import 'package:flutter/material.dart';
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
    isLoading = true;
    _safeNotify();

    try {
      records = await _cloudRepo.getHistorialGlobal(
        esAdmin: esAdmin,
        filtroCentroId: filtroCentroId,
        filtroUsuarioId: filtroUsuarioId,
        filtroModulo: filtroModulo,
      );
      debugPrint("☁️ Historial unificado cargado: ${records.length} registros");
    } catch (e) {
      debugPrint("⚠️ Fallo al cargar historial desde Supabase: $e");
      records = []; // Vaciamos para no mostrar datos fantasma
    } finally {
      isLoading = false;
      _safeNotify();
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
}
