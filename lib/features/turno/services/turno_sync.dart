import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/user_session.dart';
import '../data/local_turno_cierre_repository.dart';
import '../data/local_turno_repository.dart';
import '../domain/turno.dart';
import '../domain/turno_cierre.dart';
import 'turno_cierre_service.dart';

/// Payload de Supabase: sin columnas solo locales y con booleanos reales.
Map<String, dynamic> turnoPayloadSupabase(Map<String, dynamic> row) =>
    Map<String, dynamic>.from(row)
      ..remove('subido')
      ..remove('eliminado')
      ..remove('area_nombre')
      ..remove('centro_nombre')
      ..['extraordinario'] =
          row['extraordinario'] == 1 || row['extraordinario'] == true;

/// Fila local a partir de una de Supabase (ya subida).
Map<String, dynamic> turnoRowDesdeSupabase(Map<String, dynamic> r) => {
  for (final k in const [
    'id',
    'usuario_id',
    'empresa_id',
    'area_id',
    'centro_id',
    'estado',
    'ingreso_fecha',
    'egreso_estimado',
    'egreso_fecha',
    'observacion_ingreso',
    'observacion_egreso',
    'ingreso_registrado_at',
    'egreso_registrado_at',
    'app_version',
    'created_at',
    'updated_at',
  ])
    k: r[k],
  'extraordinario': r['extraordinario'] == true ? 1 : 0,
  'subido': 1,
  'eliminado': 0,
};

/// Sube los turnos pendientes y baja los del usuario (para verlos en un
/// celular nuevo). Un error en un turno no detiene los demás.
class TurnoSync {
  final SupabaseClient _supabase;
  final DatabaseHelper _dbHelper;

  TurnoSync({SupabaseClient? supabase, DatabaseHelper? dbHelper})
    : _supabase = supabase ?? Supabase.instance.client,
      _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const _remota = 'turnos';
  static const _local = LocalTurnoRepository.tabla;

  /// Devuelve cuántos turnos subió.
  Future<int> sincronizar() async {
    final subidos = await _subir();
    await _descargar();
    // Los cierres van después: necesitan su turno ya en Supabase.
    await _subirCierres();
    await _descargarCierres();
    return subidos;
  }

  static const _cierres = LocalTurnoCierreRepository.tabla;

  Future<void> _subirCierres() async {
    final db = await _dbHelper.database;
    final pendientes = await db.query(
      _cierres,
      where: 'subido = 0 AND eliminado = 0',
    );
    final service = TurnoCierreService(supabase: _supabase);
    for (final row in pendientes) {
      // subir() resuelve el choque con un cierre del mismo turno subido
      // desde otro celular; si falla queda pendiente para el próximo sync.
      await service.subir(TurnoCierre.fromRow(row));
    }
  }

  Future<void> _descargarCierres() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final desde = TurnoFechas.aTexto(TurnoFechas.sumar(DateTime.now(), -365));
      final remotos = await _supabase
          .from('turno_cierres')
          .select()
          .eq('usuario_id', uid)
          .gte('desde', desde);
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        for (final r in remotos) {
          // Por id y por turno: un borrador de este teléfono con otro id
          // para el mismo turno tampoco se pisa (turno_id es único).
          final local = await txn.query(
            _cierres,
            columns: ['subido', 'pdf_path_local'],
            where: 'id = ? OR turno_id = ?',
            whereArgs: [r['id'].toString(), r['turno_id'].toString()],
          );
          // Un borrador local sin subir manda sobre lo remoto.
          if (local.any((l) => l['subido'] == 0)) continue;
          await txn.insert(_cierres, {
            ...cierreRowDesdeSupabase(r),
            'pdf_path_local': local.isEmpty
                ? null
                : local.first['pdf_path_local'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e, st) {
      // Sin la tabla (migración v3 pendiente) no hay nada que bajar.
      debugPrint('⚠️ Error descargando cierres de turno: $e');
      _reportar(e, st, 'TurnoSync descargar cierres');
    }
  }

  Future<int> _subir() async {
    final db = await _dbHelper.database;
    // Cierres y bajas antes que ingresos: si el turno anterior se cerró sin
    // señal, su salida debe llegar antes que el ingreso nuevo (si no, Supabase
    // vería dos activos).
    final pendientes = await db.query(
      _local,
      where: 'subido = 0',
      orderBy:
          "CASE WHEN eliminado = 1 OR estado = '${TurnoEstado.cerrado}' "
          "THEN 0 ELSE 1 END, ingreso_fecha",
    );
    var count = 0;
    for (final row in pendientes) {
      final id = row['id'].toString();
      try {
        if (row['eliminado'] == 1) {
          await _supabase.from(_remota).delete().eq('id', id);
          await db.delete(_local, where: 'id = ?', whereArgs: [id]);
          continue;
        }
        final payload = turnoPayloadSupabase(row);
        payload['empresa_id'] ??= UserSession().empresaId;
        await _supabase.from(_remota).upsert(payload, onConflict: 'id');
        await db.update(
          _local,
          {'subido': 1},
          where: 'id = ? AND updated_at = ?',
          whereArgs: [id, row['updated_at']],
        );
        count++;
      } on PostgrestException catch (e, st) {
        if (e.code == '23505' &&
            row['estado'] == TurnoEstado.activo &&
            !await _hayOtroPendiente(db, id)) {
          // Ya hay un turno activo de este usuario subido desde otro celular:
          // manda ese (la descarga lo trae). Este ingreso duplicado se
          // descarta para no quedar reintentando en cada sync.
          debugPrint('⚠️ Turno $id duplicado con otro activo: se descarta.');
          await db.delete(_local, where: 'id = ?', whereArgs: [id]);
          continue;
        }
        debugPrint('🔥 Error sincronizando turno $id: $e');
        _reportar(e, st, 'TurnoSync subir: $id');
      } catch (e, st) {
        debugPrint('🔥 Error sincronizando turno $id: $e');
        _reportar(e, st, 'TurnoSync subir: $id');
      }
    }
    return count;
  }

  /// Otro turno de este teléfono sin subir (ej. el cierre del anterior que
  /// falló): entonces el choque se resuelve solo en el próximo sync y el
  /// ingreso no se descarta.
  Future<bool> _hayOtroPendiente(DatabaseExecutor db, String id) async {
    final n = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_local WHERE subido = 0 AND id != ?',
        [id],
      ),
    );
    return (n ?? 0) > 0;
  }

  Future<void> _descargar() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final desde = TurnoFechas.aTexto(TurnoFechas.sumar(DateTime.now(), -365));
      final remotos = await _supabase
          .from(_remota)
          .select()
          .eq('usuario_id', uid)
          .gte('ingreso_fecha', desde);
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        for (final r in remotos) {
          final id = r['id'].toString();
          final local = await txn.query(
            _local,
            columns: ['subido'],
            where: 'id = ?',
            whereArgs: [id],
          );
          // Un cambio local sin subir manda sobre lo remoto.
          if (local.isNotEmpty && local.first['subido'] == 0) continue;
          await txn.insert(
            _local,
            turnoRowDesdeSupabase(r),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e, st) {
      debugPrint('⚠️ Error descargando turnos: $e');
      _reportar(e, st, 'TurnoSync descargar');
    }
  }

  void _reportar(Object e, StackTrace st, String reason) {
    try {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: reason,
        fatal: false,
      );
    } catch (_) {}
  }
}
