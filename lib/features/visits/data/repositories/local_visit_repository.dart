import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/models/visit_model.dart';

class LocalVisitRepository {
  final dbHelper = DatabaseHelper.instance;

  // Obtener Regiones (Áreas)
  Future<List<Map<String, dynamic>>> getRegiones() async {
    return await dbHelper.getAreas();
  }

  // Obtener Lugares de Visita (Centros) filtrados por Región
  Future<List<Map<String, dynamic>>> getCentrosPorRegion(String areaId) async {
    return await dbHelper.getCentros(areaId);
  }

  Future<List<String>> getRegionesHistoricas() async {
    final db = await dbHelper.database; // ✅ Usamos la instancia de la clase

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT region 
      FROM visitas_tecnicas_pendientes
      WHERE region IS NOT NULL AND trim(region) != ''
      ORDER BY region ASC
    ''');

    return maps.map((e) => e['region'] as String).toList();
  }

  Future<List<String>> getCentrosHistoricos() async {
    final db = await dbHelper.database; // ✅ Usamos la instancia de la clase

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT lugar_visita 
      FROM visitas_tecnicas_pendientes
      WHERE lugar_visita IS NOT NULL AND trim(lugar_visita) != ''
      ORDER BY lugar_visita ASC
    ''');

    return maps.map((e) => e['lugar_visita'] as String).toList();
  }

  Future<void> saveVisitaCompleta({
    required Map<String, dynamic> visitaMap,
    required List<String> fotosPaths,
    required bool
    esBorrador, // 👈 EL JEFE DEL ESTADO (Igual que en Inspecciones)
  }) async {
    final db = await dbHelper.database;
    final estadoFinal = esBorrador ? 'En Progreso' : 'Finalizada';

    // Aseguramos el estado antes de insertar
    visitaMap['estado_final'] = estadoFinal;
    visitaMap['subido'] = 0; // Forzamos sync al guardar cambios

    await db.transaction((txn) async {
      debugPrint('💾 TXN: Guardando Visita Técnica (Borrador: $esBorrador)...');

      await txn.insert(
        'visitas_tecnicas_pendientes',
        visitaMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // BLINDAJE ANTI FUGAS DE MEMORIA Y DUPLICADOS
      if (fotosPaths.isNotEmpty) {
        // Regla de Inspecciones: Limpiamos antes de insertar para no acumular basura
        await txn.delete(
          'fotos_pendientes',
          where: 'actividad_id = ?',
          whereArgs: [visitaMap['id']],
        );
        for (var path in fotosPaths) {
          await txn.insert('fotos_pendientes', {
            'actividad_id': visitaMap['id'],
            'item_id': 'visita_general',
            'local_path': path,
            'descripcion': 'Anexo fotográfico de Visita Técnica',
            'subido': 0,
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await dbHelper.database;
    final result = await db.query(
      'visitas_tecnicas_pendientes',
      where: 'estado_final = ? AND subido = 0 AND eliminado = 0',
      whereArgs: ['En Progreso'],
      orderBy: 'fecha_realizacion DESC',
    );

    // INYECCIÓN VITAL: El DraftListWidget necesita 'tipo_actividad' y 'nombre_centro' para funcionar
    return result.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['tipo_actividad'] = 'Visita Técnica';
      map['nombre_centro'] =
          map['lugar_visita']; // Homologamos nombre para la UI
      return map;
    }).toList();
  }

  // Soft delete para ser llamado desde el Home
  Future<void> eliminarBorrador(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'visitas_tecnicas_pendientes',
      {
        'estado_final': 'Eliminada',
        'eliminado': 1,
        'subido': 0, // Fuerza al SyncService a leer esto y subir el cambio
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
