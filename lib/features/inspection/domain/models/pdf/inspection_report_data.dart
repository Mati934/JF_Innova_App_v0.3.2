import 'dart:typed_data';

class InspectionReportData {
  final String empresaContratista;
  final String cliente;
  final String logoUrl;
  final String numeroReporte;
  final String fecha;

  final String centro;
  final String area;
  final String embarcacion;
  final String matricula;

  final bool esConsecutiva;
  final String appVersion;

  final String? encargadoCentro;
  final String? supervisorCentro;
  final String? profesional;

  final String tipoFaena;
  final String supervisor;
  final String estadoGlobal;

  // CLEAN CODE: Ahora son mapas de Strings (rutas absolutas)
  final Map<String, String?> safetyPhotosPaths;
  final Map<String, String?> safetyObservations;

  final String observacionPrevencionista;
  final Map<String, dynamic> verificacionesBuceo;
  final bool esAprobado;

  final String? horaInicio;
  final String? horaTermino;

  final String? compresor1Matricula;
  final String? compresor1Vigencia;
  final String? compresor1PH;
  final String? compresor1Buzos;

  final String? compresor2Matricula;
  final String? compresor2Vigencia;
  final String? compresor2PH;
  final String? compresor2Buzos;

  final List<PersonalDto> equipo;
  final List<InspectionItemDto> items;

  // CLEAN CODE: Lista de rutas
  final List<String> fotosGeneralesPaths;
  final List<Map<String, String>> fotosExtraObservaciones;

  final int totalCumple;
  final int totalNoCumple;
  final int totalNoAplica;
  final int totalIntolerables;

  InspectionReportData({
    required this.empresaContratista,
    required this.cliente,
    required this.logoUrl,
    required this.numeroReporte,
    required this.fecha,
    required this.centro,
    required this.area,
    required this.embarcacion,
    required this.matricula,

    // Inicializamos con mapas/listas vacías para evitar nulls
    this.safetyPhotosPaths = const {},
    this.safetyObservations = const {},
    this.esConsecutiva = false,
    required this.appVersion,
    this.encargadoCentro,
    this.supervisorCentro,
    this.profesional,
    required this.tipoFaena,
    required this.supervisor,
    required this.estadoGlobal,
    required this.esAprobado,
    required this.equipo,
    required this.items,
    required this.fotosGeneralesPaths, // Actualizado
    required this.fotosExtraObservaciones,
    required this.totalCumple,
    required this.totalNoCumple,
    required this.totalNoAplica,
    required this.totalIntolerables,
    required this.observacionPrevencionista,
    required this.verificacionesBuceo,
    this.horaInicio,
    this.horaTermino,
    this.compresor1Matricula,
    this.compresor1Vigencia,
    this.compresor1PH,
    this.compresor1Buzos,
    this.compresor2Matricula,
    this.compresor2Vigencia,
    this.compresor2PH,
    this.compresor2Buzos,
  });
}

class PersonalDto {
  final String nombre;
  final String rut;
  final String cargo;
  final String matricula;
  final String rolEnFaena;

  PersonalDto({
    required this.nombre,
    required this.rut,
    this.cargo = '',
    this.matricula = '',
    required this.rolEnFaena,
  });
}

class InspectionItemDto {
  final String categoria;
  final String pregunta;
  final String respuesta;
  final String criticidad;
  final String? comentario;

  // CLEAN CODE: Lista de rutas de disco, no binarios
  final List<String> fotosPaths;

  InspectionItemDto({
    required this.categoria,
    required this.pregunta,
    required this.respuesta,
    required this.criticidad,
    this.comentario,
    this.fotosPaths = const [],
  });
}
