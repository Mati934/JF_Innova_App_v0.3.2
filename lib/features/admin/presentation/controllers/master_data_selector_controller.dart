import 'package:flutter/foundation.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/models/selector_option.dart';
import '../controllers/batch_draft_controller.dart';

// =============================================================================
// MasterDataSelectorController
// =============================================================================
//
// Responsabilidades:
//   1. Escuchar al BatchDraftController (ChangeNotifier).
//   2. Consultar SQLite vía los métodos específicos de DatabaseHelper.
//   3. Fusionar ambas fuentes en listas [SelectorOption] inmutables.
//   4. Filtrar en cascada: cuando cambia la empresa seleccionada, recalcula
//      las áreas disponibles filtrando por empresa_id (real o temporal).
//   5. Exponer a la vista ÚNICAMENTE listas de [SelectorOption] y los IDs
//      seleccionados actualmente — cero lógica en el widget build().

class MasterDataSelectorController extends ChangeNotifier {
  MasterDataSelectorController({
    required DatabaseHelper db,
    required BatchDraftController draftController,
  }) : _db = db,
       _draftController = draftController;

  final DatabaseHelper _db;
  final BatchDraftController _draftController;

  // ---------------------------------------------------------------------------
  // Estado interno
  // ---------------------------------------------------------------------------

  bool _isLoading = false;
  String? _error;

  List<SelectorOption> _empresas = const [];
  List<SelectorOption> _todasLasAreas = const [];
  List<SelectorOption> _contratistas = const [];
  List<SelectorOption> _embarcaciones = const [];

  // Mapa interno: areaId → empresaId (real o temporal), para el filtro cascada
  Map<String, String?> _areaEmpresaMap = {};

  String? _selectedEmpresaId;
  String? _selectedAreaId;
  String? _selectedContratistaId;
  String? _selectedEmbarcacionId;

  // ---------------------------------------------------------------------------
  // Getters públicos — estado de carga
  // ---------------------------------------------------------------------------

  bool get isLoading => _isLoading;
  String? get error => _error;

  // ---------------------------------------------------------------------------
  // Getters públicos — listas para los dropdowns
  // ---------------------------------------------------------------------------

  List<SelectorOption> get empresas => List.unmodifiable(_empresas);

  /// Áreas filtradas por la empresa actualmente seleccionada.
  /// Si no hay empresa seleccionada, devuelve todas.
  List<SelectorOption> get areasFiltradas {
    if (_selectedEmpresaId == null) return List.unmodifiable(_todasLasAreas);
    return List.unmodifiable(
      _todasLasAreas
          .where((a) => _areaEmpresaMap[a.id] == _selectedEmpresaId)
          .toList(),
    );
  }

  List<SelectorOption> get contratistas => List.unmodifiable(_contratistas);
  List<SelectorOption> get embarcaciones => List.unmodifiable(_embarcaciones);

  // ---------------------------------------------------------------------------
  // Getters públicos — selección actual
  // ---------------------------------------------------------------------------

  String? get selectedEmpresaId => _selectedEmpresaId;
  String? get selectedAreaId => _selectedAreaId;
  String? get selectedContratistaId => _selectedContratistaId;
  String? get selectedEmbarcacionId => _selectedEmbarcacionId;

  // ---------------------------------------------------------------------------
  // Helpers para el CustomDropdown
  // ---------------------------------------------------------------------------

  /// Convierte la lista de opciones en los strings que espera [CustomDropdown].
  List<String> toDisplayNames(List<SelectorOption> options) =>
      options.map((o) => o.displayName).toList();

  /// Devuelve el [SelectorOption] correspondiente a un displayName.
  SelectorOption? findByDisplayName(
    List<SelectorOption> options,
    String displayName,
  ) {
    try {
      return options.firstWhere((o) => o.displayName == displayName);
    } catch (_) {
      return null;
    }
  }

  /// Dado un ID (real o temporal), devuelve su displayName para usarlo como
  /// valor inicial del CustomDropdown (parámetro `value`).
  String? displayNameForId(List<SelectorOption> options, String? id) {
    if (id == null) return null;
    try {
      return options.firstWhere((o) => o.id == id).displayName;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Ciclo de vida
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _draftController.addListener(_onDraftsChanged);
    await _loadAll();
  }

  @override
  void dispose() {
    _draftController.removeListener(_onDraftsChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Selección — llamados desde la vista
  // ---------------------------------------------------------------------------

  void selectEmpresa(String? displayName) {
    if (displayName == null || displayName.isEmpty) {
      _selectedEmpresaId = null;
      _selectedAreaId = null;
      notifyListeners();
      return;
    }
    final option = findByDisplayName(_empresas, displayName);
    if (option == null || option.id == _selectedEmpresaId) return;
    _selectedEmpresaId = option.id;
    _selectedAreaId = null; // Cascada: resetear área al cambiar empresa
    notifyListeners();
  }

  void selectArea(String? displayName) {
    if (displayName == null || displayName.isEmpty) {
      _selectedAreaId = null;
      notifyListeners();
      return;
    }
    final option = findByDisplayName(areasFiltradas, displayName);
    if (option == null || option.id == _selectedAreaId) return;
    _selectedAreaId = option.id;
    notifyListeners();
  }

  void selectContratista(String? displayName) {
    if (displayName == null || displayName.isEmpty) {
      _selectedContratistaId = null;
      notifyListeners();
      return;
    }
    final option = findByDisplayName(_contratistas, displayName);
    if (option == null || option.id == _selectedContratistaId) return;
    _selectedContratistaId = option.id;
    notifyListeners();
  }

  void selectEmbarcacion(String? displayName) {
    if (displayName == null || displayName.isEmpty) {
      _selectedEmbarcacionId = null;
      notifyListeners();
      return;
    }
    final option = findByDisplayName(_embarcaciones, displayName);
    if (option == null || option.id == _selectedEmbarcacionId) return;
    _selectedEmbarcacionId = option.id;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Carga de datos — privado
  // ---------------------------------------------------------------------------

  void _onDraftsChanged() => _loadAll();

  Future<void> _loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cargamos en paralelo todas las entidades
      await Future.wait([
        _loadEmpresas(),
        _loadAreas(),
        _loadContratistas(),
        _loadEmbarcaciones(),
      ]);
    } catch (e, st) {
      _error = 'Error al cargar datos maestros: $e';
      debugPrint('[MasterDataSelectorController] Error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadEmpresas() async {
    // DatabaseHelper.getAllEmpresas() — método existente en tu helper
    final dbRows = await _db.getAllEmpresas();
    final dbOptions = dbRows.map(
      (row) => SelectorOption.fromDb(
        id: row['id'] as String,
        nombre: row['nombre'] as String? ?? '',
        tipo: TipoEntidad.empresa,
      ),
    );

    // BatchDraftController.getEntitiesByType() — método existente en el controller
    final draftOptions = _draftController
        .getEntitiesByType('empresa')
        .map(
          (d) => SelectorOption.fromDraft(
            tempId: d.tempId,
            nombre: d.displayName,
            tipo: TipoEntidad.empresa,
          ),
        );

    _empresas = [...dbOptions, ...draftOptions];
  }

  Future<void> _loadAreas() async {
    // DatabaseHelper.getAreas() — devuelve todas las áreas con empresa_id
    final dbRows = await _db.getAreas();
    final dbItems = dbRows.map(
      (row) => _AreaItem(
        option: SelectorOption.fromDb(
          id: row['id'] as String,
          nombre: row['nombre'] as String? ?? '',
          tipo: TipoEntidad.area,
        ),
        empresaId: row['empresa_id'] as String?,
      ),
    );

    final draftItems = _draftController
        .getEntitiesByType('area')
        .map(
          (d) => _AreaItem(
            option: SelectorOption.fromDraft(
              tempId: d.tempId,
              nombre: d.displayName,
              tipo: TipoEntidad.area,
            ),
            // La FK empresa_id se guarda en data al crear el área draft
            empresaId: d.data['empresa_id'] as String?,
          ),
        );

    final allItems = [...dbItems, ...draftItems];

    // Reconstruimos el mapa de cascada: areaId → empresaId
    _areaEmpresaMap = {
      for (final item in allItems) item.option.id: item.empresaId,
    };

    _todasLasAreas = allItems.map((i) => i.option).toList();
  }

  Future<void> _loadContratistas() async {
    final dbRows = await _db.getContratistas();
    final dbOptions = dbRows.map(
      (row) => SelectorOption.fromDb(
        id: row['id'] as String,
        nombre: row['nombre'] as String? ?? '',
        tipo: TipoEntidad.contratista,
      ),
    );

    final draftOptions = _draftController
        .getEntitiesByType('contratista')
        .map(
          (d) => SelectorOption.fromDraft(
            tempId: d.tempId,
            nombre: d.displayName,
            tipo: TipoEntidad.contratista,
          ),
        );

    _contratistas = [...dbOptions, ...draftOptions];
  }

  Future<void> _loadEmbarcaciones() async {
    // DatabaseHelper.getAllEmbarcaciones() — devuelve todas sin filtro
    final dbRows = await _db.getAllEmbarcaciones();
    final dbOptions = dbRows.map(
      (row) => SelectorOption.fromDb(
        id: row['id'] as String,
        nombre: row['nombre'] as String? ?? '',
        tipo: TipoEntidad.embarcacion,
      ),
    );

    final draftOptions = _draftController
        .getEntitiesByType('embarcacion')
        .map(
          (d) => SelectorOption.fromDraft(
            tempId: d.tempId,
            nombre: d.displayName,
            tipo: TipoEntidad.embarcacion,
          ),
        );

    _embarcaciones = [...dbOptions, ...draftOptions];
  }
}

// ---------------------------------------------------------------------------
// Clase auxiliar interna — no expuesta fuera del archivo
// ---------------------------------------------------------------------------

class _AreaItem {
  final SelectorOption option;
  final String? empresaId;
  const _AreaItem({required this.option, required this.empresaId});
}
