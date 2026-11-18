import '../../domain/formato_inspeccion.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/user_session.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_inspection_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

class InspectionSetupController extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final _syncService = SyncService();
  final _localRepo = LocalInspectionRepository();

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

  // --- NUEVA VARIABLE: TIPO DE REPORTE ---
  // false = Inicial (0), true = Consecutiva (1)
  bool _esConsecutiva = false;

  final TextEditingController numeroInformeController = TextEditingController();

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
  bool get esConsecutiva => _esConsecutiva; // Getter para la UI

  List<Map<String, dynamic>> get areas => _areas;
  List<Map<String, dynamic>> get centros => _centros;
  List<Map<String, dynamic>> get contratistas => _contratistas;
  List<Map<String, dynamic>> get embarcaciones => _embarcaciones;

  /// Formato interno del informe; queda guardado en la actividad.
  final String formato;

  InspectionSetupController({this.formato = FormatoInspeccion.estandar}) {
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
      // Fallback si empresa_areas no tiene datos aún
      final areasData = areasResult.isNotEmpty
          ? areasResult
          : await _dbHelper.getAreas();
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

  // NUEVO MÉTODO PARA CAMBIAR TIPO
  void setEsConsecutiva(bool valor) {
    _esConsecutiva = valor;
    notifyListeners();
  }

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

  void setCentro(String? v) async {
    centroId = v;
    notifyListeners();

    // --- CORRECCIÓN CLEAN CODE ---
    // NO llamamos a sugerirSiguienteNumeroReporte.
    // Dejamos el campo vacío para indicar que es nuevo y está pendiente.
    if (v != null) {
      numeroInformeController.text = ""; // Se queda vacío
    }
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
    if (v != null) _cargarEmbarcaciones(null);

    // Estimar número de informe cuando se selecciona tipo
    if (v != null) {
      _cargarNumeroEstimado(v);
    }
  }

  Future<void> _cargarNumeroEstimado(String tipoActividad) async {
    try {
      final estimado = await _localRepo.estimarSiguienteNumeroInforme(
        tipoActividad,
      );
      if (estimado != null) {
        numeroInformeController.text = "~$estimado";
      }
      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ Error estimando número: $e");
    }
  }

  void setContratista(String? v) {
    contratistaId = v;
    _cargarEmbarcaciones(v);
    notifyListeners();
  }

  /// Todas las embarcaciones, primero las del servicio elegido (las embarcaciones rotan de servicio: si solo se
  /// mostraban las del servicio, la que faltaba se creaba de nuevo y quedaba duplicada). La embarcación ya elegida
  /// se mantiene al cambiar el servicio.
  Future<void> _cargarEmbarcaciones(String? contratistaId) async {
    final carga = ++_cargaEmbarcaciones;
    final lista = await _dbHelper.getEmbarcacionesParaSelector(contratistaId);
    if (carga != _cargaEmbarcaciones) return; // llegó otra carga más nueva
    _embarcaciones = lista;
    notifyListeners();
  }

  int _cargaEmbarcaciones = 0;

  /// Si aún no hay servicio elegido, se propone el servicio actual de la embarcación (se puede cambiar).
  void setEmbarcacion(String? v) {
    embarcacionId = v?.toString();
    if (contratistaId == null && v != null) {
      final emb = _embarcaciones.where((e) => e['id']?.toString() == v);
      final servicio = emb.isEmpty ? null : emb.first['contratista_id'];
      if (servicio != null) setContratista(servicio.toString());
    }
    notifyListeners();
  }

  // --- LÓGICA DE GUARDADO ---
  // Retorna true si todo salió bien
  Future<bool> guardarActividad() async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // <--- 1. OBTENEMOS LA VERSIÓN AQUÍ AL PRINCIPIO
      final packageInfo = await PackageInfo.fromPlatform();
      final versionActual = "v${packageInfo.version}";
      // ----------------------------------------------

      final userId = Supabase.instance.client.auth.currentUser?.id;
      createdActivityId ??= const Uuid().v4();

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

        // <--- 2. AGREGAMOS LA VERSIÓN AL MAPA
        'app_version': versionActual,

        // -----------------------------------
        'estado_final': 'En Progreso',
        'numero_seguimiento': _esConsecutiva ? 1 : 0,
        'subido': 0,
        'numero_reporte': _obtenerNumeroParaGuardar(),
        if (formato != FormatoInspeccion.estandar) 'formato_informe': formato,
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

  /// Retorna null si el número es estimado (~) o vacío.
  /// Solo guarda números reales en SQLite.
  String? _obtenerNumeroParaGuardar() {
    final texto = numeroInformeController.text.trim();
    if (texto.isEmpty || texto.startsWith("~")) return null;
    return texto;
  }

  // Validador manual simple para usar en el Controller
  bool validarFormulario() {
    if (areaId == null) return false;
    if (centroId == null) return false;
    if (estadoPuerto == 'CERRADO' && actividadPuertoCerrado == null) {
      return false;
    }

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
