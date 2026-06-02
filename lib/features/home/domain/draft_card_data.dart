import 'package:flutter/material.dart';

/// Tipos de borradores que pueden aparecer en el Home.
enum DraftKind {
  inspeccionBuceo,
  inspeccionEmbarcacion,
  bitacora,
  visitaTecnica,
  visitaChecklistElectricidad,
  visitaChecklistPisos,
  visitaChecklistOtro,
  inspeccionExtintores,
  mantencionProsesso,
  hidroserGruaHorquilla,
  desconocido,
}

/// DTO inmutable que representa una tarjeta de borrador en el Home.
///
/// Es generado por [DraftCardMapper] y consumido por la capa de presentación.
/// Mantiene el [raw] para que la navegación pueda extraer ids/centros sin
/// que el widget tenga que conocer la estructura de la BD.
class DraftCardData {
  final String id;
  final DraftKind kind;
  final String title;
  final String? centro;
  final DateTime fecha;
  final String? numeroReporte;
  final String? region;
  final String? empresa;
  final String? horaRango;
  final Map<String, dynamic> raw;

  const DraftCardData({
    required this.id,
    required this.kind,
    required this.title,
    required this.fecha,
    required this.raw,
    this.centro,
    this.numeroReporte,
    this.region,
    this.empresa,
    this.horaRango,
  });

  IconData get icon {
    switch (kind) {
      case DraftKind.inspeccionExtintores:
        return Icons.fire_extinguisher;
      case DraftKind.mantencionProsesso:
        return Icons.build_circle;
      case DraftKind.hidroserGruaHorquilla:
        return Icons.engineering;
      case DraftKind.visitaTecnica:
      case DraftKind.visitaChecklistOtro:
        return Icons.assignment_outlined;
      case DraftKind.visitaChecklistElectricidad:
        return Icons.electrical_services;
      case DraftKind.visitaChecklistPisos:
        return Icons.grid_4x4;
      case DraftKind.inspeccionBuceo:
        return Icons.scuba_diving;
      case DraftKind.inspeccionEmbarcacion:
        return Icons.directions_boat;
      case DraftKind.bitacora:
        return Icons.menu_book_outlined;
      case DraftKind.desconocido:
        return Icons.edit_document;
    }
  }

  Color get color {
    switch (kind) {
      case DraftKind.inspeccionExtintores:
        return Colors.red.shade700;
      case DraftKind.mantencionProsesso:
        return const Color(0xFFC8102E);
      case DraftKind.hidroserGruaHorquilla:
        return const Color(0xFF0277BD);
      case DraftKind.visitaTecnica:
        return Colors.blue.shade700;
      case DraftKind.visitaChecklistElectricidad:
        return Colors.amber.shade800;
      case DraftKind.visitaChecklistPisos:
        return Colors.brown.shade600;
      case DraftKind.visitaChecklistOtro:
        return Colors.indigo.shade600;
      case DraftKind.inspeccionBuceo:
        return Colors.teal.shade700;
      case DraftKind.inspeccionEmbarcacion:
        return Colors.cyan.shade800;
      case DraftKind.bitacora:
        return Colors.deepPurple.shade400;
      case DraftKind.desconocido:
        return Colors.orange.shade800;
    }
  }

  bool get esVisitaOExtintor =>
      kind == DraftKind.visitaTecnica ||
      kind == DraftKind.visitaChecklistElectricidad ||
      kind == DraftKind.visitaChecklistPisos ||
      kind == DraftKind.visitaChecklistOtro ||
      kind == DraftKind.inspeccionExtintores ||
      kind == DraftKind.mantencionProsesso ||
      kind == DraftKind.hidroserGruaHorquilla;
}
