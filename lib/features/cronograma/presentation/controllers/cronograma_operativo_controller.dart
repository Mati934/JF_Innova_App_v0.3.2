import 'package:flutter/foundation.dart';
import '../../data/repositories/cronograma_operativo_repository.dart';

class CronogramaOperativoController extends ChangeNotifier {
  final CronogramaOperativoRepository _repository =
      CronogramaOperativoRepository();

  bool isLoading = false;
  String? error;
  List<Map<String, dynamic>> tareas = [];
  DateTime periodoDesde = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime periodoHasta = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  Future<void> cargarMes([DateTime? mes]) async {
    final selected = mes ?? DateTime.now();
    periodoDesde = DateTime(selected.year, selected.month, 1);
    periodoHasta = DateTime(selected.year, selected.month + 1, 0);
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      tareas = await _repository.getTareasDelPeriodo(
        desde: periodoDesde,
        hasta: periodoHasta,
      );
    } catch (e) {
      error = 'No se pudo cargar tu cronograma: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> tomar(String id) => _ejecutar(() => _repository.tomarTarea(id));

  Future<bool> soltar(String id) =>
      _ejecutar(() => _repository.soltarTarea(id));

  Future<bool> iniciar(String id) =>
      _ejecutar(() => _repository.iniciarTarea(id));

  Future<bool> completar(String id, String comentario) => _ejecutar(
    () => _repository.completarTarea(tareaId: id, comentario: comentario),
  );

  Future<List<Map<String, dynamic>>> historial(String id) {
    return _repository.getHistorial(id);
  }

  Future<bool> _ejecutar(Future<bool> Function() action) async {
    try {
      final result = await action();
      await cargarMes(periodoDesde);
      return result;
    } catch (e) {
      error = 'No se pudo actualizar la tarea: $e';
      notifyListeners();
      return false;
    }
  }
}
