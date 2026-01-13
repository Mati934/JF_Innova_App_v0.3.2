import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart'; // Importa el contrato

class SupabaseInspectionRepository implements InspectionRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<FormularioItem>> getItems(String tipoActividad) async {
    final response = await _client
        .from('formulario_items')
        .select()
        .eq('tipo_actividad', tipoActividad)
        .eq('activo', true)
        .order('orden');

    return (response as List).map((e) => FormularioItem.fromJson(e)).toList();
  }

  @override
  Future<void> saveRespuestasBatch(
    List<Map<String, dynamic>> respuestas,
  ) async {
    await _client.from('inspeccion_respuestas').insert(respuestas);
  }

  @override
  Future<void> saveFoto({
    required String activityId,
    required String? itemId,
    required XFile file,
    required String descripcion,
  }) async {
    // Lógica de subida a Storage de Supabase
    final String path =
        '$activityId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('evidencias').upload(path, File(file.path));
    // ... guardar referencia en BD ...
  }
}
