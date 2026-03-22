import 'package:jf_innova_app/features/inspection/domain/models/buceo_verificacion_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/participante_model.dart';
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
    // Usamos upsert para que si ya existe la respuesta, la actualice
    await _client.from('inspeccion_respuestas').upsert(respuestas);
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
  }

  @override
  Future<List<Map<String, dynamic>>> getBorradores() async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> cargarRespuestasGuardadas(
    String activityId,
  ) async {
    return {};
  }

  // --- IMPLEMENTACIÓN REAL PARA BUCEO (SUPABASE) ---

  @override
  Future<void> guardarVerificacionesBuceo(BuceoVerificacionModel data) async {
    // Upsert: Si existe lo actualiza, si no, lo crea.
    await _client.from('verificaciones_buceo').upsert(data.toMap());
  }

  @override
  Future<BuceoVerificacionModel?> getVerificacionesBuceo(
    String activityId,
  ) async {
    final response = await _client
        .from('verificaciones_buceo')
        .select()
        .eq('actividad_id', activityId)
        .maybeSingle(); // Retorna null si no encuentra nada, en vez de error

    if (response != null) {
      return BuceoVerificacionModel.fromMap(response);
    }
    return null;
  }

  @override
  Future<void> guardarParticipantes(
    String activityId,
    List<ParticipanteModel> participantes,
  ) async {
    // Estrategia: Borrar y Reinsertar (igual que en SQLite) para mantener consistencia

    // 1. Borrar relaciones existentes para esta actividad
    await _client
        .from('actividad_participantes')
        .delete()
        .eq('actividad_id', activityId);

    if (participantes.isEmpty) return;

    // 2. Asegurar que el personal exista en la tabla maestra (personal_externo)
    final personalData = participantes
        .map(
          (p) => {
            'id': p
                .personalId, // OJO: Si usas IDs temporales locales, esto podría dar conflicto en la nube si no son UUIDs válidos.
            'nombre_completo': p.nombreCompleto,
            'rut': p.rut,
            'cargo': p.cargo,
            'matricula': p.matricula,
            'activo': true,
          },
        )
        .toList();

    // Upsert del personal (ignora duplicados o actualiza datos)
    await _client.from('personal_externo').upsert(personalData);

    // 3. Crear las relaciones en la tabla intermedia
    final relacionesData = participantes
        .map(
          (p) => {
            'actividad_id': activityId,
            'personal_id': p.personalId,
            'rol_en_faena': p.cargo,
            'condiciones_optimas': p.condicionesOptimas,
          },
        )
        .toList();

    await _client.from('actividad_participantes').insert(relacionesData);
  }

  @override
  Future<List<ParticipanteModel>> getParticipantes(String activityId) async {
    // Hacemos un JOIN con la tabla personal_externo
    final response = await _client
        .from('actividad_participantes')
        .select('*, personal_externo(*)')
        .eq('actividad_id', activityId);

    final List<dynamic> data = response as List<dynamic>;

    return data.map((item) {
      // Mapeo manual porque Supabase devuelve el JOIN anidado
      final personal = item['personal_externo'] ?? {};

      return ParticipanteModel(
        personalId: item['personal_id'],
        // Si el JOIN trajo datos, usamos esos. Si no, fallback vacío.
        nombreCompleto: personal['nombre_completo'] ?? '',
        rut: personal['rut'] ?? '',
        cargo: item['rol_en_faena'], // El rol específico de esta faena
        matricula: personal['matricula'] ?? '', // <--- AGREGAR MATRICULA
        contratistaId: personal['contratista_id'], // <--- AGREGAR CONTRATISTA_ID
        condicionesOptimas: item['condiciones_optimas'] == true,
      );
    }).toList();
  }
}
