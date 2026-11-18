import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/models/registro_inmersion_models.dart';

/// Datos de la inspección de buceo que alimentan el registro.
class InspeccionBuceoBase {
  final String actividadId;
  final String? usuarioId;
  final String? empresaId;
  final String? centroId;
  final String? centroNombre;
  final String? contratistaId;
  final String? contratistaNombre;
  final DateTime? fecha;
  final String? numeroInspeccion;
  final double? profundidadAutorizadaM;
  final List<ParticipanteCuadrilla> cuadrilla;

  const InspeccionBuceoBase({
    required this.actividadId,
    this.usuarioId,
    this.empresaId,
    this.centroId,
    this.centroNombre,
    this.contratistaId,
    this.contratistaNombre,
    this.fecha,
    this.numeroInspeccion,
    this.profundidadAutorizadaM,
    this.cuadrilla = const [],
  });
}

class ParticipanteCuadrilla {
  final String personalId;
  final String nombre;
  final String? rut;
  final String rol;

  const ParticipanteCuadrilla({
    required this.personalId,
    required this.nombre,
    required this.rol,
    this.rut,
  });

  bool get esBuzo => rol.trim().toLowerCase() == 'buzo';
}

/// Registro completo para reabrir, sincronizar o generar el PDF.
class RegistroInmersionCompleto {
  final RegistroInmersion registro;
  final List<RegistroInmersionBuzo> buzos;
  final List<RegistroInmersionFoto> fotos;

  const RegistroInmersionCompleto({
    required this.registro,
    required this.buzos,
    required this.fotos,
  });
}

/// Número de inspección válido (descarta provisorios viejos `PROV-*` / `~`).
String? numeroInspeccionValido(Object? valor) {
  final s = (valor ?? '').toString().trim();
  if (s.isEmpty || s.startsWith('PROV-') || s.startsWith('~')) return null;
  return s;
}

/// Repositorio local (SQLite) del registro de inmersiones.
class LocalRegistroInmersionRepository {
  final DatabaseHelper _db;
  LocalRegistroInmersionRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  static const _tRegistro = 'registros_inmersion_pendientes';
  static const _tBuzos = 'registro_inmersion_buzos_pendientes';
  static const _tInmersiones = 'registro_inmersion_inmersiones_pendientes';
  static const _tFotos = 'registro_inmersion_fotos_pendientes';

  /// Inspecciones de buceo finalizadas del auditor que están en este
  /// teléfono, las más recientes primero, con su registro si ya tiene uno.
  Future<List<Map<String, dynamic>>> getInspeccionesBuceoDisponibles(
    String usuarioId,
  ) async {
    final db = await _db.database;
    return db.rawQuery(
      '''
      SELECT a.id AS actividad_id,
             a.fecha_realizacion,
             a.numero_reporte,
             c.nombre AS centro_nombre,
             r.id AS registro_id,
             r.estado_final AS registro_estado,
             r.correlativo AS registro_correlativo
        FROM actividades_pendientes a
        LEFT JOIN centros c ON c.id = a.centro_id
        LEFT JOIN $_tRegistro r
               ON r.actividad_id = a.id AND r.eliminado = 0
       WHERE a.tipo_actividad = 'INSPECCION_BUCEO'
         AND a.eliminado = 0
         AND a.estado_final NOT IN ('En Progreso', 'Eliminada')
         AND a.usuario_id = ?
       ORDER BY a.fecha_realizacion DESC
      ''',
      [usuarioId],
    );
  }

  /// Registro vigente (no eliminado) de una inspección, o null.
  Future<Map<String, dynamic>?> getRegistroVigentePorActividad(
    String actividadId,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      _tRegistro,
      where: 'actividad_id = ? AND eliminado = 0',
      whereArgs: [actividadId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Lee la inspección de buceo local: cabecera, profundidad autorizada y
  /// cuadrilla. Null si la inspección no está en el teléfono.
  Future<InspeccionBuceoBase?> cargarInspeccion(String actividadId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.id, a.usuario_id, a.empresa_id, a.centro_id, a.contratista_id,
             a.fecha_realizacion, a.numero_reporte,
             c.nombre AS centro_nombre,
             k.nombre AS contratista_nombre
        FROM actividades_pendientes a
        LEFT JOIN centros c ON c.id = a.centro_id
        LEFT JOIN contratistas k ON k.id = a.contratista_id
       WHERE a.id = ?
       LIMIT 1
      ''',
      [actividadId],
    );
    if (rows.isEmpty) return null;
    final a = rows.first;

    final participantes = await db.rawQuery(
      '''
      SELECT ap.personal_id, ap.rol_en_faena, p.nombre_completo, p.rut
        FROM actividad_participantes ap
        LEFT JOIN personal_externo p ON p.id = ap.personal_id
       WHERE ap.actividad_id = ?
      ''',
      [actividadId],
    );

    return InspeccionBuceoBase(
      actividadId: actividadId,
      usuarioId: a['usuario_id']?.toString(),
      empresaId: a['empresa_id']?.toString(),
      centroId: a['centro_id']?.toString(),
      centroNombre: a['centro_nombre']?.toString(),
      contratistaId: a['contratista_id']?.toString(),
      contratistaNombre: a['contratista_nombre']?.toString(),
      fecha: DateTime.tryParse((a['fecha_realizacion'] ?? '').toString()),
      // La inspección no captura la profundidad autorizada (en Supabase
      // `verificaciones_buceo.profundidad_maxima` vale 0 en todas las filas):
      // el auditor la ingresa en el encabezado del registro.
      numeroInspeccion: numeroInspeccionValido(a['numero_reporte']),
      cuadrilla: participantes
          .map(
            (p) => ParticipanteCuadrilla(
              personalId: p['personal_id'].toString(),
              nombre: (p['nombre_completo'] ?? 'Sin nombre').toString(),
              rut: p['rut']?.toString(),
              rol: (p['rol_en_faena'] ?? 'Buzo').toString(),
            ),
          )
          .toList(),
    );
  }

  /// Arma un registro nuevo (sin guardarlo) con los buzos de la cuadrilla.
  /// Cada buzo trae una inmersión con "desde" = [ahora] (editable).
  static RegistroInmersionCompleto nuevoDesdeInspeccion({
    required InspeccionBuceoBase base,
    required String origen,
    required String? usuarioId,
    required String? empresaId,
    DateTime? ahora,
    Uuid uuid = const Uuid(),
  }) {
    final momento = ahora ?? DateTime.now();
    final registroId = uuid.v4();
    final horaInicio =
        '${momento.hour.toString().padLeft(2, '0')}:'
        '${momento.minute.toString().padLeft(2, '0')}';

    final registro = RegistroInmersion(
      id: registroId,
      actividadId: base.actividadId,
      empresaId: empresaId ?? base.empresaId,
      usuarioId: usuarioId ?? base.usuarioId,
      centroId: base.centroId,
      centroNombre: base.centroNombre,
      contratistaId: base.contratistaId,
      contratistaNombre: base.contratistaNombre,
      numeroInspeccion: base.numeroInspeccion,
      fechaRealizacion: base.fecha ?? momento,
      profundidadAutorizadaM: base.profundidadAutorizadaM,
      origen: origen,
    );

    final buzos = <RegistroInmersionBuzo>[];
    for (final p in base.cuadrilla.where((p) => p.esBuzo)) {
      final buzoId = uuid.v4();
      buzos.add(
        RegistroInmersionBuzo(
          id: buzoId,
          registroId: registroId,
          personalId: p.personalId,
          nombre: p.nombre,
          rut: p.rut,
          cargo: 'Buzo',
          orden: buzos.length,
          inmersiones: [
            Inmersion(
              id: uuid.v4(),
              buzoId: buzoId,
              registroId: registroId,
              horaInicio: horaInicio,
            ),
          ],
        ),
      );
    }
    return RegistroInmersionCompleto(
      registro: registro,
      buzos: buzos,
      fotos: const [],
    );
  }

  /// Inserta o actualiza el registro completo. Reescribe los hijos para
  /// mantener consistencia (mismo patrón que AST). Queda `subido = 0`.
  Future<void> guardar(
    RegistroInmersion registro,
    List<RegistroInmersionBuzo> buzos,
    List<RegistroInmersionFoto> fotos,
  ) async {
    final db = await _db.database;
    final autorizada = registro.profundidadAutorizadaM;
    await db.transaction((txn) async {
      await txn.insert(_tRegistro, {
        ...registro.toRow(),
        'subido': 0,
        'eliminado': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final t in [_tInmersiones, _tBuzos, _tFotos]) {
        await txn.delete(t, where: 'registro_id = ?', whereArgs: [registro.id]);
      }
      for (var i = 0; i < buzos.length; i++) {
        final b = buzos[i]..orden = i;
        await txn.insert(_tBuzos, {
          ...b.toRow(autorizada),
          'subido': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        final inmersiones = b.realizoInmersion
            ? b.inmersiones
            : const <Inmersion>[];
        for (var j = 0; j < inmersiones.length; j++) {
          final inm = inmersiones[j]..orden = j + 1;
          await txn.insert(_tInmersiones, {
            ...inm.toRow(autorizada),
            'subido': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final f in fotos) {
        await txn.insert(_tFotos, {
          ...f.toRow(),
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<RegistroInmersionCompleto?> getCompleto(String registroId) async {
    final db = await _db.database;
    final rows = await db.query(
      _tRegistro,
      where: 'id = ?',
      whereArgs: [registroId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final buzosRows = await db.query(
      _tBuzos,
      where: 'registro_id = ?',
      whereArgs: [registroId],
      orderBy: 'orden ASC',
    );
    final inmRows = await db.query(
      _tInmersiones,
      where: 'registro_id = ?',
      whereArgs: [registroId],
      orderBy: 'orden ASC',
    );
    final fotosRows = await db.query(
      _tFotos,
      where: 'registro_id = ?',
      whereArgs: [registroId],
      orderBy: 'posicion ASC',
    );
    final buzos = buzosRows.map((b) {
      final id = b['id'].toString();
      return RegistroInmersionBuzo.fromRow(
        b,
        inmersiones: inmRows
            .where((i) => i['buzo_id'].toString() == id)
            .map(Inmersion.fromRow)
            .toList(),
      );
    }).toList();
    return RegistroInmersionCompleto(
      registro: RegistroInmersion.fromRow(rows.first),
      buzos: buzos,
      fotos: fotosRows.map(RegistroInmersionFoto.fromRow).toList(),
    );
  }

  /// Borradores del usuario para la lista de Inicio.
  Future<List<Map<String, dynamic>>> getBorradores(String? usuarioId) async {
    final db = await _db.database;
    try {
      return await db.rawQuery(
        '''
        SELECT r.*,
               (SELECT COUNT(*) FROM $_tBuzos b WHERE b.registro_id = r.id)
                 AS num_buzos
          FROM $_tRegistro r
         WHERE r.eliminado = 0
           AND r.estado_final = ?
           AND r.usuario_id = ?
         ORDER BY r.created_at DESC
        ''',
        [RegistroInmersionEstado.borrador, usuarioId ?? ''],
      );
    } catch (e) {
      debugPrint('⚠️ Error leyendo borradores de inmersiones: $e');
      return [];
    }
  }

  /// Soft delete: el sync lo borra en Supabase (si llegó a subir) y local.
  Future<void> eliminarBorrador(String registroId) async {
    final db = await _db.database;
    await db.update(
      _tRegistro,
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [registroId],
    );
  }
}
