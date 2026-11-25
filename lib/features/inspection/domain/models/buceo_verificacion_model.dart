class BuceoVerificacionModel {
  final String actividadId;

  // CHECKS DE SEGURIDAD
  bool autorizacionAutoridadMaritima;
  bool induccionCentroCultivo;
  bool permisoBuceoCentroCorrecto;
  bool planContingenciasCentroOk;
  bool examenesOcupacionalesVigentes;

  // --- NUEVO: DETALLES POR ITEM (Observación + Foto) ---
  String? obsAutorizacion;
  String? imgAutorizacion;

  String? obsInduccion;
  String? imgInduccion;

  String? obsPermiso;
  String? imgPermiso;

  String? obsPlan;
  String? imgPlan;

  String? obsExamenes;
  String? imgExamenes;
  // ----------------------------------------------------

  // ESTADOS
  String? observacionGeneral;
  String? estadoManual;

  // --- PERSONAL CONTRATISTA (EMPRESA BUCEO) ---
  String? supervisorNombre;
  String? supervisorRut;

  // --- PERSONAL CENTRO (AQUACHILE - NUEVOS) ---
  String? encargadoCentro; // Jefe de Centro
  String? supervisorCentro; // Supervisor de Turno

  // --- DATOS TÉCNICOS ---

  // Compresor 1
  String? compresor1Matricula;
  DateTime? compresor1Vigencia;
  DateTime? compresor1VigenciaPH;
  int? compresor1BuzosCargo;

  // Compresor 2
  String? compresor2Matricula;
  DateTime? compresor2Vigencia;
  DateTime? compresor2VigenciaPH;
  int? compresor2BuzosCargo;

  // Horarios
  String? horaInicio;
  String? horaTermino;

  BuceoVerificacionModel({
    required this.actividadId,
    this.autorizacionAutoridadMaritima = false,
    this.induccionCentroCultivo = false,
    this.permisoBuceoCentroCorrecto = false,
    this.planContingenciasCentroOk = false,
    this.examenesOcupacionalesVigentes = false,
    this.observacionGeneral,
    this.estadoManual,

    // Inicializar nuevos campos
    this.obsAutorizacion,
    this.imgAutorizacion,
    this.obsInduccion,
    this.imgInduccion,
    this.obsPermiso,
    this.imgPermiso,
    this.obsPlan,
    this.imgPlan,
    this.obsExamenes,
    this.imgExamenes,

    // Contratista
    this.supervisorNombre,
    this.supervisorRut,

    // Cliente (AquaChile) - NUEVOS
    this.encargadoCentro,
    this.supervisorCentro,

    // Compresores y Horarios
    this.compresor1Matricula,
    this.compresor1Vigencia,
    this.compresor1VigenciaPH,
    this.compresor1BuzosCargo,
    this.compresor2Matricula,
    this.compresor2Vigencia,
    this.compresor2VigenciaPH,
    this.compresor2BuzosCargo,
    this.horaInicio,
    this.horaTermino,
  });

  // Lógica de validación
  bool get faenaHabilitada {
    if (estadoManual == 'APROBADO') return true;
    if (estadoManual == 'SUSPENDIDO') return false;

    // Si no es manual, depende de los switchs críticos
    return autorizacionAutoridadMaritima &&
        induccionCentroCultivo &&
        permisoBuceoCentroCorrecto &&
        planContingenciasCentroOk &&
        examenesOcupacionalesVigentes;
  }

  /// El forzado manual tiene prioridad incluso sobre hallazgos intolerables.
  static bool resolverAprobacionFaena({
    required BuceoVerificacionModel? verificaciones,
    required int totalIntolerables,
  }) {
    if (verificaciones?.estadoManual == 'APROBADO') return true;
    if (verificaciones?.estadoManual == 'SUSPENDIDO') return false;
    return totalIntolerables == 0 && (verificaciones?.faenaHabilitada ?? true);
  }

  Map<String, dynamic> toMap() {
    return {
      'actividad_id': actividadId,
      'autorizacion_autoridad_maritima': autorizacionAutoridadMaritima ? 1 : 0,
      'induccion_centro_cultivo': induccionCentroCultivo ? 1 : 0,
      'permiso_buceo_centro_correcto': permisoBuceoCentroCorrecto ? 1 : 0,
      'plan_contingencias_centro_ok': planContingenciasCentroOk ? 1 : 0,
      'examenes_ocupacionales_vigentes': examenesOcupacionalesVigentes ? 1 : 0,

      // Mapeo nuevos campos
      'obs_autorizacion': obsAutorizacion,
      'img_autorizacion': imgAutorizacion,
      'obs_induccion': obsInduccion,
      'img_induccion': imgInduccion,
      'obs_permiso': obsPermiso,
      'img_permiso': imgPermiso,
      'obs_plan': obsPlan,
      'img_plan': imgPlan,
      'obs_examenes': obsExamenes,
      'img_examenes': imgExamenes,
      'observacion_general': observacionGeneral,
      'estado_manual': estadoManual,

      // Contratista
      'supervisor_nombre': supervisorNombre,
      'supervisor_rut': supervisorRut,

      // Cliente (AquaChile) - NUEVOS (Deben coincidir con database_helper)
      'encargado_centro': encargadoCentro,
      'supervisor_centro': supervisorCentro,

      // Horarios
      'hora_inicio': horaInicio,
      'hora_termino': horaTermino,

      // Compresor 1
      'compresor_1_matricula': compresor1Matricula,
      'compresor_1_vigencia': compresor1Vigencia?.toIso8601String(),
      'compresor_1_vigencia_ph': compresor1VigenciaPH?.toIso8601String(),
      'compresor_1_buzos_cargo': compresor1BuzosCargo,

      // Compresor 2
      'compresor_2_matricula': compresor2Matricula,
      'compresor_2_vigencia': compresor2Vigencia?.toIso8601String(),
      'compresor_2_vigencia_ph': compresor2VigenciaPH?.toIso8601String(),
      'compresor_2_buzos_cargo': compresor2BuzosCargo,
    };
  }

  factory BuceoVerificacionModel.fromMap(Map<String, dynamic> map) {
    return BuceoVerificacionModel(
      actividadId: map['actividad_id'],
      autorizacionAutoridadMaritima:
          map['autorizacion_autoridad_maritima'] == 1,
      induccionCentroCultivo: map['induccion_centro_cultivo'] == 1,
      permisoBuceoCentroCorrecto: map['permiso_buceo_centro_correcto'] == 1,
      planContingenciasCentroOk: map['plan_contingencias_centro_ok'] == 1,
      examenesOcupacionalesVigentes:
          map['examenes_ocupacionales_vigentes'] == 1,

      // Leer nuevos campos
      obsAutorizacion: map['obs_autorizacion'],
      imgAutorizacion: map['img_autorizacion'],
      obsInduccion: map['obs_induccion'],
      imgInduccion: map['img_induccion'],
      obsPermiso: map['obs_permiso'],
      imgPermiso: map['img_permiso'],
      obsPlan: map['obs_plan'],
      imgPlan: map['img_plan'],
      obsExamenes: map['obs_examenes'],
      imgExamenes: map['img_examenes'],

      observacionGeneral: map['observacion_general'],
      estadoManual: map['estado_manual'],

      // Contratista
      supervisorNombre: map['supervisor_nombre'],
      supervisorRut: map['supervisor_rut'],

      // Cliente (AquaChile) - NUEVOS
      encargadoCentro: map['encargado_centro'],
      supervisorCentro: map['supervisor_centro'],

      // Horarios
      horaInicio: map['hora_inicio'],
      horaTermino: map['hora_termino'],

      // Compresores (con seguridad de nulos)
      compresor1Matricula: map['compresor_1_matricula'],
      compresor1Vigencia: map['compresor_1_vigencia'] != null
          ? DateTime.tryParse(map['compresor_1_vigencia'])
          : null,
      compresor1VigenciaPH: map['compresor_1_vigencia_ph'] != null
          ? DateTime.tryParse(map['compresor_1_vigencia_ph'])
          : null,
      compresor1BuzosCargo: map['compresor_1_buzos_cargo'],

      compresor2Matricula: map['compresor_2_matricula'],
      compresor2Vigencia: map['compresor_2_vigencia'] != null
          ? DateTime.tryParse(map['compresor_2_vigencia'])
          : null,
      compresor2VigenciaPH: map['compresor_2_vigencia_ph'] != null
          ? DateTime.tryParse(map['compresor_2_vigencia_ph'])
          : null,
      compresor2BuzosCargo: map['compresor_2_buzos_cargo'],
    );
  }
}
