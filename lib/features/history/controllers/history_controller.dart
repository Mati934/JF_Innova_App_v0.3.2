import 'package:flutter/material.dart';
import '../data/repositories/local_history_repository.dart';
import '../data/repositories/supabase_history_repository.dart';

class HistoryController extends ChangeNotifier {
  final _localRepo = LocalHistoryRepository();
  final _cloudRepo = SupabaseHistoryRepository();

  List<Map<String, dynamic>> inspections = [];
  bool isLoading = true;
  bool esAdmin = false;

  // Filtros
  String? filtroCentroId;
  String? filtroUsuarioId;

  List<Map<String, dynamic>> listaCentros = [];
  List<Map<String, dynamic>> listaUsuarios = [];

  HistoryController() {
    _init();
  }

  Future<void> _init() async {
    isLoading = true;
    notifyListeners();

    try {
      // 1. Verificamos Rol
      esAdmin = await _cloudRepo.soyAdmin();
      debugPrint("👤 Rol Admin detectado: $esAdmin");

      // 2. Si es admin, cargamos las listas para los filtros
      if (esAdmin) {
        // Usamos Future.wait para cargar en paralelo (más rápido)
        final results = await Future.wait([
          _cloudRepo.getCentros(),
          _cloudRepo.getUsuarios(),
        ]);
        listaCentros = results[0];
        listaUsuarios = results[1];
      }

      // 3. Cargar datos
      await cargarHistorial();
    } catch (e) {
      debugPrint("⚠️ Error inicializando historial: $e");
      // Si falla la inicialización (ej. sin internet), cargamos local
      await _cargarLocal();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cargarHistorial() async {
    isLoading = true;
    notifyListeners();

    try {
      // Intentamos ir a la Nube primero para tener datos frescos
      inspections = await _cloudRepo.getHistorialGlobal(
        esAdmin: esAdmin,
        filtroCentroId: filtroCentroId,
        filtroUsuarioId: filtroUsuarioId,
      );
      debugPrint(
        "☁️ Historial cargado desde Nube: ${inspections.length} items",
      );
    } catch (e) {
      debugPrint("⚠️ Fallo nube ($e). Cargando local...");
      await _cargarLocal();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _cargarLocal() async {
    // El repo local no soporta filtros complejos ni datos de otros usuarios
    // Así que solo traemos lo que hay en el dispositivo
    inspections = await _localRepo.getAllInspections();
    debugPrint("🏠 Historial Local cargado: ${inspections.length} items");
  }

  void setFiltroCentro(String? id) {
    filtroCentroId = id;
    cargarHistorial();
  }

  void setFiltroUsuario(String? id) {
    filtroUsuarioId = id;
    cargarHistorial();
  }
}
