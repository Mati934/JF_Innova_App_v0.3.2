import 'package:flutter/material.dart';
import '../../data/repositories/cronograma_templates_repository.dart';

/// Controller para administración de Plantillas de Cronograma.
/// Maneja estado de tipos, plantillas y asignaciones.
class CronogramaTemplatesController extends ChangeNotifier {
  final _repository = CronogramaTemplatesRepository();

  // Estado
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _tiposTarea = [];
  List<Map<String, dynamic>> _plantillas = [];
  List<Map<String, dynamic>> _asignaciones = [];
  List<Map<String, dynamic>> _clientesEmpresas = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get tiposTarea => List.unmodifiable(_tiposTarea);
  List<Map<String, dynamic>> get plantillas => List.unmodifiable(_plantillas);
  List<Map<String, dynamic>> get asignaciones =>
      List.unmodifiable(_asignaciones);
  List<Map<String, dynamic>> get clientesEmpresas =>
      List.unmodifiable(_clientesEmpresas);

  /// Carga todos los datos iniciales
  Future<void> cargar() async {
    _setLoading(true);
    try {
      final tipos = await _repository.getTiposTarea();
      final plantillas = await _repository.getPlantillas();
      final asignaciones = await _repository.getAsignaciones();
      final clientesEmpresas = await _repository.getClientesEmpresas();

      _tiposTarea = tipos;
      _plantillas = plantillas;
      _asignaciones = asignaciones;
      _clientesEmpresas = clientesEmpresas;
      _error = null;
    } catch (e) {
      _error = 'Error cargando datos: $e';
      debugPrint('❌ CronogramaTemplatesController.cargar: $_error');
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TIPOS DE TAREA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> crearTipoTarea({
    required String codigo,
    required String nombre,
    String? targetModuleKey,
    bool usaPantallaGenerica = false,
  }) async {
    try {
      final tipo = await _repository.crearTipoTarea(
        codigo: codigo,
        nombre: nombre,
        targetModuleKey: targetModuleKey,
        usaPantallaGenerica: usaPantallaGenerica,
      );
      _tiposTarea.add(tipo);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error creando tipo: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  Future<void> actualizarTipoTarea({
    required String id,
    String? nombre,
    bool? activo,
  }) async {
    try {
      final tipo = await _repository.actualizarTipoTarea(
        id: id,
        nombre: nombre,
        activo: activo,
      );
      final idx = _tiposTarea.indexWhere((t) => t['id'] == id);
      if (idx >= 0) {
        _tiposTarea[idx] = tipo;
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error actualizando tipo: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PLANTILLAS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> crearPlantilla({
    required String nombre,
    String? descripcion,
  }) async {
    try {
      final plantilla = await _repository.crearPlantilla(
        nombre: nombre,
        descripcion: descripcion,
      );
      _plantillas.add(plantilla);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error creando plantilla: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  Future<void> actualizarPlantilla({
    required String id,
    String? nombre,
    String? descripcion,
    bool? activo,
  }) async {
    try {
      final plantilla = await _repository.actualizarPlantilla(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        activo: activo,
      );
      final idx = _plantillas.indexWhere((p) => p['id'] == id);
      if (idx >= 0) {
        _plantillas[idx] = plantilla;
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error actualizando plantilla: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  Future<void> eliminarPlantilla(String plantillaId) async {
    try {
      await _repository.eliminarPlantilla(plantillaId);
      _plantillas.removeWhere((p) => p['id'] == plantillaId);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error eliminando plantilla: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAREAS DE PLANTILLA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> agregarTareaAPlantilla({
    required String plantillaId,
    required String tipoTareaId,
    required String nombre,
    required String frecuencia,
    int orden = 0,
  }) async {
    try {
      await _repository.agregarTareaAPlantilla(
        plantillaId: plantillaId,
        tipoTareaId: tipoTareaId,
        nombre: nombre,
        frecuencia: frecuencia,
        orden: orden,
      );
      // Recargar plantilla
      await cargar();
    } catch (e) {
      _error = 'Error agregando tarea: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  Future<void> eliminarTareaPlantilla(String tareaId) async {
    try {
      await _repository.eliminarTareaPlantilla(tareaId);
      await cargar();
    } catch (e) {
      _error = 'Error eliminando tarea: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ASIGNACIONES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> crearAsignacion({
    required String plantillaId,
    required String clienteEmpresaId,
    DateTime? vigenteDesde,
    DateTime? vigentaHasta,
    bool autoGenerarPlan = true,
  }) async {
    try {
      final asignacion = await _repository.crearAsignacion(
        plantillaId: plantillaId,
        clienteEmpresaId: clienteEmpresaId,
        vigenteDesde: vigenteDesde,
        vigentaHasta: vigentaHasta,
        autoGenerarPlan: autoGenerarPlan,
      );
      _asignaciones.add(asignacion);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error creando asignación: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  Future<void> desactivarAsignacion(String asignacionId) async {
    try {
      await _repository.desactivarAsignacion(asignacionId);
      _asignaciones.removeWhere((a) => a['id'] == asignacionId);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error desactivando asignación: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  Future<void> generarCronogramaDesdeAsignacion({
    required String asignacionId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      await _repository.generarCronogramaDesdeAsignacion(
        asignacionId: asignacionId,
        desde: desde,
        hasta: hasta,
      );
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error generando cronograma: $e';
      debugPrint('❌ $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  String getNombreTipoTarea(String tipoTareaId) {
    try {
      return _tiposTarea
          .firstWhere((t) => t['id'] == tipoTareaId)['nombre']
          .toString();
    } catch (_) {
      return 'Tipo desconocido';
    }
  }

  String getNombrePlantilla(String plantillaId) {
    try {
      return _plantillas
          .firstWhere((p) => p['id'] == plantillaId)['nombre']
          .toString();
    } catch (_) {
      return 'Plantilla desconocida';
    }
  }
}
