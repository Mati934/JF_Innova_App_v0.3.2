import 'package:flutter/material.dart';

/// Traduce el nombre de icono guardado en Supabase (`checklists.icono` y
/// `checklist_navigation_nodes.icono`) al `IconData` de Material.
///
/// Los nombres deben coincidir con los que siembra
/// `checklist_catalog_seed.dart` / los archivos .sql de seed.
IconData checklistIconFromName(String? name) {
  switch (name) {
    case 'handyman':
      return Icons.handyman;
    case 'hardware':
      return Icons.hardware;
    case 'construction':
      return Icons.construction;
    case 'build':
      return Icons.build;
    case 'build_circle':
      return Icons.build_circle;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'electrical_services':
      return Icons.electrical_services;
    case 'bolt':
      return Icons.bolt;
    case 'power':
      return Icons.power;
    case 'electric_bolt':
      return Icons.electric_bolt;
    case 'precision_manufacturing':
      return Icons.precision_manufacturing;
    case 'directions_car':
      return Icons.directions_car;
    case 'fire_extinguisher':
      return Icons.fire_extinguisher;
    case 'plumbing':
      return Icons.plumbing;
    case 'category':
      return Icons.category;
    case 'checklist':
      return Icons.checklist;
    default:
      return Icons.fact_check_outlined;
  }
}

/// Traduce el string `checklists.color` (hex, ej. `#455A64`) a un [Color].
/// Mismo parseo usado en `home_controller.dart` (`_colorFromHex`), expuesto
/// aquí para reutilizarlo también en tarjetas de borradores/historial.
Color checklistColorFromHex(
  String? value, {
  Color fallback = const Color(0xFF176B87),
}) {
  if (value == null || value.isEmpty) return fallback;
  final normalized = value.replaceFirst('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
