import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/models/buceo_equipment_inspeccion.dart';

/// Repositorio local del módulo Equipamiento de Buceo.
///
/// Usa tablas propias (`buceo_equipamiento_*`) independientes del módulo
/// Hidroser, espejando el patrón offline-first del resto de la app.
class LocalBuceoEquipmentRepository {
  final DatabaseHelper _db;
  LocalBuceoEquipmentRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  /// Preguntas (items) del checklist asociado a una lista, leídas del catálogo
  /// local `buceo_equipamiento_items` filtrando por `lista_codigo`.
  Future<List<Map<String, dynamic>>> getItemsForLista(
    String listaCodigo,
  ) async {
    final db = await _db.database;
    return db.query(
      'buceo_equipamiento_items',
      where: 'lista_codigo = ? AND activo = 1',
      whereArgs: [listaCodigo],
      orderBy: 'orden ASC',
    );
  }

  /// Entrega un aproximado local del próximo número de informe por lista.
  /// Se calcula con la cantidad de inspecciones no eliminadas en caché local.
  Future<int> getProximoNumeroInformeEstimado(String listaCodigo) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM buceo_equipamiento_inspecciones_pendientes
      WHERE lista_codigo = ?
        AND eliminado = 0
      ''',
      [listaCodigo],
    );
    final total = rows.isNotEmpty ? (rows.first['total'] as int? ?? 0) : 0;
    return total + 1;
  }

  /// Inserta o actualiza una inspección y sus respuestas.
  Future<void> guardarInspeccion(
    BuceoEquipmentInspeccion insp,
    List<BuceoEquipmentRespuesta> respuestas,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'buceo_equipamiento_inspecciones_pendientes',
        _inspeccionToRow(insp),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'buceo_equipamiento_respuestas_pendientes',
        where: 'inspeccion_id = ?',
        whereArgs: [insp.id],
      );
      for (final r in respuestas) {
        await txn.insert(
          'buceo_equipamiento_respuestas_pendientes',
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
      'buceo_equipamiento_inspecciones_pendientes',
      {'pdf_path_local': pathLocal, 'subido': 0},
      where: 'id = ?',
      whereArgs: [inspeccionId],
    );
  }

  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await _db.database;
    return db.query(
      'buceo_equipamiento_inspecciones_pendientes',
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
      'buceo_equipamiento_inspecciones_pendientes',
      where: 'id = ?',
      whereArgs: [inspeccionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final cabecera = Map<String, dynamic>.from(rows.first);
    final respuestas = await db.query(
      'buceo_equipamiento_respuestas_pendientes',
      where: 'inspeccion_id = ?',
      whereArgs: [inspeccionId],
    );
    cabecera['respuestas'] = respuestas;
    return cabecera;
  }

  Future<void> eliminarBorrador(String inspeccionId) async {
    final db = await _db.database;
    await db.update(
      'buceo_equipamiento_inspecciones_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [inspeccionId],
    );
  }

  Future<void> softDelete(String inspeccionId) async {
    final db = await _db.database;
    await db.update(
      'buceo_equipamiento_inspecciones_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [inspeccionId],
    );
  }

  // --- Mappers ----------------------------------------------------------

  Map<String, dynamic> _inspeccionToRow(BuceoEquipmentInspeccion i) {
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
