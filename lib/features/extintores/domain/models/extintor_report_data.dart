import 'package:jf_innova_app/features/extintores/domain/models/extintor_state.dart';

class ExtintorReportData {
  final String empresa;
  final String region;
  final String oficina;
  final String lugarInspeccion;
  final String profesional;
  final String fonoProfesional;
  final String correoProfesional;
  final String jefaturaCargo;
  final String origenVisita;
  final String fecha;
  final String horaInicio;
  final String horaTermino;
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

  final List<ExtintorResumenItem> extintores;

  const ExtintorReportData({
    required this.empresa,
    required this.region,
    required this.oficina,
    required this.lugarInspeccion,
    required this.profesional,
    required this.fonoProfesional,
    required this.correoProfesional,
    required this.jefaturaCargo,
    required this.origenVisita,
    required this.fecha,
    required this.horaInicio,
    required this.horaTermino,
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
    required this.extintores,
  });
}

/// Vista resumida de un extintor para el PDF
class ExtintorResumenItem {
  final int numero;
  final String? matricula;
  final String? tipoExtintor;
  final bool todosCumplen;
  final int totalPuntos;
  final List<PuntoNCResumen> puntosNC;
  final List<String> fotoPaths;

  const ExtintorResumenItem({
    required this.numero,
    this.matricula,
    this.tipoExtintor,
    required this.todosCumplen,
    required this.totalPuntos,
    required this.puntosNC,
    required this.fotoPaths,
  });

  factory ExtintorResumenItem.fromState(ExtintorState s) => ExtintorResumenItem(
    numero: s.numero,
    matricula: s.matricula,
    tipoExtintor: s.tipoExtintor,
    todosCumplen: s.todosCumplen,
    totalPuntos: s.totalPuntos,
    puntosNC: s.puntosNC
        .map(
          (p) =>
              PuntoNCResumen(pregunta: p.pregunta, observacion: p.observacion),
        )
        .toList(),
    fotoPaths: s.fotoPaths,
  );
}

class PuntoNCResumen {
  final String pregunta;
  final String? observacion;

  const PuntoNCResumen({required this.pregunta, this.observacion});
}
