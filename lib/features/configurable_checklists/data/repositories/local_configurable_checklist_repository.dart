import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/models/configurable_checklist.dart';

class LocalConfigurableChecklistRepository {
  final DatabaseHelper _db;

  LocalConfigurableChecklistRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  Future<List<ChecklistFormType>> getActiveFormTypes() async {
    final rows = await _db.database.then(
      (db) => db.query(
        'checklist_form_types',
        where: 'activo = 1',
        orderBy: 'form_type_key ASC',
      ),
    );
    return rows.map(ChecklistFormType.fromMap).toList();
  }

  Future<List<ConfigurableChecklist>> getActiveChecklists() async {
    final rows = await _db.database.then(
      (db) =>
          db.query('checklists', where: 'activo = 1', orderBy: 'nombre ASC'),
    );
    return rows.map(ConfigurableChecklist.fromMap).toList();
  }

  Future<ConfigurableChecklist?> getChecklist(String checklistKey) async {
    final rows = await (await _db.database).query(
      'checklists',
      where: 'checklist_key = ?',
      whereArgs: [checklistKey],
      limit: 1,
    );
    return rows.isEmpty ? null : ConfigurableChecklist.fromMap(rows.first);
  }

  Future<ChecklistVersion?> getPublishedVersion(String checklistKey) async {
    final rows = await (await _db.database).query(
      'checklist_versions',
      where: 'checklist_key = ? AND estado = ?',
      whereArgs: [checklistKey, 'PUBLICADA'],
      orderBy: 'version DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ChecklistVersion.fromMap(rows.first);
  }

  Future<List<ChecklistNavigationNode>> getNavigationNodes(
    String empresaId,
  ) async {
    final rows = await (await _db.database).query(
      'checklist_navigation_nodes',
      where: 'empresa_id = ? AND habilitado = 1',
      whereArgs: [empresaId],
      orderBy: 'orden ASC, titulo ASC',
    );
    return rows.map(ChecklistNavigationNode.fromMap).toList();
  }

  /// Todos los nodos de una empresa (habilitados o no). Uso exclusivo del
  /// panel de administracion, que necesita ver y alternar los deshabilitados.
  Future<List<ChecklistNavigationNode>> getAllNavigationNodesForAdmin(
    String empresaId,
  ) async {
    final rows = await (await _db.database).query(
      'checklist_navigation_nodes',
      where: 'empresa_id = ?',
      whereArgs: [empresaId],
      orderBy: 'orden ASC, titulo ASC',
    );
    return rows.map(ChecklistNavigationNode.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getItemsForChecklist(
    String checklistKey,
  ) async {
    final version = await getPublishedVersion(checklistKey);
    return version?.preguntas ?? const [];
  }

  Future<void> saveDraft({
    required Map<String, dynamic> inspection,
    required List<Map<String, dynamic>> responses,
    List<Map<String, dynamic>> camposValores = const [],
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'checklist_inspecciones_pendientes',
        inspection,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'checklist_respuestas_pendientes',
        where: 'inspeccion_id = ?',
        whereArgs: [inspection['id']],
      );
      for (final response in responses) {
        await txn.insert(
          'checklist_respuestas_pendientes',
          response,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.delete(
        'checklist_campo_valores_pendientes',
        where: 'inspeccion_id = ?',
        whereArgs: [inspection['id']],
      );
      for (final valor in camposValores) {
        await txn.insert(
          'checklist_campo_valores_pendientes',
          valor,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteDraft(String inspectionId) async {
    final db = await _db.database;
    await db.update(
      'checklist_inspecciones_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<List<Map<String, dynamic>>> getDrafts(String empresaId) async {
    final db = await _db.database;
    return db.rawQuery(
      '''
        SELECT i.*, c.nombre AS checklist_nombre, c.icono AS checklist_icono,
          c.color AS checklist_color
        FROM checklist_inspecciones_pendientes i
        LEFT JOIN checklists c ON c.checklist_key = i.checklist_key
        WHERE i.empresa_id = ?
          AND i.eliminado = 0
          AND i.estado_final = ?
        ORDER BY i.created_at DESC
      ''',
      [empresaId, 'Borrador'],
    );
  }

  Future<Map<String, dynamic>?> getDraft(
    String inspectionId,
    String empresaId,
  ) async {
    final db = await _db.database;
    final inspections = await db.query(
      'checklist_inspecciones_pendientes',
      where: 'id = ? AND empresa_id = ? AND eliminado = 0',
      whereArgs: [inspectionId, empresaId],
      limit: 1,
    );
    if (inspections.isEmpty) return null;

    final responses = await db.query(
      'checklist_respuestas_pendientes',
      where: 'inspeccion_id = ?',
      whereArgs: [inspectionId],
      orderBy: 'orden ASC',
    );
    final evidencias = await db.query(
      'checklist_evidencias_pendientes',
      where: 'inspeccion_id = ?',
      whereArgs: [inspectionId],
      orderBy: 'orden ASC',
    );
    final camposValores = await db.query(
      'checklist_campo_valores_pendientes',
      where: 'inspeccion_id = ?',
      whereArgs: [inspectionId],
    );
    return {
      'inspeccion': inspections.first,
      'respuestas': responses,
      'evidencias': evidencias,
      'campos_valores': camposValores,
    };
  }

  /// Guarda (reemplazando) la foto de una pregunta puntual. Copia el
  /// archivo a un directorio permanente de la app antes de referenciarlo,
  /// igual que `LocalInspectionRepository.saveFoto`.
  Future<String> saveFotoPregunta({
    required String inspeccionId,
    required String itemKey,
    required File file,
  }) async {
    final permanentPath = await _copiarFotoPermanente(file, itemKey);
    final db = await _db.database;
    await db.delete(
      'checklist_evidencias_pendientes',
      where: 'inspeccion_id = ? AND tipo = ? AND respuesta_id = ?',
      whereArgs: [inspeccionId, 'RESPUESTA', itemKey],
    );
    await db.insert('checklist_evidencias_pendientes', {
      'id': const Uuid().v4(),
      'inspeccion_id': inspeccionId,
      'respuesta_id': itemKey,
      'tipo': 'RESPUESTA',
      'local_path': permanentPath,
      'storage_path': null,
      'orden': 0,
      'metadata': '{}',
      'subido': 0,
    });
    return permanentPath;
  }

  /// Reemplaza la galería de fotos generales de una inspección.
  Future<List<String>> saveFotosGenerales({
    required String inspeccionId,
    required List<File> files,
  }) async {
    final db = await _db.database;
    await db.delete(
      'checklist_evidencias_pendientes',
      where: 'inspeccion_id = ? AND tipo = ?',
      whereArgs: [inspeccionId, 'GENERAL'],
    );
    final paths = <String>[];
    var orden = 0;
    for (final file in files) {
      final permanentPath = await _copiarFotoPermanente(file, 'general');
      paths.add(permanentPath);
      await db.insert('checklist_evidencias_pendientes', {
        'id': const Uuid().v4(),
        'inspeccion_id': inspeccionId,
        'respuesta_id': null,
        'tipo': 'GENERAL',
        'local_path': permanentPath,
        'storage_path': null,
        'orden': orden,
        'metadata': '{}',
        'subido': 0,
      });
      orden++;
    }
    return paths;
  }

  Future<String> _copiarFotoPermanente(File file, String tag) async {
    final directory = await getApplicationDocumentsDirectory();
    final folderPath = '${directory.path}/checklist_configurable_img';
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    if (file.path.contains(folderPath)) return file.path;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$tag.jpg';
    final permanentPath = '$folderPath/$fileName';
    if (await file.exists()) {
      await file.copy(permanentPath);
    } else {
      throw Exception('El archivo original desapareció.');
    }
    return permanentPath;
  }
}
