import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/services/user_session.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_ast_repository.dart';
import '../../domain/models/ast_models.dart';

/// Controlador de la pantalla de configuración inicial de un AST.
/// Reúne ubicación (área/centro), empresa (contratista), embarcación opcional,
/// profesional (automático) y fecha (automática pero modificable).
class AstSetupController extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final _repo = LocalAstRepository();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _centros = [];
  List<Map<String, dynamic>> _contratistas = [];
  List<Map<String, dynamic>> _embarcaciones = [];

  String? areaId;
  String? centroId;
  String? contratistaId;
  String? embarcacionId;

  DateTime fecha = DateTime.now();
  final String profesional = UserSession().nombreCompleto ?? '';

  String? createdInformeId;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get areas => _areas;
  List<Map<String, dynamic>> get centros => _centros;
  List<Map<String, dynamic>> get contratistas => _contratistas;
  List<Map<String, dynamic>> get embarcaciones => _embarcaciones;

  AstSetupController() {
    _cargarListasIniciales();
  }

  Future<void> _cargarListasIniciales() async {
    try {
      _isLoading = true;
      notifyListeners();

      final empresaId = UserSession().empresaId;
      final areasResult = empresaId != null
          ? await _dbHelper.getAreasByEmpresa(empresaId)
          : await _dbHelper.getAreas();
      _areas = areasResult.isNotEmpty
          ? areasResult
          : await _dbHelper.getAreas();
      _contratistas = await _dbHelper.getContratistas();
      _embarcaciones = await _dbHelper.getEmbarcacionesParaSelector(null);
    } catch (e) {
      _errorMessage = 'Error cargando listas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setArea(String? v) {
    areaId = v;
    centroId = null;
    _cargarCentros(v);
    notifyListeners();
  }

  Future<void> _cargarCentros(String? areaId) async {
    if (areaId == null) {
      _centros = [];
    } else {
      _centros = await _dbHelper.getCentros(areaId);
    }
    centroId = null;
    notifyListeners();
  }

  void setCentro(String? v) {
    centroId = v;
    notifyListeners();
  }

  void setContratista(String? v) {
    contratistaId = v;
    _cargarEmbarcaciones(v);
    notifyListeners();
  }

  /// Todas las embarcaciones, primero las del servicio elegido (rotan de servicio; ver `opcionesEmbarcacion`).
  /// La embarcación ya elegida se mantiene al cambiar el servicio.
  Future<void> _cargarEmbarcaciones(String? contratistaId) async {
    final carga = ++_cargaEmbarcaciones;
    final lista = await _dbHelper.getEmbarcacionesParaSelector(contratistaId);
    if (carga != _cargaEmbarcaciones) return; // llegó otra carga más nueva
    _embarcaciones = lista;
    notifyListeners();
  }

  int _cargaEmbarcaciones = 0;

  /// Si aún no hay empresa elegida, se propone el servicio actual de la embarcación (se puede cambiar).
  void setEmbarcacion(String? v) {
    embarcacionId = v;
    if (contratistaId == null && v != null) {
      final emb = _embarcaciones.where((e) => e['id'] == v);
      final servicio = emb.isEmpty ? null : emb.first['contratista_id'];
      if (servicio != null) setContratista(servicio.toString());
    }
    notifyListeners();
  }

  void setFecha(DateTime f) {
    fecha = f;
    notifyListeners();
  }

  bool validarFormulario() {
    if (areaId == null) return false;
    if (centroId == null) return false;
    if (contratistaId == null) return false;
    return true;
  }

  String? _nombreDe(List<Map<String, dynamic>> lista, String? id) {
    if (id == null) return null;
    final m = lista.firstWhere(
      (e) => e['id'] == id,
      orElse: () => const {'nombre': null},
    );
    return m['nombre'] as String?;
  }

  /// Crea y persiste el borrador inicial. Devuelve el id si tuvo éxito.
  Future<bool> guardarBorrador() async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      createdInformeId ??= const Uuid().v4();

      final informe = AstInforme(
        id: createdInformeId!,
        usuarioId: UserSession().userId,
        empresaId: UserSession().empresaId,
        areaId: areaId,
        centroId: centroId,
        contratistaId: contratistaId,
        embarcacionId: embarcacionId,
        areaNombre: _nombreDe(_areas, areaId),
        centroNombre: _nombreDe(_centros, centroId),
        contratistaNombre: _nombreDe(_contratistas, contratistaId),
        embarcacionNombre: _nombreDe(_embarcaciones, embarcacionId),
        profesional: profesional,
        fechaRealizacion: fecha,
        estadoFinal: 'En Progreso',
      );

      await _repo.guardarInforme(informe, const []);

      // Sync silencioso en segundo plano (no bloquea la navegación).
      SyncService().sincronizarTodo().catchError((_) => 0);

      return true;
    } catch (e) {
      _errorMessage = 'Error creando AST: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
