import 'package:flutter/foundation.dart';
import '../../data/repositories/cronograma_repository.dart';

class CronogramaAdminController extends ChangeNotifier {
  final _repo = CronogramaRepository();
  bool _disposed = false;

  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> clientesEmpresas = [];
  List<Map<String, dynamic>> grupos = [];
  List<Map<String, dynamic>> usuarios = [];

  CronogramaAdminController() {
    cargar();
  }

  Future<void> cargar() async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final results = await Future.wait([
        _repo.getClientesEmpresas(),
        _repo.getGrupos(),
        _repo.getUsuarios(),
      ]);
      clientesEmpresas = results[0];
      grupos = results[1];
      usuarios = results[2];
    } catch (e) {
      error = 'Error cargando datos de cronograma: $e';
      debugPrint(error);
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<bool> crearClienteEmpresa(String nombre, String? rut) async {
    try {
      await _repo.crearClienteEmpresa(nombre, rut);
      clientesEmpresas = await _repo.getClientesEmpresas();
      _safeNotify();
      return true;
    } catch (e) {
      debugPrint('Error creando empresa de cronograma: $e');
      return false;
    }
  }

  Future<bool> editarClienteEmpresa(
    String id,
    String nombre,
    String? rut,
    bool activo,
  ) async {
    try {
      await _repo.editarClienteEmpresa(id, nombre, rut, activo);
      clientesEmpresas = await _repo.getClientesEmpresas();
      _safeNotify();
      return true;
    } catch (e) {
      debugPrint('Error editando empresa de cronograma: $e');
      return false;
    }
  }

  Future<bool> crearGrupo(String nombre, String? descripcion) async {
    try {
      await _repo.crearGrupo(nombre, descripcion);
      grupos = await _repo.getGrupos();
      _safeNotify();
      return true;
    } catch (e) {
      debugPrint('Error creando grupo de cronograma: $e');
      return false;
    }
  }

  Future<bool> editarGrupo(
    String id,
    String nombre,
    String? descripcion,
    bool activo,
  ) async {
    try {
      await _repo.editarGrupo(id, nombre, descripcion, activo);
      grupos = await _repo.getGrupos();
      _safeNotify();
      return true;
    } catch (e) {
      debugPrint('Error editando grupo de cronograma: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMiembrosGrupo(String grupoId) {
    return _repo.getMiembrosGrupo(grupoId);
  }

  Future<bool> agregarMiembro(String grupoId, String usuarioId) async {
    try {
      await _repo.agregarMiembro(grupoId, usuarioId);
      return true;
    } catch (e) {
      debugPrint('Error agregando miembro: $e');
      return false;
    }
  }

  Future<bool> quitarMiembro(String membresiaId) async {
    try {
      await _repo.quitarMiembro(membresiaId);
      return true;
    } catch (e) {
      debugPrint('Error quitando miembro: $e');
      return false;
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
