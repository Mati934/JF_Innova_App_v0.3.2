class VisitModel {
  String activityId;
  String? region; // Cambiado a ID para buenas prácticas relacionales
  String? centro; // Cambiado a ID
  String? jefaturaCargo;
  String? origenVisita;
  String? horaInicio;
  String? horaTermino;
  String? emailEmpresa1;
  String? emailEmpresa2;

  // Checkboxs
  bool checkReunion;
  bool checkSenaletica;
  bool checkCapacitacion;
  bool checkVisitaSso;
  bool checkCharla;
  bool checkInvestigacion;
  bool checkInspeccionSso;
  bool checkObsConductual;
  bool checkOtro;
  String? otroActividadTexto;
  String? apuntesObservaciones;

  VisitModel({
    required this.activityId,
    this.region,
    this.centro,
    this.jefaturaCargo,
    this.origenVisita,
    this.horaInicio,
    this.horaTermino,
    this.emailEmpresa1,
    this.emailEmpresa2,
    this.checkReunion = false,
    this.checkSenaletica = false,
    this.checkCapacitacion = false,
    this.checkVisitaSso = false,
    this.checkCharla = false,
    this.checkInvestigacion = false,
    this.checkInspeccionSso = false,
    this.checkObsConductual = false,
    this.checkOtro = false,
    this.otroActividadTexto,
    this.apuntesObservaciones,
  });

  Map<String, dynamic> toMap() {
    return {
      'activity_id': activityId,
      'region': region, // Guardamos el ID del Area
      'lugar_visita': centro, // Guardamos el ID del Centro
      'jefatura_a_cargo': jefaturaCargo,
      'origen_visita': origenVisita,
      'hora_inicio': horaInicio,
      'hora_termino': horaTermino,
      'email_empresa_1': emailEmpresa1,
      'email_empresa_2': emailEmpresa2,
      'check_reunion': checkReunion ? 1 : 0,
      'check_instalacion_senaletica': checkSenaletica ? 1 : 0,
      'check_capacitacion': checkCapacitacion ? 1 : 0,
      'check_visita_sso': checkVisitaSso ? 1 : 0,
      'check_charla': checkCharla ? 1 : 0,
      'check_investigacion_incidente': checkInvestigacion ? 1 : 0,
      'check_inspeccion_sso': checkInspeccionSso ? 1 : 0,
      'check_obs_conductual': checkObsConductual ? 1 : 0,
      'check_otro': checkOtro ? 1 : 0,
      'otro_actividad_texto': otroActividadTexto,
      'apuntes_observaciones': apuntesObservaciones,
    };
  }

  factory VisitModel.fromMap(Map<String, dynamic> map) {
    return VisitModel(
      // CLEAN CODE: Soporta la llave 'id' (nueva tabla) o 'activity_id' (tabla vieja)
      activityId: map['id'] ?? map['activity_id'] ?? '',
      region: map['region'],
      centro: map['lugar_visita'],
      jefaturaCargo: map['jefatura_a_cargo'],
      origenVisita: map['origen_visita'],
      horaInicio: map['hora_inicio'],
      horaTermino: map['hora_termino'],
      emailEmpresa1: map['email_empresa_1'],
      emailEmpresa2: map['email_empresa_2'],
      checkReunion: map['check_reunion'] == 1 || map['check_reunion'] == true,
      checkSenaletica:
          map['check_instalacion_senaletica'] == 1 ||
          map['check_instalacion_senaletica'] == true,
      checkCapacitacion:
          map['check_capacitacion'] == 1 || map['check_capacitacion'] == true,
      checkVisitaSso:
          map['check_visita_sso'] == 1 || map['check_visita_sso'] == true,
      checkCharla: map['check_charla'] == 1 || map['check_charla'] == true,
      checkInvestigacion:
          map['check_investigacion_incidente'] == 1 ||
          map['check_investigacion_incidente'] == true,
      checkInspeccionSso:
          map['check_inspeccion_sso'] == 1 ||
          map['check_inspeccion_sso'] == true,
      checkObsConductual:
          map['check_obs_conductual'] == 1 ||
          map['check_obs_conductual'] == true,
      checkOtro: map['check_otro'] == 1 || map['check_otro'] == true,
      otroActividadTexto: map['otro_actividad_texto'],
      apuntesObservaciones: map['apuntes_observaciones'],
    );
  }
}
