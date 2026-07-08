import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../../prosesso/domain/models/prosesso_extintor_state.dart';
import '../../domain/models/merieux_visita.dart';

/// Repositorio local (offline-first) de los 2 submódulos Merieux. Comparten
/// la cabecera (`merieux_visitas_pendientes`); cada submódulo tiene su propia
/// tabla hija:
///   * MERIEUX_VISITAS    -> merieux_visita_respuestas_pendientes
///   * MERIEUX_EXTINTORES -> merieux_extintores_pendientes (reusa
///     ExtintorProsessoState, mismo formato que el módulo Prosesso).
class LocalMerieuxRepository {
  final DatabaseHelper _db;
  LocalMerieuxRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  // --- Preguntas (reusan formulario_items existentes) --------------------

  Future<List<FormularioItem>> getItemsChecklistVisita() async {
    final db = await _db.database;
    final rows = await db.query(
      'formulario_items',
      where: 'tipo_actividad = ? AND activo = 1',
      whereArgs: [kMerieuxChecklistVehiculosLivianos],
      orderBy: 'orden ASC',
    );
    return rows
        .map(
          (r) => FormularioItem(
            id: r['id'].toString(),
            pregunta: (r['pregunta'] ?? '').toString(),
            categoria: (r['categoria'] ?? 'General').toString(),
            criticidad: (r['criticidad'] ?? 'Tolerable').toString(),
          ),
        )
        .toList();
  }

  Future<List<FormularioItem>> getItemsChecklistExtintores() async {
    final db = await _db.database;
    final rows = await db.query(
      'formulario_items',
      where: 'tipo_actividad = ? AND activo = 1',
      whereArgs: [kMerieuxTipoFormularioExtintores],
      orderBy: 'orden ASC',
    );
    return rows
        .map(
          (r) => FormularioItem(
            id: r['id'].toString(),
            pregunta: (r['pregunta'] ?? '').toString(),
            categoria: (r['categoria'] ?? 'General').toString(),
            criticidad: (r['criticidad'] ?? 'Tolerable').toString(),
          ),
        )
        .toList();
  }

  // --- MERIEUX_VISITAS -----------------------------------------------------

  Future<void> guardarVisita(
    MerieuxVisita visita,
    List<MerieuxRespuesta> respuestas,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'merieux_visitas_pendientes',
        _visitaToRow(visita),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'merieux_visita_respuestas_pendientes',
        where: 'visita_id = ?',
        whereArgs: [visita.id],
      );
      for (final r in respuestas) {
        await txn.insert(
          'merieux_visita_respuestas_pendientes',
          {...r.toMap(), 'subido': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Map<String, dynamic>?> getVisitaConRespuestasById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'merieux_visitas_pendientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final cabecera = Map<String, dynamic>.from(rows.first);
    final respuestas = await db.query(
      'merieux_visita_respuestas_pendientes',
      where: 'visita_id = ?',
      whereArgs: [id],
    );
    cabecera['respuestas'] = respuestas;
    return cabecera;
  }

  // --- MERIEUX_EXTINTORES --------------------------------------------------

  Future<void> guardarVisitaExtintores(
    MerieuxVisita visita,
    List<ExtintorProsessoState> extintores,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'merieux_visitas_pendientes',
        _visitaToRow(visita),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'merieux_extintores_pendientes',
        where: 'visita_id = ?',
        whereArgs: [visita.id],
      );
      for (final ext in extintores) {
        await txn.insert(
          'merieux_extintores_pendientes',
          ext.toDbRow(visita.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<ExtintorProsessoState>> getExtintoresPorVisita(
    String visitaId,
    List<FormularioItem> items,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'merieux_extintores_pendientes',
      where: 'visita_id = ?',
      whereArgs: [visitaId],
      orderBy: 'numero ASC',
    );
    return rows
        .map((r) => ExtintorProsessoState.fromDb(row: r, items: items))
        .toList();
  }

  // --- Comunes ------------------------------------------------------------

  /// Borradores de un submódulo (`tipoActividad`). No filtra por usuario:
  /// la BD local es por dispositivo (mismo criterio que
  /// `LocalAstRepository.getBorradores`), filtrar por `usuario_id` acá solo
  /// agrega un punto de falla si ese campo no quedó seteado a tiempo.
  /// Incluye `num_extintores` (0 para MERIEUX_VISITAS) para la tarjeta.
  Future<List<Map<String, dynamic>>> getBorradores({
    required String tipoActividad,
  }) async {
    final db = await _db.database;
    return db.rawQuery(
      '''
      SELECT v.*,
             (SELECT COUNT(*)
                FROM merieux_extintores_pendientes e
               WHERE e.visita_id = v.id) AS num_extintores
        FROM merieux_visitas_pendientes v
       WHERE v.tipo_actividad = ? AND v.estado_final = ? AND v.eliminado = 0
       ORDER BY v.created_at DESC
      ''',
      [tipoActividad, 'En Progreso'],
    );
  }

  Future<void> setPdfPathLocal(String visitaId, String pathLocal) async {
    final db = await _db.database;
    await db.update(
      'merieux_visitas_pendientes',
      {'pdf_path_local': pathLocal, 'subido': 0},
      where: 'id = ?',
      whereArgs: [visitaId],
    );
  }

  Future<void> eliminarBorrador(String visitaId) async {
    final db = await _db.database;
    await db.update(
      'merieux_visitas_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [visitaId],
    );
  }

  // --- Mappers --------------------------------------------------------

  Map<String, dynamic> _visitaToRow(MerieuxVisita v) {
    return {
      'id': v.id,
      'usuario_id': v.usuarioId,
      'empresa_id': v.empresaId,
      'tipo_actividad': v.tipoActividad,
      'checklist_tipo': v.checklistTipo,
      'profesional': v.profesional,
      'fono_profesional': v.fonoProfesional,
      'correo_profesional': v.correoProfesional,
      'region': v.region,
      'area': v.area,
      'jefatura_a_cargo': v.jefaturaACargo,
      'origen_actividad': v.origenActividad,
      'fecha_realizacion': v.fechaRealizacion.toIso8601String(),
      'hora_inicio': v.horaInicio,
      'hora_termino': v.horaTermino,
      'correo_1': v.correo1,
      'correo_2': v.correo2,
      'campos_extra': jsonEncode(const {}),
      'observaciones': v.observaciones,
      'correlativo': v.correlativo,
      'estado_final': v.estadoFinal,
      'firma_nombre': v.firmaNombre,
      'signature_image': v.signatureImage,
      'pdf_url': v.pdfUrl,
      'pdf_path_local': v.pdfPathLocal,
      'subido': 0,
      'eliminado': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  MerieuxVisita visitaFromRow(Map<String, dynamic> row) {
    return MerieuxVisita(
      id: row['id'] as String,
      tipoActividad: (row['tipo_actividad'] ?? kMerieuxTipoVisitas).toString(),
      checklistTipo: row['checklist_tipo'] as String?,
      usuarioId: row['usuario_id'] as String?,
      empresaId: row['empresa_id'] as String?,
      profesional: row['profesional'] as String?,
      fonoProfesional: row['fono_profesional'] as String?,
      correoProfesional: row['correo_profesional'] as String?,
      region: row['region'] as String?,
      area: row['area'] as String?,
      jefaturaACargo: row['jefatura_a_cargo'] as String?,
      origenActividad: row['origen_actividad'] as String?,
      fechaRealizacion:
          DateTime.tryParse((row['fecha_realizacion'] ?? '').toString()) ??
          DateTime.now(),
      horaInicio: row['hora_inicio'] as String?,
      horaTermino: row['hora_termino'] as String?,
      correo1: row['correo_1'] as String?,
      correo2: row['correo_2'] as String?,
      observaciones: row['observaciones'] as String?,
      correlativo: row['correlativo'] as String?,
      estadoFinal: (row['estado_final'] ?? 'En Progreso').toString(),
      firmaNombre: row['firma_nombre'] as String?,
      signatureImage: row['signature_image'] is Uint8List
          ? row['signature_image'] as Uint8List
          : null,
      pdfUrl: row['pdf_url'] as String?,
      pdfPathLocal: row['pdf_path_local'] as String?,
    );
  }

  String newId() => const Uuid().v4();

  Future<Map<String, dynamic>?> getUsuarioLocal(String userId) async {
    final db = await _db.database;
    final result = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
}
