import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/turno_cierre.dart';

/// Cierres de turno guardados en el teléfono (borradores y generados).
class LocalTurnoCierreRepository {
  final DatabaseHelper _dbHelper;

  LocalTurnoCierreRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const tabla = 'turno_cierres';

  Future<TurnoCierre?> getPorTurno(String turnoId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      tabla,
      where: 'turno_id = ? AND eliminado = 0',
      whereArgs: [turnoId],
      limit: 1,
    );
    return rows.isEmpty ? null : TurnoCierre.fromRow(rows.first);
  }

  /// Cierres del usuario por id de turno (para las tarjetas de "Mis turnos").
  Future<Map<String, TurnoCierre>> getPorUsuario(String usuarioId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      tabla,
      where: 'usuario_id = ? AND eliminado = 0',
      whereArgs: [usuarioId],
    );
    return {
      for (final r in rows) r['turno_id'].toString(): TurnoCierre.fromRow(r),
    };
  }

  /// Marca subido solo si la fila sigue igual que cuando se subió.
  Future<void> marcarSubido(String id, String updatedAt) async {
    final db = await _dbHelper.database;
    await db.update(
      tabla,
      {'subido': 1},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, updatedAt],
    );
  }

  /// Si otro celular ya subió un cierre para el mismo turno, el borrador de
  /// este teléfono pasa a usar ese id (lo editado aquí manda y lo reemplaza).
  Future<void> cambiarId(String idLocal, String idRemoto) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(tabla, where: 'id = ?', whereArgs: [idRemoto]);
      await txn.update(
        tabla,
        {'id': idRemoto},
        where: 'id = ?',
        whereArgs: [idLocal],
      );
    });
  }

  /// Guarda el cierre pendiente de subir (salvo que se indique lo contrario).
  Future<void> guardar(TurnoCierre c, {bool subido = false}) async {
    final db = await _dbHelper.database;
    await db.insert(tabla, {
      ...c.toRow(),
      'subido': subido ? 1 : 0,
      'eliminado': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
