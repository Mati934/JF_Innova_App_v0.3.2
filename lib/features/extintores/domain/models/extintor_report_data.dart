import 'package:jf_innova_app/features/extintores/domain/models/extintor_state.dart';

class ExtintorReportData {
  final String region;
  final String centro;
  final String profesional;
  final String fonoProfesional;
  final String correoProfesional;
  final String jefaturaCargo;
  final String fecha;
  final String horaInicio;
  final String horaTermino;
  final List<ExtintorResumenItem> extintores;

  const ExtintorReportData({
    required this.region,
    required this.centro,
    required this.profesional,
    required this.fonoProfesional,
    required this.correoProfesional,
    required this.jefaturaCargo,
    required this.fecha,
    required this.horaInicio,
    required this.horaTermino,
    required this.extintores,
  });
}

/// Vista resumida de un extintor para el PDF
class ExtintorResumenItem {
  final int numero;
  final String? matricula;
  final bool todosCumplen;
  final int totalPuntos;
  final List<PuntoNCResumen> puntosNC;
  final List<String> fotoPaths;

  const ExtintorResumenItem({
    required this.numero,
    this.matricula,
    required this.todosCumplen,
    required this.totalPuntos,
    required this.puntosNC,
    required this.fotoPaths,
  });

  factory ExtintorResumenItem.fromState(ExtintorState s) => ExtintorResumenItem(
    numero: s.numero,
    matricula: s.matricula,
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
