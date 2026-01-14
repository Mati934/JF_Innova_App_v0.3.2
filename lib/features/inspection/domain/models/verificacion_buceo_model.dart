class VerificacionBuceo {
  final String actividadId;
  final bool autorizacionAutoridadMaritima;
  final bool induccionCentroCultivo;
  final bool permisoBuceoCentroCorrecto;
  final bool planContingenciasCentroOk;
  final bool examenesOcupacionalesVigentes;
  final String? observacionesBloqueo;

  VerificacionBuceo({
    required this.actividadId,
    this.autorizacionAutoridadMaritima = false,
    this.induccionCentroCultivo = false,
    this.permisoBuceoCentroCorrecto = false,
    this.planContingenciasCentroOk = false,
    this.examenesOcupacionalesVigentes = false,
    this.observacionesBloqueo,
  });

  // Factory para convertir desde Supabase/SQLite
  factory VerificacionBuceo.fromMap(Map<String, dynamic> map) {
    return VerificacionBuceo(
      actividadId: map['actividad_id'] ?? '',
      autorizacionAutoridadMaritima:
          map['autorizacion_autoridad_maritima'] ?? false,
      induccionCentroCultivo: map['induccion_centro_cultivo'] ?? false,
      permisoBuceoCentroCorrecto: map['permiso_buceo_centro_correcto'] ?? false,
      planContingenciasCentroOk: map['plan_contingencias_centro_ok'] ?? false,
      examenesOcupacionalesVigentes:
          map['examenes_ocupacionales_vigentes'] ?? false,
      observacionesBloqueo: map['observaciones_bloqueo'],
    );
  }

  // Método para convertir a Map (para guardar en BD)
  Map<String, dynamic> toMap() {
    return {
      'actividad_id': actividadId,
      'autorizacion_autoridad_maritima': autorizacionAutoridadMaritima,
      'induccion_centro_cultivo': induccionCentroCultivo,
      'permiso_buceo_centro_correcto': permisoBuceoCentroCorrecto,
      'plan_contingencias_centro_ok': planContingenciasCentroOk,
      'examenes_ocupacionales_vigentes': examenesOcupacionalesVigentes,
      'observaciones_bloqueo': observacionesBloqueo,
    };
  }

  // Clean Code: Método helper para saber si todo está OK
  bool get esAptoParaBuceo =>
      autorizacionAutoridadMaritima &&
      induccionCentroCultivo &&
      permisoBuceoCentroCorrecto &&
      planContingenciasCentroOk &&
      examenesOcupacionalesVigentes;
}
