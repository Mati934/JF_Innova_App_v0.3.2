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
  String? filtroTipoInspeccion;
  String?
  filtroModulo; // Puede ser 'Inspección', 'Visita Técnica' o null para todos

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

    try {
      final cloudResult = await _cloudRepo.getHistorialGlobal(
        esAdmin: esAdmin,
        esSuperAdmin: esSuperAdmin,
        empresaId: UserSession().empresaId,
        filtroCentroId: filtroCentroId,
        filtroUsuarioId: filtroUsuarioId,
        filtroModulo: filtroModulo,
        filtroEmbarcacionId: filtroEmbarcacionId,
        filtroAreaId: filtroAreaId,
        filtroContratistaId: filtroContratistaId,
        filtroTipoInspeccion: filtroTipoInspeccion,
      );

      // Siempre fusionamos con historial local para no perder visibilidad de
      // registros finalizados que aún no llegaron a la nube.
      final localRepo = LocalHistoryRepository();
      final localRecords = await localRepo.getAllInspections();
      final localMapped = localRecords.map((r) {
        return <String, dynamic>{
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
          'centro_id': null,
          'embarcacion_id': null,
          'subido': r['subido'] ?? 0,
        };
      }).toList();

      final result = mergeCloudAndLocalRecords(cloudResult, localMapped);
      if (seq != _loadSequence) return; // Descarta resultado stale
      records = result;
      debugPrint("☁️ Historial unificado cargado: ${records.length} registros");
    } catch (e) {
      if (seq != _loadSequence) return;
      debugPrint("⚠️ Fallo al cargar historial desde Supabase: $e");
      // Fallback: intentar cargar desde SQLite local
      try {
        final localRepo = LocalHistoryRepository();
        final localRecords = await localRepo.getAllInspections();
        records = localRecords.map((r) {
          return <String, dynamic>{
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
            'centro_id': null,
            'embarcacion_id': null,
            'subido': r['subido'] ?? 0,
          };
        }).toList();
        debugPrint("📱 Historial local cargado: ${records.length} registros");
      } catch (localError) {
        debugPrint("⚠️ Historial local también falló: $localError");
        records = [];
      }
    } finally {
      if (seq == _loadSequence) {
        isLoading = false;
        _safeNotify();
      }
    }
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

  // --- Mutadores de Filtros ---

  void setFiltroCentro(String? id) {
    if (filtroCentroId == id) return;
    filtroCentroId = id;
    cargarHistorial();
  }

  void setFiltroUsuario(String? id) {
    if (filtroUsuarioId == id) return;
    filtroUsuarioId = id;
    cargarHistorial();
  }

  void setFiltroEmbarcacion(String? id) {
    if (filtroEmbarcacionId == id) return;
    filtroEmbarcacionId = id;
    cargarHistorial();
  }

  void setFiltroArea(String? id) {
    if (filtroAreaId == id) return;
    filtroAreaId = id;
    cargarHistorial();
  }

  void setFiltroContratista(String? id) {
    if (filtroContratistaId == id) return;
    filtroContratistaId = id;
    cargarHistorial();
  }

  void setFiltroTipoInspeccion(String? tipo) {
    if (filtroTipoInspeccion == tipo) return;
    filtroTipoInspeccion = tipo;
    cargarHistorial();
  }

  void setFiltroModulo(String? modulo) {
    if (filtroModulo == modulo) return;
    filtroModulo = modulo;
    cargarHistorial();
  }

  static bool matchesHistoryFilters(
    Map<String, dynamic> row,
    Map<String, String> filters,
  ) {
    final tipoInspeccion = filters['tipo_inspeccion'];
    if (tipoInspeccion != null &&
        tipoInspeccion.isNotEmpty &&
        row['tipo_registro']?.toString() != tipoInspeccion) {
      return false;
    }

    final areaId = filters['area_id'];
    if (areaId != null && areaId.isNotEmpty) {
      final rowArea = row['area_id']?.toString();
      if (rowArea == null || rowArea != areaId) return false;
    }

    final contratistaId = filters['contratista_id'];
    if (contratistaId != null && contratistaId.isNotEmpty) {
      final rowContratista = row['contratista_id']?.toString();
      if (rowContratista == null || rowContratista != contratistaId) {
        return false;
      }
    }

    return true;
  }

  /// Aplica filtros desde un Map (e.g. desde CustomFilterSheet).
  void applyFilters(Map<String, String> filters) {
    filtroModulo = filters['modulo'];
    filtroCentroId = filters['centro_id'];
    filtroUsuarioId = filters['usuario_id'];
    filtroEmbarcacionId = filters['embarcacion_id'];
    filtroAreaId = filters['area_id'];
    filtroContratistaId = filters['contratista_id'];
    filtroTipoInspeccion = filters['tipo_inspeccion'];
    cargarHistorial();
  }

  /// Mapa de filtros activos para pasar a CustomFilterSheet.
  Map<String, String> get activeFilters {
    final m = <String, String>{};
    if (filtroModulo != null) m['modulo'] = filtroModulo!;
    if (filtroCentroId != null) m['centro_id'] = filtroCentroId!;
    if (filtroUsuarioId != null) m['usuario_id'] = filtroUsuarioId!;
    if (filtroEmbarcacionId != null) m['embarcacion_id'] = filtroEmbarcacionId!;
    if (filtroAreaId != null) m['area_id'] = filtroAreaId!;
    if (filtroContratistaId != null) m['contratista_id'] = filtroContratistaId!;
    if (filtroTipoInspeccion != null) {
      m['tipo_inspeccion'] = filtroTipoInspeccion!;
    }
    return m;
  }

  int get activeFilterCount => activeFilters.length;
}
