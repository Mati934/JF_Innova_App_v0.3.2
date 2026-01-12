import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/formulario_item.dart';

class InspectionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Obtener las preguntas según el tipo de actividad (Buceo vs Nave)
  Future<List<FormularioItem>> fetchItems(String tipoActividad) async {
    try {
      final response = await _supabase
          .from('formulario_items')
          .select()
          .eq('tipo_actividad', tipoActividad) // FILTRO CRÍTICO
          .eq('activo', true)
          .order('orden', ascending: true);

      return (response as List)
          .map((item) => FormularioItem.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error al cargar items: $e');
    }
  }

  // 2. Guardar respuesta individual (o podrías hacer un bulk insert al final)
  // En inspection_service.dart, actualiza el método saveAnswer:

  // OPTIMIZADO: Recibe una lista de mapas y hace 1 solo INSERT
  // --- MÉTODO NUEVO PARA BULK INSERT (OPTIMIZADO) ---
  Future<void> saveAnswersBatch(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    try {
      // Un solo viaje a la base de datos para todas las respuestas
      await _supabase.from('inspeccion_respuestas').insert(records);
    } catch (e) {
      throw Exception('Error en guardado masivo: $e');
    }
  }
}
