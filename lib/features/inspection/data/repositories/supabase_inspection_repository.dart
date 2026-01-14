import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';

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
    final String path =
        '$activityId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('evidencias').upload(path, File(file.path));
    // Nota: Aquí faltaría guardar la referencia en la tabla registro_fotografico en la nube,
    // pero eso lo maneja tu SyncService por ahora.
  }

  // --- MÉTODOS "VACÍOS" PARA CUMPLIR EL CONTRATO ---
  // Como los borradores son locales, aquí devolvemos vacío para que no rompa el código.

  @override
  Future<List<Map<String, dynamic>>> getBorradores() async {
    // La nube no gestiona "borradores locales", así que devuelve lista vacía.
    return [];
  }

  @override
  Future<Map<String, dynamic>> cargarRespuestasGuardadas(
    String activityId,
  ) async {
    // Si quisieras cargar datos desde la nube para editar, aquí iría la lógica.
    // Por ahora, devolvemos mapa vacío.
    return {};
  }
}
