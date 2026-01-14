import 'package:image_picker/image_picker.dart';
import '../models/formulario_item.dart';
// IMPORTANTE: Asegúrate que estas rutas existan
import '../models/buceo_verificacion_model.dart';
import '../models/participante_model.dart';

abstract class InspectionRepository {
  Future<List<FormularioItem>> getItems(String tipoActividad);

  Future<void> saveRespuestasBatch(List<Map<String, dynamic>> respuestas);

  Future<void> saveFoto({
    required String activityId,
    required String? itemId,
    required XFile file,
    required String descripcion,
  });

  // 1. Obtener lista de inspecciones que no se han terminado/subido
  Future<List<Map<String, dynamic>>> getBorradores();

  // 2. Recuperar las respuestas que ya guardamos de una inspección específica
  Future<Map<String, dynamic>> cargarRespuestasGuardadas(String activityId);

  // --- MÉTODOS NUEVOS PARA BUCEO (AGREGADOS) ---

  // Guardar/Actualizar la cabecera de verificaciones
  Future<void> guardarVerificacionesBuceo(BuceoVerificacionModel data);

  // Obtener la cabecera
  Future<BuceoVerificacionModel?> getVerificacionesBuceo(String activityId);

  // Guardar la lista completa de participantes (Borra y reinserta)
  Future<void> guardarParticipantes(
    String activityId,
    List<ParticipanteModel> participantes,
  );

  // Obtener la lista de participantes
  Future<List<ParticipanteModel>> getParticipantes(String activityId);
}
