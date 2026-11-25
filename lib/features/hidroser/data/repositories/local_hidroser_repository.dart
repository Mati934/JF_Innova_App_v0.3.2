import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/models/hidroser_inspeccion.dart';
import '../../domain/models/hidroser_lista.dart';

class LocalHidroserRepository {
  final DatabaseHelper _db;
  LocalHidroserRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  /// Catálogo de listas activas (para la pantalla del módulo).
  Future<List<HidroserLista>> getListasActivas() async {
    final rows = await _db.getHidroserListasActivas();
    return rows.map(HidroserLista.fromMap).toList();
  }

  Future<HidroserLista?> getListaByCodigo(String codigo) async {
    final db = await _db.database;
    final rows = await db.query(
      'hidroser_listas',
      where: 'codigo = ?',
      whereArgs: [codigo],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HidroserLista.fromMap(rows.first);
  }

  /// Preguntas (items) del checklist asociado a una lista.
  /// Reutilizamos `formulario_items` filtrando por `tipo_actividad`.
  Future<List<Map<String, dynamic>>> getItemsForLista(
    HidroserLista lista,
  ) async {
    final db = await _db.database;
    return db.query(
      'formulario_items',
      where: 'tipo_actividad = ? AND activo = 1',
      whereArgs: [lista.tipoFormularioItems],
      orderBy: 'orden ASC',
    );
  }

  /// Inserta o actualiza una inspección y sus respuestas.
  Future<void> guardarInspeccion(
    HidroserInspeccion insp,
    List<HidroserRespuesta> respuestas,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'hidroser_inspecciones_pendientes',
        _inspeccionToRow(insp),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Reescribimos respuestas para mantener consistencia.
      await txn.delete(
        'hidroser_respuestas_pendientes',
        where: 'inspeccion_id = ?',
        whereArgs: [insp.id],
      );
      for (final r in respuestas) {
        await txn.insert(
          'hidroser_respuestas_pendientes',
          {...r.toMap(), 'subido': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Marca el PDF generado localmente para que el sync lo suba.
  Future<void> setPdfPathLocal(String inspeccionId, String pathLocal) async {
    final db = await _db.database;
    await db.update(
      'hidroser_inspecciones_pendientes',
      {'pdf_path_local': pathLocal, 'subido': 0},
      where: 'id = ?',
      whereArgs: [inspeccionId],
    );
  }

  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await _db.database;
    return db.query(
      'hidroser_inspecciones_pendientes',
      where: 'eliminado = 0 AND estado_final = ?',
      whereArgs: ['Borrador'],
      orderBy: 'created_at DESC',
    );
  }

  /// Devuelve la cabecera de una inspección pendiente junto con sus respuestas
  /// (clave `respuestas` en el mapa). Útil para reabrir un borrador.
  Future<Map<String, dynamic>?> getInspeccionConRespuestasById(
    String inspeccionId,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'hidroser_inspecciones_pendientes',
      where: 'id = ?',
      whereArgs: [inspeccionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final cabecera = Map<String, dynamic>.from(rows.first);
    final respuestas = await db.query(
      'hidroser_respuestas_pendientes',
      where: 'inspeccion_id = ?',
      whereArgs: [inspeccionId],
    );
    cabecera['respuestas'] = respuestas;
    return cabecera;
  }

  Future<void> eliminarBorrador(String inspeccionId) async {
    final db = await _db.database;
    await db.update(
      'hidroser_inspecciones_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [inspeccionId],
    );
  }

  Future<void> softDelete(String inspeccionId) async {
    final db = await _db.database;
    await db.update(
      'hidroser_inspecciones_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [inspeccionId],
    );
  }

  // --- Mappers ----------------------------------------------------------

  Map<String, dynamic> _inspeccionToRow(HidroserInspeccion i) {
    return {
      'id': i.id,
      'usuario_id': i.usuarioId,
      'empresa_id': i.empresaId,
      'lista_codigo': i.listaCodigo,
      'fecha_realizacion': i.fechaRealizacion.toIso8601String(),
      'correlativo': i.correlativo,
      'quien_inspecciona': i.quienInspecciona,
      'observaciones': i.observaciones,
      'campos_extra': jsonEncode(i.camposExtra),
      'firma_supervisor_nombre': i.firmaSupervisorNombre,
      'firma_operador_nombre': i.firmaOperadorNombre,
      'firma_supervisor_image': i.firmaSupervisorImage,
      'firma_operador_image': i.firmaOperadorImage,
      'estado_final': i.estadoFinal,
      'pdf_url': i.pdfUrl,
      'pdf_path_local': i.pdfPathLocal,
      'subido': 0,
      'eliminado': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // Helper expuesto para tests / debug
  Uint8List? bytesOrNull(Object? v) => v is Uint8List ? v : null;
}
