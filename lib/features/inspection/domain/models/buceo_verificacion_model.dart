class BuceoVerificacionModel {
  final String actividadId;

  // Checks booleanos
  bool autorizacionAutoridadMaritima;
  bool induccionCentroCultivo;
  bool permisoBuceoCentroCorrecto;
  bool planContingenciasCentroOk;
  bool examenesOcupacionalesVigentes;

  // Campos nuevos (Opcionales y Manuales)
  String? observacionGeneral;
  String? estadoManual; // 'APROBADO', 'SUSPENDIDO' o null

  BuceoVerificacionModel({
    required this.actividadId,
    this.autorizacionAutoridadMaritima = false,
    this.induccionCentroCultivo = false,
    this.permisoBuceoCentroCorrecto = false,
    this.planContingenciasCentroOk = false,
    this.examenesOcupacionalesVigentes = false,
    this.observacionGeneral,
    this.estadoManual,
  });

  // Lógica de Negocio: Prioriza el estado manual, si no, usa los checks
  bool get faenaHabilitada {
    if (estadoManual == 'APROBADO') return true;
    if (estadoManual == 'SUSPENDIDO') return false;

    // Cálculo automático por defecto
    return autorizacionAutoridadMaritima &&
        induccionCentroCultivo &&
        permisoBuceoCentroCorrecto &&
        planContingenciasCentroOk &&
        examenesOcupacionalesVigentes;
  }

  // Serialización (Útil para SQLite/Supabase después)
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
    );
  }
}
