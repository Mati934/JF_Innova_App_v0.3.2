import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../sync/services/sync_service.dart';

class InspectionSetupController extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final _syncService = SyncService();

  // Estados de carga
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Listas de datos
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _centros = [];
  List<Map<String, dynamic>> _contratistas = [];
  List<Map<String, dynamic>> _embarcaciones = [];

  // Selecciones del usuario
  String? areaId;
  String? centroId;
  String? estadoPuerto = 'ABIERTO';
  String? actividadPuertoCerrado;
  String? tipoActividad;
  String? contratistaId;
  String? embarcacionId;

  // Datos calculados para la navegación posterior
  String? createdActivityId;
  String? finalActivityType;
  String? finalCentroNombre;
  bool esInspeccionCompleta = false;

  // Constantes de UI
  final List<String> tiposInspeccion = [
    'INSPECCION_BUCEO',
    'INSPECCION_EMBARCACION',
  ];
  final List<String> estadosPuerto = ['ABIERTO', 'CERRADO'];
  final List<String> opcionesPuertoCerrado = [
    'PRE_INSPECCION',
    'CHARLAS_SEGURIDAD',
    'LIMPIEZA_PLAYA',
    'SIN_ACTIVIDAD',
    'OTRAS_LABORES',
  ];

  // Getters
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get areas => _areas;
  List<Map<String, dynamic>> get centros => _centros;
  List<Map<String, dynamic>> get contratistas => _contratistas;
  List<Map<String, dynamic>> get embarcaciones => _embarcaciones;

  InspectionSetupController() {
    _cargarListasIniciales();
  }

  Future<void> _cargarListasIniciales() async {
    try {
      _isLoading = true;
      notifyListeners();

      final areasData = await _dbHelper.getAreas();
      final contratistasData = await _dbHelper.getContratistas();

      _areas = areasData;
      _contratistas = contratistasData;
    } catch (e) {
      _errorMessage = "Error cargando listas: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- MÉTODOS DE SELECCIÓN ---

  void setArea(String? v) {
    areaId = v;
    _cargarCentros(v);
    notifyListeners();
  }

  Future<void> _cargarCentros(String? areaId) async {
    if (areaId == null) {
      _centros = [];
      centroId = null;
    } else {
      final centrosData = await _dbHelper.getCentros(areaId);
      _centros = centrosData;
      centroId = null; // Reseteamos selección
    }
    notifyListeners();
  }

  void setCentro(String? v) {
    centroId = v;
    notifyListeners();
  }

  void setEstadoPuerto(String? v) {
    estadoPuerto = v;
    actividadPuertoCerrado = null; // Limpiamos al cambiar estado
    notifyListeners();
  }

  void setActividadPuertoCerrado(String? v) {
    actividadPuertoCerrado = v;
    notifyListeners();
  }

  void setTipoActividad(String? v) {
    tipoActividad = v;
    // Reseteamos dependencias
    contratistaId = null;
    embarcacionId = null;
    _embarcaciones = [];
    notifyListeners();
  }

  void setContratista(String? v) {
    contratistaId = v;
    _cargarEmbarcaciones(v);
    notifyListeners();
  }

  Future<void> _cargarEmbarcaciones(String? contratistaId) async {
    if (contratistaId == null) {
      _embarcaciones = [];
      embarcacionId = null;
    } else {
      final naves = await _dbHelper.getEmbarcaciones(contratistaId);
      _embarcaciones = naves;
      embarcacionId = null;
    }
    notifyListeners();
  }

  void setEmbarcacion(String? v) {
    embarcacionId = v;
    notifyListeners();
  }

  // --- LÓGICA DE GUARDADO ---
  bool _yaGuardado = false;
  // Retorna true si todo salió bien
  Future<bool> guardarActividad() async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (createdActivityId == null) {
        createdActivityId = const Uuid().v4();
      }

      // Regla de Negocio: ¿Es inspección completa o solo bitácora?
      esInspeccionCompleta =
          estadoPuerto == 'ABIERTO' ||
          (estadoPuerto == 'CERRADO' &&
              actividadPuertoCerrado == 'PRE_INSPECCION');

      finalActivityType = esInspeccionCompleta ? tipoActividad! : 'BITACORA';

      String? obs = estadoPuerto == 'CERRADO'
          ? 'Puerto Cerrado: $actividadPuertoCerrado'
          : null;

      // Obtener nombre del centro para la UI
      finalCentroNombre = _centros.firstWhere(
        (c) => c['id'] == centroId,
        orElse: () => {'nombre': 'Centro Desconocido'},
      )['nombre'];

      final datosActividad = {
        'id': createdActivityId,
        'usuario_id': userId,
        'centro_id': centroId,
        'fecha_realizacion': DateTime.now().toIso8601String(),
        'puerto_abierto': estadoPuerto == 'ABIERTO' ? 1 : 0,
        'tipo_actividad': finalActivityType,
        'observaciones_generales': obs,
        'contratista_id': esInspeccionCompleta ? contratistaId : null,
        'embarcacion_id': esInspeccionCompleta ? embarcacionId : null,
        'estado_final': 'En Seguimiento',
        'subido': 0,
      };

      await _dbHelper.saveActividadOffline(datosActividad);

      // Sincronización en segundo plano (Fire & Forget)
      _syncService
          .sincronizarTodo()
          .then((cantidad) {
            debugPrint("Sincronización background: $cantidad subidos");
          })
          .catchError((e) {
            debugPrint("Error sync background: $e");
          });

      return true;
    } catch (e) {
      _errorMessage = "Error guardando actividad: $e";
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // Validador manual simple para usar en el Controller
  bool validarFormulario() {
    if (areaId == null) return false;
    if (centroId == null) return false;
    if (estadoPuerto == 'CERRADO' && actividadPuertoCerrado == null)
      return false;

    // Si es inspección completa, validamos campos técnicos
    bool requiereTecnicos =
        estadoPuerto == 'ABIERTO' ||
        (estadoPuerto == 'CERRADO' &&
            actividadPuertoCerrado == 'PRE_INSPECCION');

    if (requiereTecnicos) {
      if (tipoActividad == null) return false;
      if (contratistaId == null) return false;
      // Embarcación puede ser opcional dependiendo de tu lógica, asumo que no por el código original
    }

    return true;
  }
}
