import 'package:image_picker/image_picker.dart';
import '../../domain/models/formulario_item.dart';

abstract class InspectionRepository {
  // Obtener las preguntas
  Future<List<FormularioItem>> getItems(String tipoActividad);

  // Guardar las respuestas (en lote)
  Future<void> saveRespuestasBatch(List<Map<String, dynamic>> respuestas);

  // NUEVO: Guardar una foto (sea local o nube)
  // Retorna true si se guardó correctamente
  Future<void> saveFoto({
    required String activityId,
    required String? itemId, // Null si es foto general
    required XFile file,
    required String descripcion,
  });
}
