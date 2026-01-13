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
}
