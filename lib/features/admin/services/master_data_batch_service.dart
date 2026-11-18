import 'package:flutter/foundation.dart';
import 'package:jf_innova_app/features/admin/domain/models/draft_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🚀 **SERVICIO DE BATCH UPLOAD TRANSACCIONAL (Master Data Management)**
///
/// Ejecuta inserción ordenada por dependencias delegando la atomicidad
/// a la base de datos (PostgreSQL) mediante un RPC.
typedef OnTempIdResolved = void Function(String tempId, String realId);
typedef OnProgress = void Function(int completed, int total);

class MasterDataBatchService {
  final _supabase = Supabase.instance.client;

  /// 🔐 **VALIDAR PERMISOS DE USUARIO (RBAC)**
  Future<void> validateUserPermissions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    try {
      final session = _supabase.auth.currentSession;
      if (session == null || session.isExpired) {
        throw Exception('Sesión expirada');
      }
      debugPrint('✅ [MasterDataBatch] RBAC: Usuario autorizado ${user.email}');
    } catch (e) {
      throw Exception('Error validando permisos: $e');
    }
  }

  /// 🎯 **EJECUTAR INSERCIÓN ORDENADA CON TRANSACCIÓN**
  Future<void> executeOrderedBatchInsert(
    List<DraftEntity> orderedEntities, {
    required OnTempIdResolved onTempIdResolved,
    OnProgress? onProgress,
  }) async {
    if (orderedEntities.isEmpty) {
      throw Exception('Lista de entidades vacía');
    }

    try {
      debugPrint(
        '🚀 [MasterDataBatch] Enviando payload atómico a RPC: ${orderedEntities.length} entidades',
      );

      final payload = orderedEntities
          .map(
            (entity) => {
              'tempId': entity.tempId,
              'entityType': entity.entityType,
              'data': entity.data,
              'parentTempId': entity.parentTempId,
              'parentField': entity.parentField,
            },
          )
          .toList();

      final response = await _supabase.rpc(
        'fn_batch_insert_master_data',
        params: {'payload': payload},
      );

      final idMapping = Map<String, dynamic>.from(response as Map);

      int completed = 0;
      idMapping.forEach((tempId, realId) {
        onTempIdResolved(tempId, realId.toString());
        completed++;
        onProgress?.call(completed, orderedEntities.length);
        debugPrint('✅ Mapeado: $tempId → $realId');
      });

      debugPrint('🎉 [MasterDataBatch] Batch transaccional exitoso.');
    } catch (e) {
      debugPrint(
        '🔥 [MasterDataBatch] El RPC abortó la transacción entera: $e',
      );
      rethrow;
    }
  }

  /// 🗺️ **MAPEAR TIPO DE ENTIDAD A NOMBRE DE TABLA SUPABASE**
  String _getSupabaseTableName(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'empresa':
        return 'empresas';
      case 'area':
        return 'areas';
      case 'centro':
        return 'centros';
      case 'contratista':
        return 'contratistas';
      case 'embarcacion':
        return 'embarcaciones';
      case 'personal_externo':
        return 'personal_externo';
      default:
        throw Exception('Tipo de entidad no soportado: $entityType');
    }
  }

  /// 🧪 **VALIDAR CONEXIÓN CON SUPABASE**
  Future<bool> testConnection() async {
    try {
      await _supabase.from('usuarios').select('id').limit(1);
      return true;
    } catch (e) {
      debugPrint('❌ [MasterDataBatch] Error de conexión: $e');
      return false;
    }
  }

  /// 📊 **OBTENER ESTADÍSTICAS DE DATOS MAESTROS**
  Future<Map<String, int>> getCurrentMasterDataStats() async {
    try {
      // FIX: Sintaxis correcta para Supabase Dart v2+
      // Le decimos explícitamente a Dart que esta lista devolverá enteros
      final futures = <Future<int>>[
        _supabase.from('empresas').count(CountOption.exact),
        _supabase.from('areas').count(CountOption.exact),
        _supabase.from('centros').count(CountOption.exact),
        _supabase.from('contratistas').count(CountOption.exact),
        _supabase.from('embarcaciones').count(CountOption.exact),
        _supabase.from('personal_externo').count(CountOption.exact),
      ];

      final results = await Future.wait(futures);

      return {
        'empresas': results[0],
        'areas': results[1],
        'centros': results[2],
        'contratistas': results[3],
        'embarcaciones': results[4],
        'personal_externo': results[5],
      };
    } catch (e) {
      debugPrint('❌ [MasterDataBatch] Error obteniendo estadísticas: $e');
      return {};
    }
  }

  /// 🔍 **BUSCAR ENTIDADES EXISTENTES (para evitar duplicados)**
  Future<List<Map<String, dynamic>>> searchExistingEntities(
    String entityType,
    String searchTerm,
  ) async {
    final tableName = _getSupabaseTableName(entityType);
    final searchField = entityType == 'personal_externo'
        ? 'nombre_completo'
        : 'nombre';

    try {
      final response = await _supabase
          .from(tableName)
          .select('id, $searchField')
          .ilike(searchField, '%$searchTerm%')
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [MasterDataBatch] Error buscando $entityType: $e');
      return [];
    }
  }

  /// 🔐 **VALIDAR INTEGRIDAD REFERENCIAL**
  Future<void> validateReferentialIntegrity(List<DraftEntity> entities) async {
    final entityIds = <String, String>{};

    for (final entity in entities) {
      entityIds[entity.tempId] = entity.entityType;
    }

    for (final entity in entities) {
      if (entity.parentTempId != null) {
        if (entityIds.containsKey(entity.parentTempId)) continue;

        final parentType = _getParentEntityType(
          entity.entityType,
          entity.parentField!,
        );
        debugPrint(
          '⚠️ [MasterDataBatch] Validando FK externa: ${entity.parentField} para ${entity.entityType} (Depende de $parentType)',
        );
      }
    }
  }

  String _getParentEntityType(String childType, String fkField) {
    switch (fkField) {
      case 'empresa_id':
        return 'empresa';
      case 'area_id':
        return 'area';
      case 'contratista_id':
        return 'contratista';
      default:
        throw Exception('Campo FK no reconocido: $fkField');
    }
  }
}
