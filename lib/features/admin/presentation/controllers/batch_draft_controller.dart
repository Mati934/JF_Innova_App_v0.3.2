import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../admin/domain/models/draft_entity.dart';
import '../../../admin/domain/models/dependency_graph.dart';
import '../../../admin/services/master_data_batch_service.dart';

/// 🎯 **CONTROLADOR DE BORRADOR BATCH (Master Data Management)**
///
/// Maneja el estado local del "carrito de compras" para inserción masiva.
/// Resuelve dependencias padre-hijo con IDs temporales antes del batch upload.
class BatchDraftController extends ChangeNotifier {
  final MasterDataBatchService _batchService;
  final _uuid = const Uuid();

  // 📝 Estado del borrador local
  final List<DraftEntity> _draftItems = [];
  final Map<String, String> _tempIdMapping = {}; // tempId -> realId
  final DependencyGraph _dependencyGraph = DependencyGraph();

  // 🎛️ UI State
  bool _isUploading = false;
  bool _isValidating = false;
  String? _errorMessage;
  final Map<String, int> _validationErrors = {}; // entityType -> errorCount

  BatchDraftController(this._batchService);

  // === GETTERS ===
  List<DraftEntity> get draftItems => UnmodifiableListView(_draftItems);
  Map<String, String> get tempIdMapping => UnmodifiableMapView(_tempIdMapping);
  bool get isUploading => _isUploading;
  bool get isValidating => _isValidating;
  bool get isEmpty => _draftItems.isEmpty;
  bool get hasErrors => _errorMessage != null || _validationErrors.isNotEmpty;
  String? get errorMessage => _errorMessage;
  Map<String, int> get validationErrors => UnmodifiableMapView(_validationErrors);

  // 📊 Estadísticas del draft
  int get totalItems => _draftItems.length;
  Map<String, int> get itemsByType => _groupItemsByType();

  Map<String, int> _groupItemsByType() {
    final counts = <String, int>{};
    for (final item in _draftItems) {
      counts[item.entityType] = (counts[item.entityType] ?? 0) + 1;
    }
    return counts;
  }

  /// 🔄 **AÑADIR ENTIDAD AL DRAFT**
  /// Genera ID temporal, registra dependencias y valida integridad.
  Future<String> addEntity({
    required String entityType,
    required Map<String, dynamic> data,
    String? parentTempId,
    String? parentField,
  }) async {
    try {
      final tempId = _generateTempId(entityType);

      // Crear entidad draft
      final entity = DraftEntity(
        tempId: tempId,
        entityType: entityType,
        data: Map<String, dynamic>.from(data),
        parentTempId: parentTempId,
        parentField: parentField,
        isNew: true,
      );

      // Registrar en grafo de dependencias
      _dependencyGraph.addNode(tempId, entityType);
      if (parentTempId != null) {
        _dependencyGraph.addDependency(tempId, parentTempId);
      }

      // Validar que no haya ciclos
      if (_dependencyGraph.hasCycles()) {
        throw Exception(
          'No se puede crear ciclo de dependencias. '
          'Verifica la relación con ${_getEntityName(parentTempId ?? '')}.'
        );
      }

      _draftItems.add(entity);
      _clearErrors();
      notifyListeners();

      debugPrint('✅ [BatchDraft] Entidad añadida: $entityType ($tempId)');
      return tempId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// ✏️ **EDITAR ENTIDAD EXISTENTE**
  Future<void> updateEntity(String tempId, Map<String, dynamic> newData) async {
    try {
      final index = _draftItems.indexWhere((item) => item.tempId == tempId);
      if (index == -1) {
        throw Exception('Entidad no encontrada: $tempId');
      }

      final updatedEntity = _draftItems[index].copyWith(
        data: Map<String, dynamic>.from(newData),
      );

      _draftItems[index] = updatedEntity;
      _clearErrors();
      notifyListeners();

      debugPrint('✅ [BatchDraft] Entidad actualizada: $tempId');
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 🗑️ **ELIMINAR ENTIDAD DEL DRAFT**
  Future<void> removeEntity(String tempId) async {
    try {
      // Verificar dependencias antes de eliminar
      final dependents = _dependencyGraph.getDependents(tempId);
      if (dependents.isNotEmpty) {
        final names = dependents.map(_getEntityName).join(', ');
        throw Exception(
          'No se puede eliminar. Los siguientes elementos dependen de esta entidad: $names'
        );
      }

      // Eliminar del grafo y lista
      _dependencyGraph.removeNode(tempId);
      _draftItems.removeWhere((item) => item.tempId == tempId);
      _clearErrors();
      notifyListeners();

      debugPrint('✅ [BatchDraft] Entidad eliminada: $tempId');
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 🧹 **LIMPIAR TODOS LOS BORRADORES**
  void clearAllDrafts() {
    _draftItems.clear();
    _dependencyGraph.clear();
    _tempIdMapping.clear();
    _clearErrors();
    notifyListeners();
    debugPrint('🧹 [BatchDraft] Todos los borradores limpiados');
  }

  /// ✅ **VALIDAR INTEGRIDAD ANTES DEL UPLOAD**
  Future<bool> validateIntegrity() async {
    _isValidating = true;
    _validationErrors.clear();
    notifyListeners();

    try {
      // 1. Verificar dependencias resueltas
      for (final item in _draftItems) {
        if (item.parentTempId != null) {
          final parentExists = _draftItems.any((p) => p.tempId == item.parentTempId);
          if (!parentExists) {
            _validationErrors[item.entityType] =
                (_validationErrors[item.entityType] ?? 0) + 1;
          }
        }
      }

      // 2. Verificar reglas de negocio específicas por tipo
      await _validateBusinessRules();

      // 3. Verificar que no haya ciclos (redundante pero seguro)
      if (_dependencyGraph.hasCycles()) {
        throw Exception('Se detectaron dependencias circulares');
      }

      final isValid = _validationErrors.isEmpty;
      if (!isValid) {
        _errorMessage = 'Se encontraron ${_validationErrors.values.fold(0, (a, b) => a + b)} errores de validación';
      }

      return isValid;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isValidating = false;
      notifyListeners();
    }
  }

  /// 🚀 **EJECUTAR BATCH UPLOAD COMPLETO**
  /// Ordena por dependencias y ejecuta inserción transaccional.
  Future<bool> executeBatchUpload() async {
    if (_draftItems.isEmpty) {
      _errorMessage = 'No hay elementos para subir';
      notifyListeners();
      return false;
    }

    // Pre-validación obligatoria
    final isValid = await validateIntegrity();
    if (!isValid) return false;

    _isUploading = true;
    _clearErrors();
    notifyListeners();

    try {
      // 1. Verificar permisos de usuario (RBAC)
      await _batchService.validateUserPermissions();

      // 2. Obtener orden topológico
      final sortedIds = _dependencyGraph.topologicalSort();
      final orderedEntities = _orderEntitiesByDependencies(sortedIds);

      debugPrint('🎯 [BatchDraft] Iniciando batch upload de ${orderedEntities.length} entidades');
      debugPrint('📋 [BatchDraft] Orden de inserción: ${sortedIds.join(' → ')}');

      // 3. Ejecutar inserción ordenada con transacción
      _tempIdMapping.clear();
      await _batchService.executeOrderedBatchInsert(
        orderedEntities,
        onTempIdResolved: (tempId, realId) {
          _tempIdMapping[tempId] = realId;
          debugPrint('🔗 [BatchDraft] ID mapeado: $tempId → $realId');
        },
        onProgress: (completed, total) {
          // TODO: Agregar callback de progreso si necesitas barra de progreso
          debugPrint('📈 [BatchDraft] Progreso: $completed/$total');
        },
      );

      // 4. Limpiar draft exitosamente
      clearAllDrafts();

      debugPrint('🎉 [BatchDraft] Batch upload completado exitosamente');
      return true;

    } catch (e) {
      _errorMessage = 'Error en batch upload: ${e.toString()}';
      debugPrint('❌ [BatchDraft] Batch upload falló: $e');
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// 🔍 **BUSCAR ENTIDADES POR TIPO**
  List<DraftEntity> getEntitiesByType(String entityType) {
    return _draftItems.where((item) => item.entityType == entityType).toList();
  }

  /// 🔍 **BUSCAR ENTIDAD POR ID TEMPORAL**
  DraftEntity? getEntityById(String tempId) {
    try {
      return _draftItems.firstWhere((item) => item.tempId == tempId);
    } catch (e) {
      return null;
    }
  }

  // === MÉTODOS PRIVADOS ===

  String _generateTempId(String entityType) {
    return 'temp_${entityType.toLowerCase()}_${_uuid.v4().substring(0, 8)}';
  }

  String _getEntityName(String tempId) {
    final entity = getEntityById(tempId);
    if (entity == null) return tempId;

    final nombre = entity.data['nombre'] ?? entity.data['nombre_completo'] ?? 'Sin nombre';
    return '${entity.entityType}: $nombre';
  }

  List<DraftEntity> _orderEntitiesByDependencies(List<String> sortedIds) {
    final ordered = <DraftEntity>[];
    for (final tempId in sortedIds) {
      final entity = getEntityById(tempId);
      if (entity != null) {
        ordered.add(entity);
      }
    }
    return ordered;
  }

  void _clearErrors() {
    _errorMessage = null;
    _validationErrors.clear();
  }

  /// 🔍 **VALIDACIONES DE REGLAS DE NEGOCIO**
  Future<void> _validateBusinessRules() async {
    for (final item in _draftItems) {
      try {
        switch (item.entityType) {
          case 'empresa':
            _validateEmpresa(item);
            break;
          case 'area':
            _validateArea(item);
            break;
          case 'centro':
            _validateCentro(item);
            break;
          case 'contratista':
            _validateContratista(item);
            break;
          case 'embarcacion':
            _validateEmbarcacion(item);
            break;
          case 'personal_externo':
            _validatePersonalExterno(item);
            break;
        }
      } catch (e) {
        _validationErrors[item.entityType] =
            (_validationErrors[item.entityType] ?? 0) + 1;
      }
    }
  }

  void _validateEmpresa(DraftEntity item) {
    final nombre = item.data['nombre']?.toString().trim();
    if (nombre == null || nombre.isEmpty) {
      throw Exception('Empresa debe tener nombre');
    }
  }

  void _validateArea(DraftEntity item) {
    final nombre = item.data['nombre']?.toString().trim();
    if (nombre == null || nombre.isEmpty) {
      throw Exception('Área debe tener nombre');
    }
    // Si hay empresa_id en el futuro, validar aquí
  }

  void _validateCentro(DraftEntity item) {
    final nombre = item.data['nombre']?.toString().trim();
    if (nombre == null || nombre.isEmpty) {
      throw Exception('Centro debe tener nombre');
    }
    if (item.parentTempId == null) {
      throw Exception('Centro debe tener área padre');
    }
  }

  void _validateContratista(DraftEntity item) {
    final nombre = item.data['nombre']?.toString().trim();
    if (nombre == null || nombre.isEmpty) {
      throw Exception('Contratista debe tener nombre');
    }
  }

  void _validateEmbarcacion(DraftEntity item) {
    final nombre = item.data['nombre']?.toString().trim();
    if (nombre == null || nombre.isEmpty) {
      throw Exception('Embarcación debe tener nombre');
    }
    if (item.parentTempId == null) {
      throw Exception('Embarcación debe tener contratista padre');
    }
  }

  void _validatePersonalExterno(DraftEntity item) {
    final nombreCompleto = item.data['nombre_completo']?.toString().trim();
    final rut = item.data['rut']?.toString().trim();

    if (nombreCompleto == null || nombreCompleto.isEmpty) {
      throw Exception('Personal debe tener nombre completo');
    }
    if (rut == null || rut.isEmpty) {
      throw Exception('Personal debe tener RUT');
    }
    if (item.parentTempId == null) {
      throw Exception('Personal debe tener contratista padre');
    }
  }

  @override
  void dispose() {
    clearAllDrafts();
    super.dispose();
  }
}