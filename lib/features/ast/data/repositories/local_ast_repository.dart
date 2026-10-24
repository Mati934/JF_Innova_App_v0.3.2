import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/models/ast_models.dart';

/// Repositorio local (SQLite) del módulo AST. Maneja la persistencia offline
/// de informes y hallazgos. El [SyncService] se encarga de subirlos a Supabase.
class LocalAstRepository {
  final DatabaseHelper _db;
  LocalAstRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  /// Inserta o actualiza un informe AST junto con sus hallazgos.
  /// Reescribe los hallazgos para mantener consistencia.
  Future<void> guardarInforme(
    AstInforme informe,
    List<AstHallazgo> hallazgos,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'ast_informes_pendientes',
        _informeToRow(informe),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'ast_hallazgos_pendientes',
        where: 'informe_id = ?',
        whereArgs: [informe.id],
      );
      for (final h in hallazgos) {
        await txn.insert('ast_hallazgos_pendientes', {
          ...h.toMap(),
          'subido': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Marca el PDF generado localmente para que el sync lo suba.
  Future<void> setPdfPathLocal(String informeId, String pathLocal) async {
    final db = await _db.database;
    await db.update(
      'ast_informes_pendientes',
      {'pdf_path_local': pathLocal, 'subido': 0},
      where: 'id = ?',
      whereArgs: [informeId],
    );
  }

  /// Borradores AST (estado `En Progreso`) no eliminados, más recientes
  /// primero. Los informes finalizados ya NO se listan aquí: una vez subidos
  /// viven exclusivamente en el historial general (evita duplicar el registro
  /// en el módulo y en el historial).
  /// Incluye `num_hallazgos`: cantidad de hallazgos asociados a cada informe.
  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT i.*,
             (SELECT COUNT(*)
                FROM ast_hallazgos_pendientes h
               WHERE h.informe_id = i.id) AS num_hallazgos
        FROM ast_informes_pendientes i
       WHERE i.eliminado = 0
         AND i.estado_final = 'En Progreso'
       ORDER BY i.created_at DESC
    ''');
  }

  /// Devuelve la cabecera + hallazgos (clave `hallazgos`) para reabrir.
  Future<Map<String, dynamic>?> getInformeConHallazgosById(
    String informeId,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'ast_informes_pendientes',
      where: 'id = ?',
      whereArgs: [informeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final cabecera = Map<String, dynamic>.from(rows.first);
    final hallazgos = await db.query(
      'ast_hallazgos_pendientes',
      where: 'informe_id = ?',
      whereArgs: [informeId],
      orderBy: 'numero ASC',
    );
    cabecera['hallazgos'] = hallazgos;
    return cabecera;
  }

  Future<void> eliminarBorrador(String informeId) async {
    final db = await _db.database;
    await db.update(
      'ast_informes_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [informeId],
    );
  }

  // --- Mappers --------------------------------------------------------------

  Map<String, dynamic> _informeToRow(AstInforme i) {
    return {
      'id': i.id,
      'usuario_id': i.usuarioId,
      'empresa_id': i.empresaId,
      'area_id': i.areaId,
      'centro_id': i.centroId,
      'contratista_id': i.contratistaId,
      'embarcacion_id': i.embarcacionId,
      'area_nombre': i.areaNombre,
      'centro_nombre': i.centroNombre,
      'contratista_nombre': i.contratistaNombre,
      'embarcacion_nombre': i.embarcacionNombre,
      'profesional': i.profesional,
      'fecha_realizacion': i.fechaRealizacion.toIso8601String(),
      'descripcion_actividad': i.descripcionActividad,
      'observaciones': i.observaciones,
      'correlativo': i.correlativo,
      'estado_final': i.estadoFinal,
      'pdf_url': i.pdfUrl,
      'pdf_path_local': i.pdfPathLocal,
      'fotos_generales': jsonEncode(i.fotosGenerales),
      'subido': 0,
      'eliminado': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
