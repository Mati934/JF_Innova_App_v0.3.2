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
    required Map<String, dynamic>
    visitaCompletaMap, // Recibimos un solo mapa consolidado
    required List<String> fotosPaths,
  }) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      debugPrint('💾 TXN: Guardando Visita Técnica (Independiente)...');

      // 1. Guardar en la ÚNICA tabla de visitas
      await txn.insert(
        'visitas_tecnicas_pendientes',
        visitaCompletaMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Guardar Fotos (Si existen)
      if (fotosPaths.isNotEmpty) {
        for (var path in fotosPaths) {
          // Reutilizamos fotos_pendientes. La columna se llama 'actividad_id' por herencia,
          // pero ahora guardará el UUID de la visita. Funciona perfecto.
          await txn.insert('fotos_pendientes', {
            'actividad_id': visitaCompletaMap['id'],
            'item_id': 'visita_general',
            'local_path': path,
            'descripcion': 'Anexo fotográfico de Visita Técnica',
            'subido': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      debugPrint(
        '✅ TXN: Visita Técnica guardada con éxito (Sin acoplamiento).',
      );
    });
  }
}
