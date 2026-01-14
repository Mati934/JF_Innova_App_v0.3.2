import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../../../core/database/database_helper.dart';

class LocalInspectionRepository implements InspectionRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>?> getActividad(String activityId) async {
    final db = await dbHelper.database;
    try {
      final result = await db.query(
        'actividades_pendientes',
        where: 'id = ?',
        whereArgs: [activityId],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint("❌ Error obteniendo actividad $activityId: $e");
      return null;
    }
  }

  Future<void> eliminarBorrador(String activityId) async {
    final db = await dbHelper.database;
    try {
      await db.delete(
        'fotos_pendientes',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );
      await db.delete(
        'inspeccion_respuestas_pendientes',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );
      await db.delete(
        'actividades_pendientes',
        where: 'id = ?',
        whereArgs: [activityId],
      );
      debugPrint("🗑️ Borrador eliminado correctamente: $activityId");
    } catch (e) {
      debugPrint("❌ Error eliminando borrador: $e");
    }
  }

  Future<void> saveActividad({
    required String id,
    required String tipoActividad,
    required String? centroId,
    required DateTime fecha,
  }) async {
    final db = await dbHelper.database;
    try {
      await db.insert('actividades_pendientes', {
        'id': id,
        'tipo_actividad': tipoActividad,
        'centro_id': centroId,
        'fecha_realizacion': fecha.toIso8601String(),
        'subido':
            0, // Al guardar cambios, reseteamos a 0 para que se vuelva a subir
        'estado_final': 'En Progreso',
        'puerto_abierto': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      debugPrint("💾 ACTIVIDAD GUARDADA: ID=$id");
    } catch (e) {
      debugPrint("❌ ERROR CRÍTICO AL GUARDAR ACTIVIDAD: $e");
      throw e;
    }
  }

  @override
  Future<List<FormularioItem>> getItems(String tipoActividad) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'formulario_items',
      where: 'tipo_actividad = ? AND activo = 1',
      whereArgs: [tipoActividad],
      orderBy: 'orden ASC',
    );
    return result.map((json) => FormularioItem.fromJson(json)).toList();
  }

  @override
  Future<void> saveRespuestasBatch(
    List<Map<String, dynamic>> respuestas,
  ) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    try {
      for (var resp in respuestas) {
        batch.delete(
          'inspeccion_respuestas_pendientes',
          where: 'actividad_id = ? AND item_id = ?',
          whereArgs: [resp['actividad_id'], resp['item_id']],
        );
        batch.insert('inspeccion_respuestas_pendientes', {
          'actividad_id': resp['actividad_id'],
          'item_id': resp['item_id'],
          'estado': resp['estado'],
          'observacion': resp['observacion'],
          'criticidad_registrada': resp['criticidad_registrada'],
          'subido': 0, // Marcamos como pendiente de subida
        });
      }
      await batch.commit(noResult: true);
      debugPrint("💾 Respuestas guardadas (${respuestas.length} items).");
    } catch (e) {
      debugPrint("❌ Error guardando respuestas batch: $e");
    }
  }

  @override
  Future<void> saveFoto({
    required String activityId,
    required String? itemId,
    required XFile file,
    required String descripcion,
  }) async {
    final db = await dbHelper.database;
    try {
      await db.insert('fotos_pendientes', {
        'actividad_id': activityId,
        'item_id': itemId,
        'local_path': file.path,
        'descripcion': descripcion,
        'subido': 0,
      });
      debugPrint("📸 Foto guardada localmente.");
    } catch (e) {
      debugPrint("❌ Error guardando foto: $e");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await dbHelper.database;
    try {
      // --- FIX: Quitamos el filtro 'subido = 0' ---
      // Queremos ver TODOS los borradores locales, aunque ya se hayan respaldado en la nube.
      final result = await db.rawQuery('''
        SELECT a.*, c.nombre as nombre_centro 
        FROM actividades_pendientes a
        LEFT JOIN centros c ON a.centro_id = c.id
        ORDER BY a.fecha_realizacion DESC
      ''');

      debugPrint("📋 Borradores recuperados para la UI: ${result.length}");
      return result;
    } catch (e) {
      debugPrint("❌ ERROR LEYENDO BORRADORES: $e");
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> cargarRespuestasGuardadas(
    String activityId,
  ) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'inspeccion_respuestas_pendientes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );
    Map<String, dynamic> mapa = {};
    for (var row in result) {
      final itemId = row['item_id'] as String;
      mapa[itemId] = {
        'estado': row['estado'],
        'observacion': row['observacion'],
        'criticidad': row['criticidad_registrada'],
      };
    }
    return mapa;
  }

  Future<List<Map<String, dynamic>>> getFotosPendientes(
    String activityId,
  ) async {
    final db = await dbHelper.database;
    return await db.query(
      'fotos_pendientes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );
  }
}
