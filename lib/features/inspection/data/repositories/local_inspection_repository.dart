import 'package:image_picker/image_picker.dart';
// import 'package:sqflite/sqflite.dart'; // Si lo usas

// --- AQUÍ ESTÁ LA CLAVE ---
// Borra el import que decía 'inspection_repository.dart' a secas.
// Mantén SOLO este que apunta a DOMAIN:
import '../../domain/repositories/inspection_repository.dart';

import '../../domain/models/formulario_item.dart';
import '../../../../core/database/database_helper.dart';

class LocalInspectionRepository implements InspectionRepository {
  final dbHelper = DatabaseHelper.instance;

  @override
  Future<List<FormularioItem>> getItems(String tipoActividad) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'formulario_items',
      where: 'tipo_actividad = ? AND activo = 1',
      whereArgs: [tipoActividad],
      orderBy: 'orden ASC',
    );

    if (result.isEmpty) return [];

    return result
        .map(
          (json) => FormularioItem(
            id: json['id'] as String,
            pregunta: json['pregunta'] as String,
            categoria: json['categoria'] as String,
            criticidad: json['criticidad'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveRespuestasBatch(
    List<Map<String, dynamic>> respuestas,
  ) async {
    final db = await dbHelper.database;
    final batch = db.batch();

    for (var resp in respuestas) {
      batch.insert('inspeccion_respuestas_pendientes', {
        'actividad_id': resp['actividad_id'],
        'item_id': resp['item_id'],
        'estado': resp['estado'],
        'observacion': resp['observacion'],
        'criticidad_registrada': resp['criticidad_registrada'],
        'subido': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> saveFoto({
    required String activityId,
    required String? itemId,
    required XFile file,
    required String descripcion,
  }) async {
    final db = await dbHelper.database;
    // Guardamos la ruta local (path) para subirla después cuando haya internet
    await db.insert('fotos_pendientes', {
      'actividad_id': activityId,
      'item_id': itemId, // Puede ser null
      'local_path': file.path,
      'descripcion': descripcion,
      'subido': 0,
    });
  }
}
