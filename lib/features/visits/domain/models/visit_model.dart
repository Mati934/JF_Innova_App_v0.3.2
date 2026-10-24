import 'dart:convert';
import 'dart:typed_data';
// Para parsear el JSON

class VisitModel {
  String activityId;
  String? empresa;
  String? region; // Cambiado a ID para buenas prácticas relacionales
  String? centro; // Cambiado a ID
  String? jefaturaCargo;
  String? profesional;
  String? fonoProfesional;
  String? correoProfesional;
  String? origenVisita;
  String? horaInicio;
  String? horaTermino;
  String? emailEmpresa1;
  String? emailEmpresa2;

  // --- NUEVO: Checklist Dinámico (JSONB) ---
  String? tipoChecklist; // Ej: 'ELECTRICIDAD_R005'
  Map<String, dynamic>? respuestasChecklist;

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
  // --- NUEVO: Bloque "Actividades Realizadas" opcional ---
  // Cuando es false, el bloque se oculta en la UI y no se renderiza en el PDF.
  bool incluirActividades;

  /// Valores de los campos extra propios del checklist seleccionado.
  /// Las definiciones (qué campos pide cada checklist) viven en la tabla
  /// `formulario_campos_extra`. Aquí solo guardamos clave -> valor.
  Map<String, String> camposExtra;

  String? apuntesObservaciones;
  Uint8List? signatureImage;

  VisitModel({
    required this.activityId,
    this.empresa,
    this.region,
    this.centro,
    this.jefaturaCargo,
    this.profesional,
    this.fonoProfesional,
    this.correoProfesional,
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
    this.incluirActividades = false,
    Map<String, String>? camposExtra,
    this.apuntesObservaciones,
    this.signatureImage,
    this.tipoChecklist,
    this.respuestasChecklist,
  }) : camposExtra = camposExtra ?? <String, String>{};

  Map<String, dynamic> toMap() {
    return {
      'activity_id': activityId,
      'empresa': empresa,
      'region': region, // Guardamos el ID del Area
      'lugar_visita': centro, // Guardamos el ID del Centro
      'jefatura_a_cargo': jefaturaCargo,
      'profesional': profesional,
      'fono_profesional': fonoProfesional,
      'correo_profesional': correoProfesional,
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
      'incluir_actividades': incluirActividades ? 1 : 0,
      'campos_extra': camposExtra.isEmpty ? null : jsonEncode(camposExtra),
      'otro_actividad_texto': otroActividadTexto,
      'apuntes_observaciones': apuntesObservaciones,
      'signature_image': signatureImage,
    };
  }

  factory VisitModel.fromMap(Map<String, dynamic> map) {
    return VisitModel(
      // CLEAN CODE: Soporta la llave 'id' (nueva tabla) o 'activity_id' (tabla vieja)
      activityId: map['id'] ?? map['activity_id'] ?? '',
      empresa: map['empresa'],
      region: map['region'],
      centro: map['lugar_visita'],
      jefaturaCargo: map['jefatura_a_cargo'],
      profesional: map['profesional'],
      fonoProfesional: map['fono_profesional'],
      correoProfesional: map['correo_profesional'],
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
      // Backward compat: si la columna no existe (borradores viejos) pero hay
      // algún check marcado, asumimos que el bloque sí estaba incluido.
      incluirActividades:
          map['incluir_actividades'] == 1 ||
          map['incluir_actividades'] == true ||
          (map['incluir_actividades'] == null &&
              ((map['check_reunion'] == 1 || map['check_reunion'] == true) ||
                  (map['check_instalacion_senaletica'] == 1 ||
                      map['check_instalacion_senaletica'] == true) ||
                  (map['check_capacitacion'] == 1 ||
                      map['check_capacitacion'] == true) ||
                  (map['check_visita_sso'] == 1 ||
                      map['check_visita_sso'] == true) ||
                  (map['check_charla'] == 1 || map['check_charla'] == true) ||
                  (map['check_investigacion_incidente'] == 1 ||
                      map['check_investigacion_incidente'] == true) ||
                  (map['check_inspeccion_sso'] == 1 ||
                      map['check_inspeccion_sso'] == true) ||
                  (map['check_obs_conductual'] == 1 ||
                      map['check_obs_conductual'] == true) ||
                  (map['check_otro'] == 1 || map['check_otro'] == true))),
      otroActividadTexto: map['otro_actividad_texto'],
      camposExtra: _parseCamposExtra(map['campos_extra']),
      apuntesObservaciones: map['apuntes_observaciones'],
      signatureImage: map['signature_image'] as Uint8List?,
    );
  }

  /// Acepta tanto el `jsonb` que llega desde Supabase (ya parseado como Map)
  /// como el TEXT que guarda SQLite (un string JSON).
  static Map<String, String> _parseCamposExtra(dynamic raw) {
    if (raw == null) return <String, String>{};
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }
    } catch (_) {
      // JSON corrupto en borrador viejo: mejor empezar limpio que crashear.
    }
    return <String, String>{};
  }
}
