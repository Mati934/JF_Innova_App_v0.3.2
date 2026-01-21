import 'dart:typed_data';

class InspectionReportData {
  // ... (Tus otros campos siguen igual) ...
  final String empresaContratista;
  final String cliente;
  final String logoUrl; // No la usaremos por ahora, cargaremos asset directo
  final String numeroReporte;
  final String fecha;

  final String centro;
  final String area;
  final String embarcacion;
  final String matricula;

  final String tipoFaena;
  final String supervisor;
  final String estadoGlobal;
  final bool esAprobado;

  final List<PersonalDto> equipo;
  final List<InspectionItemDto> items;

  // NUEVO: Galería General
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
    required this.fotosGenerales, // <--- Agregar al constructor
    required this.totalCumple,
    required this.totalNoCumple,
    required this.totalNoAplica,
    required this.totalIntolerables,
  });
}
// ... (Las clases PersonalDto e InspectionItemDto siguen igual)

class PersonalDto {
  final String nombre;
  final String rut;
  final String cargo;
  final String rolEnFaena; // "Supervisor", "Buzo", etc.

  PersonalDto({
    required this.nombre,
    required this.rut,
    required this.cargo,
    required this.rolEnFaena,
  });
}

class InspectionItemDto {
  final String categoria;
  final String pregunta;
  final String respuesta; // "C", "NC", "N/A"
  final String criticidad; // "Intolerable", "Alto", etc.
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
