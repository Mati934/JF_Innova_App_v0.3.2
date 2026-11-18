import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/database_helper.dart';
import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../domain/models/formative_activity.dart';

class LocalFormativeActivityRepository {
  final DatabaseHelper _databaseHelper;

  LocalFormativeActivityRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<void> save(
    FormativeActivity activity, {
    required bool finalized,
    Uint8List? signatureBytes,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final duration = FormativeActivity.durationMinutes(
      activity.horaInicio,
      activity.horaTermino,
    );
    final accountedDuration = duration == null
        ? null
        : FormativeActivity.accountedDurationMinutes(duration);

    await db.transaction((txn) async {
      final existingParent = await txn.query(
        'actividades_pendientes',
        columns: ['numero_reporte', 'pdf_url', 'pdf_path_local'],
        where: 'id = ?',
        whereArgs: [activity.id],
        limit: 1,
      );
      final oldParent = existingParent.isEmpty
          ? <String, Object?>{}
          : existingParent.first;

      await txn.insert('actividades_pendientes', {
        'id': activity.id,
        'usuario_id': activity.usuarioId,
        'empresa_id': activity.empresaId,
        'centro_id': activity.centroId,
        'tipo_actividad': 'ACTIVIDAD_FORMATIVA',
        'fecha_realizacion': activity.fecha.toIso8601String(),
        'estado_final': finalized ? 'En Seguimiento' : 'En Progreso',
        'puerto_abierto': 1,
        'numero_reporte': oldParent['numero_reporte'],
        'numero_seguimiento': 0,
        'pdf_url': oldParent['pdf_url'],
        'pdf_path_local': oldParent['pdf_path_local'],
        'eliminado': 0,
        'subido': 0,
        'app_version': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final existingDetails = await txn.query(
        'actividades_formativas_pendientes',
        columns: ['firma_relator_image', 'firma_relator_url', 'created_at'],
        where: 'actividad_id = ?',
        whereArgs: [activity.id],
        limit: 1,
      );
      final oldDetails = existingDetails.isEmpty
          ? <String, Object?>{}
          : existingDetails.first;

      await txn.insert(
        'actividades_formativas_pendientes',
        {
          'actividad_id': activity.id,
          'empresa_id': activity.empresaId,
          'area_id': activity.areaId,
          'area_nombre': activity.areaNombre,
          'area_otro': activity.areaOtro,
          'centro_nombre': activity.centroNombre,
          'tipo_actividad': activity.tipoActividad,
          'tipo_otro': activity.tipoOtro,
          'descripcion': activity.descripcion,
          'hora_inicio': activity.horaInicio,
          'hora_termino': activity.horaTermino,
          'asistentes': activity.asistentes,
          'duracion_real_minutos': duration,
          'duracion_contabilizada_minutos': accountedDuration,
          'hh_sin_relator': accountedDuration == null
              ? null
              : FormativeActivity.hoursWithoutRelator(
                  activity.asistentes,
                  accountedDuration,
                ),
          'hh_con_relator': accountedDuration == null
              ? null
              : FormativeActivity.hoursWithRelator(
                  activity.asistentes,
                  accountedDuration,
                ),
          'relator_nombre': activity.relatorNombre,
          'firma_relator_image':
              signatureBytes ?? oldDetails['firma_relator_image'],
          'firma_relator_url': oldDetails['firma_relator_url'],
          'subido': 0,
          'created_at': existingDetails.isEmpty
              ? now
              : (existingDetails.first['created_at'] ?? now),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> setPdfPath(String activityId, String path) async {
    final db = await _databaseHelper.database;
    await db.update(
      'actividades_pendientes',
      {'pdf_path_local': path, 'subido': 0},
      where: 'id = ? AND tipo_actividad = ?',
      whereArgs: [activityId, 'ACTIVIDAD_FORMATIVA'],
    );
  }

  Future<List<String>> getPhotoPaths(String activityId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'fotos_pendientes',
      columns: ['local_path'],
      where: 'actividad_id = ? AND item_id IS NULL',
      whereArgs: [activityId],
      orderBy: 'id',
    );
    return rows.map((row) => row['local_path'] as String).toList();
  }

  Future<List<String>> savePhotos(String activityId, List<String> paths) async {
    final db = await _databaseHelper.database;
    final existing = await getPhotoPaths(activityId);
    final retained = existing.where(paths.contains).toSet();
    // Reuse inspection's permanent storage and the shared upload queue.
    final inspection = LocalInspectionRepository();
    for (final path in paths.toSet()) {
      if (!existing.contains(path)) {
        final savedPath = await inspection.saveFoto(
          activityId: activityId,
          itemId: null,
          file: XFile(path),
          descripcion: '',
        );
        retained.add(savedPath);
      }
    }
    await db.transaction((txn) async {
      for (final path in retained) {
        await txn.delete(
          'formativa_fotos_eliminadas',
          where: 'actividad_id = ? AND local_path = ?',
          whereArgs: [activityId, path],
        );
      }
      for (final path in existing.where((path) => !paths.contains(path))) {
        // Queue even an unacknowledged upload: it may have reached the server.
        await txn.insert(
          'formativa_fotos_eliminadas',
          {'actividad_id': activityId, 'local_path': path},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.delete(
          'fotos_pendientes',
          where: 'actividad_id = ? AND local_path = ? AND item_id IS NULL',
          whereArgs: [activityId, path],
        );
      }
      await txn.update(
        'actividades_pendientes',
        {'pdf_url': null, 'subido': 0},
        where: 'id = ? AND tipo_actividad = ?',
        whereArgs: [activityId, 'ACTIVIDAD_FORMATIVA'],
      );
    });
    return getPhotoPaths(activityId);
  }

  Future<List<Map<String, dynamic>>> getDrafts() async {
    final db = await _databaseHelper.database;
    return db.rawQuery('''
      SELECT a.*, c.nombre AS nombre_centro,
             f.tipo_actividad AS actividad_formativa_tipo,
             f.hora_inicio, f.hora_termino, f.area_nombre, f.area_otro,
             f.asistentes, f.relator_nombre
        FROM actividades_pendientes a
        LEFT JOIN centros c ON c.id = a.centro_id
        LEFT JOIN actividades_formativas_pendientes f ON f.actividad_id = a.id
       WHERE a.tipo_actividad = 'ACTIVIDAD_FORMATIVA'
         AND a.estado_final = 'En Progreso'
         AND a.eliminado = 0
       ORDER BY a.fecha_realizacion DESC
    ''');
  }

  Future<Map<String, dynamic>?> getById(String activityId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.*, c.nombre AS nombre_centro, e.nombre AS empresa_nombre,
             f.area_id, f.area_nombre, f.area_otro, f.tipo_actividad AS actividad_formativa_tipo,
             f.tipo_otro, f.descripcion, f.hora_inicio, f.hora_termino, f.asistentes,
             f.duracion_real_minutos, f.duracion_contabilizada_minutos,
             f.hh_sin_relator, f.hh_con_relator, f.relator_nombre,
             f.firma_relator_image, f.firma_relator_url
        FROM actividades_pendientes a
        LEFT JOIN centros c ON c.id = a.centro_id
        LEFT JOIN empresas e ON e.id = a.empresa_id
        LEFT JOIN actividades_formativas_pendientes f ON f.actividad_id = a.id
       WHERE a.id = ?
       LIMIT 1
      ''',
      [activityId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> getSuggestedAreaId(String userId, String empresaId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.area_id
        FROM actividades_pendientes a
        JOIN centros c ON c.id = a.centro_id
       WHERE a.usuario_id = ?
         AND a.empresa_id = ?
         AND a.tipo_actividad IN ('INSPECCION_BUCEO', 'INSPECCION_EMBARCACION')
         AND c.area_id IS NOT NULL
       ORDER BY a.fecha_realizacion DESC
       LIMIT 1
      ''',
      [userId, empresaId],
    );
    return rows.isEmpty ? null : rows.first['area_id']?.toString();
  }

  Future<List<Map<String, dynamic>>> getAreas(String empresaId) async {
    return _databaseHelper.getAreasByEmpresa(empresaId);
  }

  Future<List<Map<String, dynamic>>> getCentros(String empresaId) async {
    final db = await _databaseHelper.database;
    return db.rawQuery(
      '''
      SELECT c.*
        FROM centros c
        JOIN empresa_areas ea ON ea.area_id = c.area_id
       WHERE ea.empresa_id = ?
       ORDER BY c.nombre
      ''',
      [empresaId],
    );
  }

  Future<void> deleteDraft(String activityId) async {
    final db = await _databaseHelper.database;
    await db.update(
      'actividades_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ? AND tipo_actividad = ?',
      whereArgs: [activityId, 'ACTIVIDAD_FORMATIVA'],
    );
  }
}
