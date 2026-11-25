import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/database_helper.dart';
import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../domain/models/prosesso_extintor_state.dart';

const tipoActividadProsesso = 'MANTENCION_PROSESSO';

class LocalProsessoRepository {
  final _dbHelper = DatabaseHelper.instance;
  final _inspectionRepo = LocalInspectionRepository();

  /// Items de checklist (las 9 preguntas) desde formulario_items
  Future<List<FormularioItem>> getChecklistItems() =>
      _inspectionRepo.getItems(tipoActividadProsesso);

  Future<Map<String, dynamic>?> getUsuarioLocal(String userId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Devuelve el siguiente Nº de certificado sugerido para un año dado
  /// (`<año>/<correlativo>`). El usuario puede sobrescribirlo.
  Future<String> siguienteCertNumero(int anio) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      '''
      SELECT COALESCE(MAX(cert_correlativo), 0) + 1 AS siguiente
      FROM visitas_tecnicas_pendientes
      WHERE tipo_actividad = ? AND cert_anio = ?
      ''',
      [tipoActividadProsesso, anio],
    );
    final siguiente = (res.first['siguiente'] as int?) ?? 1;
    return '$anio/$siguiente';
  }

  /// Clientes y direcciones ya usadas (para autocomplete)
  Future<List<Map<String, String>>> getClientesHistoricos() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT cliente_nombre, cliente_direccion
      FROM visitas_tecnicas_pendientes
      WHERE tipo_actividad = ?
        AND cliente_nombre IS NOT NULL AND trim(cliente_nombre) != ''
      ORDER BY cliente_nombre ASC
      ''',
      [tipoActividadProsesso],
    );
    return rows
        .map(
          (r) => {
            'nombre': (r['cliente_nombre'] as String?) ?? '',
            'direccion': (r['cliente_direccion'] as String?) ?? '',
          },
        )
        .toList();
  }

  /// Guarda el servicio (cabecera + extintores) atómicamente
  Future<void> saveServicio({
    required Map<String, dynamic> visitaMap,
    required List<ExtintorProsessoState> extintores,
    required bool esBorrador,
  }) async {
    final db = await _dbHelper.database;
    final visitaId = visitaMap['id'] as String;
    visitaMap['estado_final'] = esBorrador ? 'En Progreso' : 'Finalizada';
    visitaMap['subido'] = 0;
    visitaMap['tipo_actividad'] = tipoActividadProsesso;
    visitaMap['empresa'] = 'Prosesso';

    // Asignar correlativo al finalizar si no lo tiene
    if (!esBorrador) {
      final tieneCorrelativo =
          (visitaMap['cert_correlativo'] as int?) != null &&
          (visitaMap['cert_correlativo'] as int) > 0;
      if (!tieneCorrelativo) {
        final anio = (visitaMap['cert_anio'] as int?) ?? DateTime.now().year;
        final res = await db.rawQuery(
          '''
          SELECT COALESCE(MAX(cert_correlativo), 0) + 1 AS siguiente
          FROM visitas_tecnicas_pendientes
          WHERE tipo_actividad = ? AND cert_anio = ?
          ''',
          [tipoActividadProsesso, anio],
        );
        final correlativo = (res.first['siguiente'] as int?) ?? 1;
        visitaMap['cert_anio'] = anio;
        visitaMap['cert_correlativo'] = correlativo;
        final certActual = (visitaMap['cert_numero'] as String?)?.trim();
        if (certActual == null || certActual.isEmpty) {
          visitaMap['cert_numero'] = '$anio/$correlativo';
        }
      }
    }

    await db.transaction((txn) async {
      await txn.insert(
        'visitas_tecnicas_pendientes',
        visitaMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'mantenciones_prosesso_pendientes',
        where: 'visita_id = ?',
        whereArgs: [visitaId],
      );

      for (final ext in extintores) {
        await txn.insert(
          'mantenciones_prosesso_pendientes',
          ext.toDbRow(visitaId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    debugPrint(
      '💾 Servicio PROSESSO guardado (${extintores.length} extintores)',
    );
  }

  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await _dbHelper.database;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final result = await db.query(
      'visitas_tecnicas_pendientes',
      where:
          'tipo_actividad = ? AND estado_final = ? AND eliminado = 0 AND usuario_id = ?',
      whereArgs: [tipoActividadProsesso, 'En Progreso', userId ?? ''],
      orderBy: 'fecha_realizacion DESC',
    );
    return result.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['tipo_actividad_label'] = 'Mantención de Extintores';
      map['nombre_centro'] =
          map['cliente_nombre'] ?? map['lugar_visita'] ?? 'Prosesso';
      return map;
    }).toList();
  }

  Future<Map<String, dynamic>?> getVisita(String visitaId) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'visitas_tecnicas_pendientes',
      where: 'id = ?',
      whereArgs: [visitaId],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<ExtintorProsessoState>> getExtintoresPorVisita(
    String visitaId,
    List<FormularioItem> items,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'mantenciones_prosesso_pendientes',
      where: 'visita_id = ?',
      whereArgs: [visitaId],
      orderBy: 'numero ASC',
    );
    return rows
        .map((r) => ExtintorProsessoState.fromDb(row: r, items: items))
        .toList();
  }

  Future<void> eliminarBorrador(String visitaId) async {
    final db = await _dbHelper.database;
    await db.update(
      'visitas_tecnicas_pendientes',
      {'estado_final': 'Eliminada', 'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [visitaId],
    );
  }

  Future<List<Map<String, dynamic>>> getVisitasPendientes() async {
    final db = await _dbHelper.database;
    return await db.query(
      'visitas_tecnicas_pendientes',
      where: 'tipo_actividad = ? AND subido = 0 AND eliminado = 0',
      whereArgs: [tipoActividadProsesso],
    );
  }

  Future<List<Map<String, dynamic>>> getExtintoresRawPorVisita(
    String visitaId,
  ) async {
    final db = await _dbHelper.database;
    return await db.query(
      'mantenciones_prosesso_pendientes',
      where: 'visita_id = ? AND subido = 0',
      whereArgs: [visitaId],
    );
  }

  Future<void> marcarVisitaSubida(String visitaId) async {
    final db = await _dbHelper.database;
    await db.update(
      'visitas_tecnicas_pendientes',
      {'subido': 1},
      where: 'id = ?',
      whereArgs: [visitaId],
    );
    await db.update(
      'mantenciones_prosesso_pendientes',
      {'subido': 1},
      where: 'visita_id = ?',
      whereArgs: [visitaId],
    );
  }

  Future<void> guardarPdfRegistroPath(String visitaId, String pdfPath) async {
    final db = await _dbHelper.database;
    await db.update(
      'visitas_tecnicas_pendientes',
      {'pdf_path_local': pdfPath},
      where: 'id = ?',
      whereArgs: [visitaId],
    );
  }

  Future<void> guardarPdfCertificadoPath(
    String visitaId,
    String pdfPath,
  ) async {
    final db = await _dbHelper.database;
    await db.update(
      'visitas_tecnicas_pendientes',
      {'pdf_certificado_path_local': pdfPath},
      where: 'id = ?',
      whereArgs: [visitaId],
    );
  }
}
