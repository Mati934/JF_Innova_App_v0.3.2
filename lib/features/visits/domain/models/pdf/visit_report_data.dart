import 'dart:typed_data';

class VisitReportData {
  final String empresaProveedor;
  final String empresa;
  final String region;
  final String centro;
  final String profesional;
  final String fonoProfesional;
  final String correoProfesional;
  final String jefaturaCargo;
  final String fecha;
  final String horaInicio;
  final String horaTermino;
  final String origenVisita;
  final String emailEmpresa1;
  final String emailEmpresa2;

  final bool checkReunion;
  final bool checkSenaletica;
  final bool checkCapacitacion;
  final bool checkVisitaSso;
  final bool checkCharla;
  final bool checkInvestigacion;
  final bool checkInspeccionSso;
  final bool checkObsConductual;
  final bool checkOtro;
  final String? otroActividadTexto;

  final String apuntesObservaciones;

  // CLEAN CODE: Replicando Inspecciones - Usamos rutas de disco
  final List<String> fotosPaths;

  final Uint8List? signatureImage;

  // Checklist dinámico
  final String? tipoChecklist;
  final List<VisitChecklistItemDto> checklistItems;

  VisitReportData({
    this.empresaProveedor = 'JF INNOVA',
    required this.empresa,
    required this.region,
    required this.centro,
    required this.profesional,
    required this.fonoProfesional,
    required this.correoProfesional,
    required this.jefaturaCargo,
    required this.fecha,
    required this.horaInicio,
    required this.horaTermino,
    required this.origenVisita,
    required this.emailEmpresa1,
    required this.emailEmpresa2,
    required this.checkReunion,
    required this.checkSenaletica,
    required this.checkCapacitacion,
    required this.checkVisitaSso,
    required this.checkCharla,
    required this.checkInvestigacion,
    required this.checkInspeccionSso,
    required this.checkObsConductual,
    required this.checkOtro,
    this.otroActividadTexto,
    required this.apuntesObservaciones,
    required this.fotosPaths,
    required this.signatureImage,
    this.tipoChecklist,
    this.checklistItems = const [],
  });
}

class VisitChecklistItemDto {
  final String categoria;
  final String pregunta;
  final String respuesta; // C, NC, N/A
  final String? criticidad;
  final String? observacion;

  VisitChecklistItemDto({
    required this.categoria,
    required this.pregunta,
    required this.respuesta,
    this.criticidad,
    this.observacion,
  });
}
