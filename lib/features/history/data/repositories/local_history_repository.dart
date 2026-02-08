import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';

class LocalHistoryRepository {
  final _dbHelper = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getAllInspections() async {
    final db = await _dbHelper.database;
    try {
      // JOINs para obtener nombres reales en lugar de IDs
      // Ordenamos por fecha descendente (lo más nuevo arriba)
      final result = await db.rawQuery('''
        SELECT 
          a.id,
          a.numero_reporte,
          a.fecha_realizacion,
          a.estado_final,
          a.pdf_url,
          a.subido,
          a.tipo_actividad,
          a.numero_seguimiento,
          c.nombre as centro_nombre,
          ct.nombre as contratista_nombre,
          emb.nombre as embarcacion_nombre,
          u.nombre_completo as inspector_nombre
        FROM actividades_pendientes a
        LEFT JOIN centros c ON a.centro_id = c.id
        LEFT JOIN contratistas ct ON a.contratista_id = ct.id
        LEFT JOIN embarcaciones emb ON a.embarcacion_id = emb.id
        LEFT JOIN usuarios u ON a.usuario_id = u.id
        WHERE a.estado_final = 'En Seguimiento'
        ORDER BY a.fecha_realizacion DESC
      ''');

      return result;
    } catch (e) {
      debugPrint("❌ Error leyendo historial local: $e");
      return [];
    }
  }
}
