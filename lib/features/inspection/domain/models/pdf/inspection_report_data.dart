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

  final String tipoFaena;
  final String supervisor;
  final String estadoGlobal;

  final String observacionPrevencionista;

  // CAMBIO 1: Cambiamos 'bool' por 'dynamic' para que acepte TODO (texto y switches)
  final Map<String, dynamic> verificacionesBuceo;

  final bool esAprobado;

  // --- DATOS TÉCNICOS NUEVOS (PARA EL PDF) ---
  final String? horaInicio;
  final String? horaTermino;

  // Compresor 1
  final String? compresor1Matricula;
  final String? compresor1Vigencia; // Ya formateada a String
  final String? compresor1PH; // Ya formateada a String
  final String? compresor1Buzos;

  // Compresor 2
  final String? compresor2Matricula;
  final String? compresor2Vigencia; // Ya formateada a String
  final String? compresor2PH; // Ya formateada a String
  final String? compresor2Buzos;
  // -------------------------------------------

  final List<PersonalDto> equipo;
  final List<InspectionItemDto> items;
  final List<Uint8List> fotosGenerales;

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
    required this.tipoFaena,
    required this.supervisor,
    required this.estadoGlobal,
    required this.esAprobado,
    required this.equipo,
    required this.items,
    required this.fotosGenerales,
    required this.totalCumple,
    required this.totalNoCumple,
    required this.totalNoAplica,
    required this.totalIntolerables,
    required this.observacionPrevencionista,
    required this.verificacionesBuceo,

    // Agregamos los nuevos al constructor
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

// ... (PersonalDto e InspectionItemDto se quedan igual) ...
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
  final List<Uint8List> fotos;

  InspectionItemDto({
    required this.categoria,
    required this.pregunta,
    required this.respuesta,
    required this.criticidad,
    this.comentario,
    this.fotos = const [],
  });
}
