class BuceoVerificacionModel {
  final String actividadId;

  // CHECKS DE SEGURIDAD (Ya los tenías)
  bool autorizacionAutoridadMaritima;
  bool induccionCentroCultivo;
  bool permisoBuceoCentroCorrecto;
  bool planContingenciasCentroOk;
  bool examenesOcupacionalesVigentes;

  // ESTADOS (Ya los tenías)
  String? observacionGeneral;
  String? estadoManual;

  // --- NUEVOS CAMPOS (ADMINISTRATIVOS Y TÉCNICOS) ---
  String? supervisorNombre;
  String? supervisorRut;

  // Compresor 1
  String? compresor1Matricula;
  DateTime? compresor1Vigencia;
  int? compresor1BuzosCargo;

  // Compresor 2
  String? compresor2Matricula;
  DateTime? compresor2Vigencia;
  int? compresor2BuzosCargo;

  // Certificado Equipos
  bool certificadoEquiposOk;
  DateTime? certificadoEquiposVigencia;

  BuceoVerificacionModel({
    required this.actividadId,
    this.autorizacionAutoridadMaritima = false,
    this.induccionCentroCultivo = false,
    this.permisoBuceoCentroCorrecto = false,
    this.planContingenciasCentroOk = false,
    this.examenesOcupacionalesVigentes = false,
    this.observacionGeneral,
    this.estadoManual,
    // Nuevos
    this.supervisorNombre,
    this.supervisorRut,
    this.compresor1Matricula,
    this.compresor1Vigencia,
    this.compresor1BuzosCargo,
    this.compresor2Matricula,
    this.compresor2Vigencia,
    this.compresor2BuzosCargo,
    this.certificadoEquiposOk = false,
    this.certificadoEquiposVigencia,
  });

  bool get faenaHabilitada {
    if (estadoManual == 'APROBADO') return true;
    if (estadoManual == 'SUSPENDIDO') return false;
    return autorizacionAutoridadMaritima &&
        induccionCentroCultivo &&
        permisoBuceoCentroCorrecto &&
        planContingenciasCentroOk &&
        examenesOcupacionalesVigentes;
  }

  Map<String, dynamic> toMap() {
    return {
      'actividad_id': actividadId,
      'autorizacion_autoridad_maritima': autorizacionAutoridadMaritima ? 1 : 0,
      'induccion_centro_cultivo': induccionCentroCultivo ? 1 : 0,
      'permiso_buceo_centro_correcto': permisoBuceoCentroCorrecto ? 1 : 0,
      'plan_contingencias_centro_ok': planContingenciasCentroOk ? 1 : 0,
      'examenes_ocupacionales_vigentes': examenesOcupacionalesVigentes ? 1 : 0,
      'observacion_general': observacionGeneral,
      'estado_manual': estadoManual,
      // Nuevos
      'supervisor_nombre': supervisorNombre,
      'supervisor_rut': supervisorRut,
      'compresor_1_matricula': compresor1Matricula,
      'compresor_1_vigencia': compresor1Vigencia?.toIso8601String(),
      'compresor_1_buzos_cargo': compresor1BuzosCargo,
      'compresor_2_matricula': compresor2Matricula,
      'compresor_2_vigencia': compresor2Vigencia?.toIso8601String(),
      'compresor_2_buzos_cargo': compresor2BuzosCargo,
      'certificado_equipos_ok': certificadoEquiposOk ? 1 : 0,
      'certificado_equipos_vigencia': certificadoEquiposVigencia
          ?.toIso8601String(),
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
      observacionGeneral: map['observacion_general'],
      estadoManual: map['estado_manual'],
      // Nuevos
      supervisorNombre: map['supervisor_nombre'],
      supervisorRut: map['supervisor_rut'],
      compresor1Matricula: map['compresor_1_matricula'],
      compresor1Vigencia: map['compresor_1_vigencia'] != null
          ? DateTime.tryParse(map['compresor_1_vigencia'])
          : null,
      compresor1BuzosCargo: map['compresor_1_buzos_cargo'],
      compresor2Matricula: map['compresor_2_matricula'],
      compresor2Vigencia: map['compresor_2_vigencia'] != null
          ? DateTime.tryParse(map['compresor_2_vigencia'])
          : null,
      compresor2BuzosCargo: map['compresor_2_buzos_cargo'],
      certificadoEquiposOk: map['certificado_equipos_ok'] == 1,
      certificadoEquiposVigencia: map['certificado_equipos_vigencia'] != null
          ? DateTime.tryParse(map['certificado_equipos_vigencia'])
          : null,
    );
  }
}
