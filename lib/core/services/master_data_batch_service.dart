import 'package:jf_innova_app/features/admin/domain/models/draft_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
// Ajusta esta ruta según la ubicación real en tu proyecto

/// 🎯 SERVICIO DE BATCH UPLOAD (Master Data)
///
/// Se encarga EXCLUSIVAMENTE de transformar el borrador local ordenado topológicamente
/// y enviarlo al RPC de PostgreSQL para su procesamiento transaccional atómico.
class MasterDataBatchService {
  final SupabaseClient supabaseClient;

  MasterDataBatchService(this.supabaseClient);

  /// Ejecuta la inserción o actualización masiva en una sola petición RPC.
  Future<void> executeOrderedBatchInsert(
    List<DraftEntity> orderedEntities, {
    required Function(String, String) onTempIdResolved,
    required Function(int, int) onProgress,
  }) async {
    try {
      debugPrint(
        '🚀 Iniciando preparación del payload para ${orderedEntities.length} entidades...',
      );

      // 1. Transformar las entidades al formato exacto que espera el RPC
      final List<Map<String, dynamic>> payload = orderedEntities.map((entity) {
        // Determinamos la acción:
        // Si es nuevo, es un INSERT y su tempId es temporal (ej. temp_embarcacion_123).
        // Si NO es nuevo, es un UPDATE y su tempId es en realidad el UUID real en la BD.
        final action = entity.isNew ? 'INSERT' : 'UPDATE';

        return {
          'action': action,
          'entityType': entity.entityType,
          'tempId': entity.tempId,
          'parentTempId': entity.parentTempId,
          'parentField': entity.parentField,
          'data': entity.data,
        };
      }).toList();

      // 2. Llamada única al RPC (Garantiza Atomicidad y Rollback automático si algo falla)
      debugPrint('📤 Enviando payload a Supabase...');
      final response = await supabaseClient.rpc(
        'fn_batch_insert_master_data',
        params: {'payload': payload},
      );

      // 3. Procesar el mapeo de respuesta (TempID -> UUID real)
      if (response != null) {
        final Map<String, dynamic> idMapping = response as Map<String, dynamic>;

        idMapping.forEach((tempId, realId) {
          onTempIdResolved(tempId, realId.toString());
        });
      }

      // 4. Reportar finalización
      onProgress(orderedEntities.length, orderedEntities.length);
      debugPrint('✅ Batch Upload completado con éxito.');
    } on PostgrestException catch (e) {
      debugPrint('❌ Error de PostgreSQL en Batch Upload: ${e.message}');
      throw Exception('Fallo en la base de datos: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error crítico en Batch Upload: $e');
      throw Exception('Error inesperado al sincronizar los datos maestros: $e');
    }
  }

  /// Valida que el usuario actual tenga los permisos necesarios antes de subir.
  Future<void> validateUserPermissions() async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception('Denegado: Usuario no autenticado en Supabase.');
    }

    try {
      // Consultamos el esquema real que me enviaste (usuarios -> roles)
      final response = await supabaseClient
          .from('usuarios')
          .select('''
            roles (
              nombre
            )
          ''')
          .eq('id', user.id)
          .single();

      // Extracción segura mapeando la respuesta
      final rolData = response['roles'];
      final String? nombreRol = rolData != null
          ? rolData['nombre'] as String?
          : null;

      // Ajusta 'Administrador' al string exacto que uses en tu tabla roles
      if (nombreRol != 'ADMINISTRADOR' && nombreRol != 'Admin') {
        throw Exception(
          'Acceso denegado: Requiere rol de Administrador. Rol actual: $nombreRol',
        );
      }

      debugPrint('✅ Permisos validados: El usuario es $nombreRol');
    } catch (e) {
      debugPrint('❌ Error validando rol: $e');
      throw Exception('No se pudo verificar el nivel de acceso del usuario.');
    }
  }
}
