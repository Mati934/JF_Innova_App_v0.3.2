import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/turno.dart';

/// Turnos del auditor en SQLite. Todo cambio deja `subido = 0` para que
/// [TurnoSync] lo suba; borrar es soft delete (`eliminado = 1`).
class LocalTurnoRepository {
  final DatabaseHelper _dbHelper;

  LocalTurnoRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const tabla = 'turnos';

  static const _select = '''
    SELECT t.*, a.nombre AS area_nombre, c.nombre AS centro_nombre
    FROM turnos t
    LEFT JOIN areas a ON a.id = t.area_id
    LEFT JOIN centros c ON c.id = t.centro_id
  ''';

  Future<Turno?> getActivo(String usuarioId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '$_select WHERE t.usuario_id = ? AND t.estado = ? AND t.eliminado = 0 '
      'ORDER BY t.ingreso_fecha DESC LIMIT 1',
      [usuarioId, TurnoEstado.activo],
    );
    return rows.isEmpty ? null : Turno.fromRow(rows.first);
  }

  /// Turnos cerrados, del más reciente al más antiguo.
  Future<List<Turno>> getCerrados(String usuarioId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '$_select WHERE t.usuario_id = ? AND t.estado = ? AND t.eliminado = 0 '
      'ORDER BY t.ingreso_fecha DESC',
      [usuarioId, TurnoEstado.cerrado],
    );
    return rows.map(Turno.fromRow).toList();
  }

  /// Salida del último turno cerrado (el ingreso siguiente debe ser posterior).
  Future<DateTime?> getUltimaSalida(
    String usuarioId, {
    String? excluirId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT MAX(egreso_fecha) AS f FROM turnos '
      'WHERE usuario_id = ? AND estado = ? AND eliminado = 0 AND id != ?',
      [usuarioId, TurnoEstado.cerrado, excluirId ?? ''],
    );
    final f = rows.first['f']?.toString();
    return (f == null || f.isEmpty) ? null : TurnoFechas.deTexto(f);
  }

  /// Área y centro para preseleccionar: los del último turno; si no tiene
  /// turnos, los de su última inspección o AST guardados en el teléfono.
  Future<({String? areaId, String? centroId})> getUltimaUbicacion(
    String usuarioId,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      tabla,
      columns: ['area_id', 'centro_id'],
      where: 'usuario_id = ? AND eliminado = 0',
      whereArgs: [usuarioId],
      orderBy: 'ingreso_fecha DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return (
        areaId: rows.first['area_id']?.toString(),
        centroId: rows.first['centro_id']?.toString(),
      );
    }
    return _ubicacionUltimaActividad(db, usuarioId);
  }

  Future<({String? areaId, String? centroId})> _ubicacionUltimaActividad(
    DatabaseExecutor db,
    String usuarioId,
  ) async {
    try {
      final r = await db.rawQuery(
        '''
        SELECT area_id, centro_id, f FROM (
          SELECT c.area_id AS area_id, a.centro_id AS centro_id,
                 a.fecha_realizacion AS f
          FROM actividades_pendientes a
          JOIN centros c ON c.id = a.centro_id
          WHERE a.usuario_id = ? AND c.area_id IS NOT NULL
          UNION ALL
          SELECT area_id, centro_id, fecha_realizacion AS f
          FROM ast_informes_pendientes
          WHERE usuario_id = ? AND area_id IS NOT NULL
        ) ORDER BY f DESC LIMIT 1
        ''',
        [usuarioId, usuarioId],
      );
      if (r.isEmpty) return (areaId: null, centroId: null);
      return (
        areaId: r.first['area_id']?.toString(),
        centroId: r.first['centro_id']?.toString(),
      );
    } catch (_) {
      // Una tabla vieja sin esas columnas no debe impedir registrar el turno.
      return (areaId: null, centroId: null);
    }
  }

  Future<void> guardar(Turno t) async {
    final db = await _dbHelper.database;
    await db.insert(tabla, {
      ...t.toRow(),
      'subido': 0,
      'eliminado': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> eliminar(String id) async {
    final db = await _dbHelper.database;
    // El borrador de cierre se va con el turno (en Supabase lo borra el
    // ON DELETE CASCADE al subir la baja del turno).
    await db.delete('turno_cierres', where: 'turno_id = ?', whereArgs: [id]);
    await db.update(
      tabla,
      {
        'eliminado': 1,
        'subido': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
