import 'package:image_picker/image_picker.dart';
import '../../domain/models/formulario_item.dart';

abstract class InspectionRepository {
  Future<List<FormularioItem>> getItems(String tipoActividad);

  Future<void> saveRespuestasBatch(List<Map<String, dynamic>> respuestas);

  Future<void> saveFoto({
    required String activityId,
    required String? itemId,
    required XFile file,
    required String descripcion,
  });
  // --- NUEVOS MÉTODOS PARA BORRADORES ---

  // 1. Obtener lista de inspecciones que no se han terminado/subido
  Future<List<Map<String, dynamic>>> getBorradores();

  // 2. Recuperar las respuestas que ya guardamos de una inspección específica
  Future<Map<String, dynamic>> cargarRespuestasGuardadas(String activityId);
}
