import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../domain/models/extintor_state.dart';

const _tipoActividad = 'VISITA_R004';

class LocalExtintorRepository {
  final _dbHelper = DatabaseHelper.instance;
  final _inspectionRepo = LocalInspectionRepository();

  /// Carga los 18 ítems del checklist de extintores desde SQLite
  Future<List<FormularioItem>> getChecklistItems() =>
      _inspectionRepo.getItems(_tipoActividad);

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

  Future<List<String>> getLugaresHistoricos() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT DISTINCT lugar_visita
      FROM visitas_tecnicas_pendientes
      WHERE tipo_actividad = ? AND lugar_visita IS NOT NULL AND trim(lugar_visita) != ''
      ORDER BY lugar_visita ASC
    ''',
      [_tipoActividad],
    );
    return maps.map((e) => e['lugar_visita'] as String).toList();
  }

  /// Guarda la visita base + todos los extintores en una transacción atómica
  Future<void> saveInspeccionExtintores({
    required Map<String, dynamic> visitaMap,
    required List<ExtintorState> extintores,
    required bool esBorrador,
  }) async {
    final db = await _dbHelper.database;
    final visitaId = visitaMap['id'] as String;
    visitaMap['estado_final'] = esBorrador ? 'En Progreso' : 'Finalizada';
    visitaMap['subido'] = 0;
    visitaMap['tipo_actividad'] = _tipoActividad;

    await db.transaction((txn) async {
      // 1. Cabecera de visita
      await txn.insert(
        'visitas_tecnicas_pendientes',
        visitaMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Borrar extintores anteriores de esta visita y reinsertar
      await txn.delete(
        'extintores_pendientes',
        where: 'visita_id = ?',
        whereArgs: [visitaId],
      );

      for (final extintor in extintores) {
        await txn.insert(
          'extintores_pendientes',
          extintor.toDbRow(visitaId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    debugPrint(
      '💾 Inspección extintores guardada (${extintores.length} extintores)',
    );
  }

  /// Devuelve borradores de inspecciones de extintores
  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'visitas_tecnicas_pendientes',
      where: 'tipo_actividad = ? AND estado_final = ? AND eliminado = 0',
      whereArgs: [_tipoActividad, 'En Progreso'],
      orderBy: 'fecha_realizacion DESC',
    );
    return result.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['tipo_actividad_label'] = 'Inspección Extintores';
      map['nombre_centro'] = map['lugar_visita'];
      return map;
    }).toList();
  }

  /// Carga los ExtintorState de una visita (hidratados con sus items)
  Future<List<ExtintorState>> getExtintoresPorVisita(
    String visitaId,
    List<FormularioItem> items,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'extintores_pendientes',
      where: 'visita_id = ?',
      whereArgs: [visitaId],
      orderBy: 'numero ASC',
    );
    return rows.map((r) => ExtintorState.fromDb(row: r, items: items)).toList();
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

  /// Devuelve visitas finalizadas de extintores pendientes de sync
  Future<List<Map<String, dynamic>>> getVisitasPendientes() async {
    final db = await _dbHelper.database;
    return await db.query(
      'visitas_tecnicas_pendientes',
      where: 'tipo_actividad = ? AND subido = 0 AND eliminado = 0',
      whereArgs: [_tipoActividad],
    );
  }

  /// Devuelve extintores de una visita pendientes de sync
  Future<List<Map<String, dynamic>>> getExtintoresRawPorVisita(
    String visitaId,
  ) async {
    final db = await _dbHelper.database;
    return await db.query(
      'extintores_pendientes',
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
      'extintores_pendientes',
      {'subido': 1},
      where: 'visita_id = ?',
      whereArgs: [visitaId],
    );
  }

  Future<void> guardarPdfPath(String visitaId, String pdfPath) async {
    final db = await _dbHelper.database;
    await db.update(
      'visitas_tecnicas_pendientes',
      {'pdf_path_local': pdfPath},
      where: 'id = ?',
      whereArgs: [visitaId],
    );
  }
}
