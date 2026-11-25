import 'package:flutter/material.dart';
import '../../../core/services/user_session.dart';
import '../data/repositories/local_history_repository.dart';
import '../data/repositories/supabase_history_repository.dart';

class HistoryController extends ChangeNotifier {
  final _cloudRepo = SupabaseHistoryRepository();

  bool _disposed = false;

  // Renombrado a 'records' porque ahora mezcla Inspecciones y Visitas
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;
  bool esAdmin = false;
  bool esSuperAdmin = false;

  // Filtros Activos
  String? filtroCentroId;
  String? filtroUsuarioId;
  String? filtroEmbarcacionId;
  String? filtroAreaId;
  String? filtroContratistaId;
  String? filtroTipo; // Ver [tipoLabel]; null = todos

  /// Tipos vistos en las cargas (no se achica al filtrar), para el filtro "Tipo".
  final Set<String> tiposDisponibles = {};

  /// Ids vistos en el historial por filtro (centro, usuario…): los selectores
  /// muestran solo opciones que tienen registros, no el catálogo completo.
  final Map<String, Set<String>> idsVistos = {};

  static const _filtrosPorId = [
    'centro_id',
    'usuario_id',
    'embarcacion_id',
    'area_id',
    'contratista_id',
  ];

  /// Filtra un catálogo a los ids con registros en el historial (más el
  /// valor ya elegido, para que su chip siga mostrando el nombre).
  List<Map<String, dynamic>> conRegistros(
    String key,
    List<Map<String, dynamic>> catalogo,
  ) {
    final vistos = idsVistos[key] ?? const <String>{};
    final elegido = activeFilters[key];
    return catalogo.where((item) {
      final id = item['id']?.toString();
      return id != null && (vistos.contains(id) || id == elegido);
    }).toList();
  }

  int _loadSequence = 0; // Evita race conditions en filtros rápidos

  List<Map<String, dynamic>> listaCentros = [];
  List<Map<String, dynamic>> listaUsuarios = [];
  List<Map<String, dynamic>> listaEmbarcaciones = [];
  List<Map<String, dynamic>> listaAreas = [];
  List<Map<String, dynamic>> listaContratistas = [];

  HistoryController() {
    _init();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _init() async {
    isLoading = true;
    _safeNotify();

    try {
      // El rol y la empresa activa se cargan al iniciar la sesión.
      final session = UserSession();
      esAdmin = session.esAdmin;
      esSuperAdmin = session.esSuperAdmin;
      debugPrint(
        '👤 Historial: admin=$esAdmin superAdmin=$esSuperAdmin '
        'empresa=${session.empresaId}',
      );

      // 2. Si es admin, cargamos catálogos en paralelo
      if (esAdmin) {
        final results = await Future.wait([
          _cloudRepo.getCentros(),
          _cloudRepo.getUsuarios(),
          _cloudRepo.getEmbarcaciones(),
          _cloudRepo.getAreas(),
          _cloudRepo.getContratistas(),
        ]);
        listaCentros = results[0];
        listaUsuarios = results[1];
        listaEmbarcaciones = results[2];
        listaAreas = results[3];
        listaContratistas = results[4];
      }

      // 3. Ejecutar primera carga de datos
      await cargarHistorial();
    } catch (e) {
      debugPrint("⚠️ Error crítico inicializando historial: $e");
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> cargarHistorial() async {
    final seq = ++_loadSequence;
    isLoading = true;
    _safeNotify();

    List<Map<String, dynamic>> cloud = [];
    try {
      cloud = await _cloudRepo.getHistorialGlobal(
        esAdmin: esAdmin,
        esSuperAdmin: esSuperAdmin,
        empresaId: UserSession().empresaId,
        filtroCentroId: filtroCentroId,
        filtroUsuarioId: filtroUsuarioId,
      );
    } catch (e) {
      debugPrint("⚠️ Fallo al cargar historial desde Supabase: $e");
    }

    // Siempre fusionamos con historial local para no perder visibilidad de
    // registros finalizados que aún no llegaron a la nube.
    List<Map<String, dynamic>> local = [];
    try {
      final localRecords = await LocalHistoryRepository().getAllInspections();
      local = localRecords.map(_mapLocal).toList();
    } catch (e) {
      debugPrint("⚠️ Historial local falló: $e");
    }

    if (seq != _loadSequence) return; // Descarta resultado stale

    try {
      final merged = mergeCloudAndLocalRecords(cloud, local)
          .map(
            (row) => enrichRow(
              row,
              areaPorCentro: _areaPorCentro,
              contratistaPorEmbarcacion: _contratistaPorEmbarcacion,
            ),
          )
          .toList();
      for (final row in merged) {
        tiposDisponibles.add(tipoLabel(row));
        for (final key in _filtrosPorId) {
          final id = row[key]?.toString();
          if (id != null && id.isNotEmpty) {
            idsVistos.putIfAbsent(key, () => <String>{}).add(id);
          }
        }
      }
      final filters = activeFilters;
      records = merged
          .where((row) => matchesHistoryFilters(row, filters))
          .toList();
      debugPrint("☁️ Historial unificado cargado: ${records.length} registros");
    } catch (e) {
      debugPrint("⚠️ Error armando historial: $e");
      records = [];
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Map<String, dynamic> _mapLocal(Map<String, dynamic> r) => {
    'id': r['id'],
    'modulo': 'Inspección',
    'tipo_registro': r['tipo_actividad'],
    'estado': r['estado_final'],
    'ubicacion': r['centro_nombre'] ?? 'Sin ubicación',
    'fecha_realizacion': r['fecha_realizacion'],
    'numero_reporte': r['numero_reporte'],
    'pdf_url': r['pdf_url'],
    'pdf_path_local': r['pdf_path_local'],
    'inspector_nombre': r['inspector_nombre'] ?? 'Usuario',
    'numero_seguimiento': r['numero_seguimiento'] ?? 0,
    'usuario_id': r['usuario_id'],
    'centro_id': r['centro_id'],
    'embarcacion_id': r['embarcacion_id'],
    'area_id': r['area_id'],
    'contratista_id': r['contratista_id'],
    'subido': r['subido'] ?? 0,
  };

  Map<String, String> get _areaPorCentro => {
    for (final c in listaCentros)
      if (c['area_id'] != null) c['id'].toString(): c['area_id'].toString(),
  };

  Map<String, String> get _contratistaPorEmbarcacion => {
    for (final e in listaEmbarcaciones)
      if (e['contratista_id'] != null)
        e['id'].toString(): e['contratista_id'].toString(),
  };

  /// Completa área (desde el centro) y contratista (desde la embarcación)
  /// cuando el registro no los trae: la RPC del historial no los devuelve.
  @visibleForTesting
  static Map<String, dynamic> enrichRow(
    Map<String, dynamic> row, {
    required Map<String, String> areaPorCentro,
    required Map<String, String> contratistaPorEmbarcacion,
  }) {
    final out = Map<String, dynamic>.from(row);
    final centro = row['centro_id']?.toString();
    if (out['area_id'] == null && centro != null) {
      out['area_id'] = areaPorCentro[centro];
    }
    final embarcacion = row['embarcacion_id']?.toString();
    if (out['contratista_id'] == null && embarcacion != null) {
      out['contratista_id'] = contratistaPorEmbarcacion[embarcacion];
    }
    return out;
  }

  /// Nombre del tipo de registro para el filtro "Tipo". Las inspecciones se
  /// separan por tipo (buceo, embarcación, registro de actividad); el resto
  /// usa el módulo que entrega el historial (AST, Hidroser, checklists…).
  static String tipoLabel(Map<String, dynamic> row) {
    final modulo = row['modulo']?.toString() ?? '';
    final tipo = row['tipo_registro']?.toString() ?? '';
    switch (tipo) {
      case 'INSPECCION_BUCEO':
        return 'Inspección de buceo';
      case 'INSPECCION_EMBARCACION':
        return 'Inspección de embarcación';
      case 'ACTIVIDAD_FORMATIVA':
        return 'Registro de actividad';
      case 'REGISTRO_INMERSIONES':
        return 'Registro de inmersiones';
      case 'BITACORA':
        return 'Bitácora';
    }
    return modulo.isEmpty ? 'Otro' : modulo;
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergeCloudAndLocalRecords(
    List<Map<String, dynamic>> cloud,
    List<Map<String, dynamic>> local,
  ) {
    // Preferimos nube para IDs repetidos y agregamos locales faltantes.
    final mergedById = <String, Map<String, dynamic>>{};

    for (final row in cloud) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      mergedById[id] = Map<String, dynamic>.from(row);
    }

    for (final row in local) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      mergedById.putIfAbsent(id, () => Map<String, dynamic>.from(row));
    }

    final list = mergedById.values.toList();
    list.sort((a, b) {
      final fa = DateTime.tryParse(a['fecha_realizacion']?.toString() ?? '');
      final fb = DateTime.tryParse(b['fecha_realizacion']?.toString() ?? '');
      if (fa == null && fb == null) return 0;
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fb.compareTo(fa);
    });
    return list;
  }

  /// true si [row] cumple todos los [filters] activos (claves de
  /// [activeFilters]). Se aplica igual a registros de la nube y locales.
  static bool matchesHistoryFilters(
    Map<String, dynamic> row,
    Map<String, String> filters,
  ) {
    for (final entry in filters.entries) {
      final value = entry.value;
      if (value.isEmpty) continue;
      final actual = entry.key == 'tipo'
          ? tipoLabel(row)
          : row[entry.key]?.toString();
      if (actual != value) return false;
    }
    return true;
  }

  /// Aplica filtros desde un Map (e.g. desde CustomFilterSheet).
  void applyFilters(Map<String, String> filters) {
    filtroTipo = filters['tipo'];
    filtroCentroId = filters['centro_id'];
    filtroUsuarioId = filters['usuario_id'];
    filtroEmbarcacionId = filters['embarcacion_id'];
    filtroAreaId = filters['area_id'];
    filtroContratistaId = filters['contratista_id'];
    cargarHistorial();
  }

  /// Mapa de filtros activos para pasar a CustomFilterSheet.
  Map<String, String> get activeFilters {
    final m = <String, String>{};
    if (filtroTipo != null) m['tipo'] = filtroTipo!;
    if (filtroCentroId != null) m['centro_id'] = filtroCentroId!;
    if (filtroUsuarioId != null) m['usuario_id'] = filtroUsuarioId!;
    if (filtroEmbarcacionId != null) m['embarcacion_id'] = filtroEmbarcacionId!;
    if (filtroAreaId != null) m['area_id'] = filtroAreaId!;
    if (filtroContratistaId != null) m['contratista_id'] = filtroContratistaId!;
    return m;
  }

  int get activeFilterCount => activeFilters.length;
}
