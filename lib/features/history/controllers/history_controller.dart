import 'package:flutter/material.dart';
import '../data/repositories/local_history_repository.dart';
import '../data/repositories/supabase_history_repository.dart';

class HistoryController extends ChangeNotifier {
  final _cloudRepo = SupabaseHistoryRepository();

  bool _disposed = false;

  // Renombrado a 'records' porque ahora mezcla Inspecciones y Visitas
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;
  bool esAdmin = false;

  // Filtros Activos
  String? filtroCentroId;
  String? filtroUsuarioId;
  String?
  filtroModulo; // Puede ser 'Inspección', 'Visita Técnica' o null para todos

  int _loadSequence = 0; // Evita race conditions en filtros rápidos

  List<Map<String, dynamic>> listaCentros = [];
  List<Map<String, dynamic>> listaUsuarios = [];

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
      // 1. Verificamos Rol
      esAdmin = await _cloudRepo.soyAdmin();
      debugPrint("👤 Rol Admin detectado: $esAdmin");

      // 2. Si es admin, cargamos catálogos en paralelo
      if (esAdmin) {
        final results = await Future.wait([
          _cloudRepo.getCentros(),
          _cloudRepo.getUsuarios(),
        ]);
        listaCentros = results[0];
        listaUsuarios = results[1];
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
      final result = await _cloudRepo.getHistorialGlobal(
        esAdmin: esAdmin,
        filtroCentroId: filtroCentroId,
        filtroUsuarioId: filtroUsuarioId,
        filtroModulo: filtroModulo,
      );
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

  void setFiltroModulo(String? modulo) {
    if (filtroModulo == modulo) return;
    filtroModulo = modulo;
    cargarHistorial();
  }

  /// Aplica filtros desde un Map (e.g. desde CustomFilterSheet).
  void applyFilters(Map<String, String> filters) {
    filtroModulo = filters['modulo'];
    filtroCentroId = filters['centro_id'];
    filtroUsuarioId = filters['usuario_id'];
    cargarHistorial();
  }

  /// Mapa de filtros activos para pasar a CustomFilterSheet.
  Map<String, String> get activeFilters {
    final m = <String, String>{};
    if (filtroModulo != null) m['modulo'] = filtroModulo!;
    if (filtroCentroId != null) m['centro_id'] = filtroCentroId!;
    if (filtroUsuarioId != null) m['usuario_id'] = filtroUsuarioId!;
    return m;
  }

  int get activeFilterCount => activeFilters.length;
}
