import 'package:flutter/material.dart';

import '../../configurable_checklists/presentation/checklist_icons.dart';

/// Tipos de borradores que pueden aparecer en el Home.
enum DraftKind {
  inspeccionBuceo,
  inspeccionEmbarcacion,
  bitacora,
  visitaTecnica,
  visitaChecklistElectricidad,
  visitaChecklistPisos,
  visitaChecklistOtro,
  visitaActividadesVehiculos,
  inspeccionExtintores,
  mantencionProsesso,
  hidroserGruaHorquilla,
  buceoEquipamiento,
  checklistConfigurable,
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

  /// Icono/color específicos (checklists configurables): vienen de
  /// `checklists.icono` / `checklists.color` para que el borrador use el
  /// mismo ícono que la tarjeta del checklist en Inicio, en vez de un ícono
  /// genérico igual para los 5 checklists de Herramientas y Equipos.
  final String? iconoOverride;
  final String? colorHexOverride;

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
    this.iconoOverride,
    this.colorHexOverride,
  });

  IconData get icon {
    if (kind == DraftKind.checklistConfigurable && iconoOverride != null) {
      return checklistIconFromName(iconoOverride);
    }
    switch (kind) {
      case DraftKind.inspeccionExtintores:
        return Icons.fire_extinguisher;
      case DraftKind.mantencionProsesso:
        return Icons.build_circle;
      case DraftKind.hidroserGruaHorquilla:
        return Icons.engineering;
      case DraftKind.buceoEquipamiento:
        return Icons.scuba_diving;
      case DraftKind.checklistConfigurable:
        return Icons.fact_check_outlined;
      case DraftKind.visitaTecnica:
      case DraftKind.visitaChecklistOtro:
        return Icons.assignment_outlined;
      case DraftKind.visitaActividadesVehiculos:
        return Icons.directions_car_filled;
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
    if (kind == DraftKind.checklistConfigurable && colorHexOverride != null) {
      return checklistColorFromHex(
        colorHexOverride,
        fallback: Colors.teal.shade700,
      );
    }
    switch (kind) {
      case DraftKind.inspeccionExtintores:
        return Colors.red.shade700;
      case DraftKind.mantencionProsesso:
        return const Color(0xFFC8102E);
      case DraftKind.hidroserGruaHorquilla:
        return const Color(0xFF0277BD);
      case DraftKind.buceoEquipamiento:
        return const Color(0xFF005B8A);
      case DraftKind.checklistConfigurable:
        return Colors.teal.shade700;
      case DraftKind.visitaTecnica:
        return Colors.blue.shade700;
      case DraftKind.visitaChecklistElectricidad:
        return Colors.amber.shade800;
      case DraftKind.visitaChecklistPisos:
        return Colors.brown.shade600;
      case DraftKind.visitaChecklistOtro:
        return Colors.indigo.shade600;
      case DraftKind.visitaActividadesVehiculos:
        return Colors.indigo;
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
      kind == DraftKind.visitaActividadesVehiculos ||
      kind == DraftKind.inspeccionExtintores ||
      kind == DraftKind.mantencionProsesso ||
      kind == DraftKind.hidroserGruaHorquilla ||
      kind == DraftKind.buceoEquipamiento;
}
