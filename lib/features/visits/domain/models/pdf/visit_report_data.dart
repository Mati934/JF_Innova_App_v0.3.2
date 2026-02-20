import 'dart:typed_data';

class VisitReportData {
  final String region;
  final String centro;
  final String profesional; // Nombre de tu tío Jorge o el prevencionista
  final String fonoProfesional;
  final String correoProfesional;
  final String jefaturaCargo;
  final String fecha;
  final String horaInicio;
  final String horaTermino;
  final String origenVisita;
  final String emailEmpresa1;
  final String emailEmpresa2;

  // Actividades (Booleanos)
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

  // Fotos (Lista de bytes ya procesados para el PDF)
  final List<Uint8List> fotos;

  VisitReportData({
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
    required this.fotos,
  });
}
