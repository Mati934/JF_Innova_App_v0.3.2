import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_theme.dart';
import 'hidroser_checklists.dart';
import '../../features/inspection/presentation/screens/inspection_setup_screen.dart';
import '../../features/visits/presentation/screens/visit_form_screen.dart';
import '../../features/extintores/presentation/screens/extintor_form_screen.dart';
import '../../features/prosesso/presentation/screens/prosesso_form_screen.dart';
import '../../features/hidroser/presentation/screens/hidroser_module_screen.dart';
import '../../features/ast/presentation/screens/ast_module_screen.dart';
import '../../features/buceo_equipment/presentation/screens/buceo_equipment_module_screen.dart';

import '../../features/admin/presentation/screens/master_data_admin_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/tickets/presentation/screens/ticket_list_screen.dart';
import '../../features/merieux/presentation/screens/merieux_visita_module_screen.dart';
import '../../features/merieux/presentation/screens/merieux_extintores_module_screen.dart';
import '../../features/email/presentation/screens/email_setup_screen.dart';
import '../../features/email/presentation/screens/email_outbox_screen.dart';
import '../../features/email/presentation/screens/email_admin_screen.dart';
import '../../features/cronograma/presentation/screens/cronograma_templates_admin_screen.dart';

const Color kMerieuxColor = Color(0xFF1B3B6F);

class ModuleDefinition {
  final String moduleKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool requiresAdmin;
  final bool isPlaceholder;
  final Widget Function(BuildContext) screenBuilder;

  const ModuleDefinition({
    required this.moduleKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.screenBuilder,
    this.requiresAdmin = false,
    this.isPlaceholder = false,
  });
}

class ModuleRegistry {
  ModuleRegistry._();

  static final List<ModuleDefinition> _all = [
    ModuleDefinition(
      moduleKey: 'INSPECCION',
      title: 'Nueva Inspección',
      subtitle: 'Barcos / Buceo',
      icon: Icons.assignment_turned_in,
      color: AppTheme.primaryBlue,
      screenBuilder: (_) => const InspectionSetupScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'VISITA_R003',
      title: 'Registro de Visita',
      subtitle: 'R-003',
      icon: Icons.location_city,
      color: Colors.teal,
      screenBuilder: (_) => const VisitFormScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'VISITA_R004',
      title: 'Inspección Extintores',
      subtitle: 'VISITA-R004',
      icon: Icons.fire_extinguisher,
      color: Colors.red.shade700,
      screenBuilder: (_) => const ExtintorFormScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'MANTENCION_PROSESSO',
      title: 'Mantención',
      subtitle: 'Servicio de Extintores',
      icon: Icons.build_circle,
      color: const Color(0xFFC8102E),
      screenBuilder: (_) => const ProsessoFormScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'HIDROSER',
      title: 'Hidroser',
      subtitle: 'Listas de chequeo',
      icon: Icons.engineering,
      color: kHidroserColor,
      screenBuilder: (_) => const HidroserModuleScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'AST',
      title: 'AST',
      subtitle: 'Análisis Seguro de Trabajo',
      icon: Icons.health_and_safety,
      color: const Color(0xFF003366),
      screenBuilder: (_) => const AstModuleScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'BUCEO_EQUIPAMIENTO',
      title: 'Eq. Buceo',
      subtitle: 'SAL / SAM',
      icon: Icons.scuba_diving,
      color: const Color(0xFF005B8A),
      screenBuilder: (_) => const BuceoEquipmentModuleScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'ADMIN',
      title: 'Admin Maestros',
      subtitle: 'Datos Maestros',
      icon: Icons.admin_panel_settings,
      color: Colors.red.shade700,
      requiresAdmin: true,
      screenBuilder: (_) => const MasterDataAdminScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'HISTORY',
      title: 'Historial',
      subtitle: 'Informes',
      icon: Icons.history,
      color: Colors.blueGrey,
      screenBuilder: (_) => const HistoryScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'TICKETS',
      title: 'Tickets',
      subtitle: 'Seguimiento de observaciones',
      icon: Icons.confirmation_number_outlined,
      color: const Color(0xFFB23B00),
      screenBuilder: (_) => const TicketListScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'MERIEUX_VISITAS',
      title: 'Merieux · Visitas',
      subtitle: 'Registro de Visita',
      icon: Icons.assignment_outlined,
      color: kMerieuxColor,
      screenBuilder: (_) => const MerieuxVisitaModuleScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'MERIEUX_EXTINTORES',
      title: 'Merieux · Extintores',
      subtitle: 'Mantención de Extintores',
      icon: Icons.fire_extinguisher,
      color: kMerieuxColor,
      screenBuilder: (_) => const MerieuxExtintoresModuleScreen(),
    ),
    if (kDebugMode)
      ModuleDefinition(
        moduleKey: 'EMAIL_TEST',
        title: 'Correo prueba',
        subtitle: 'Caso base de correo',
        icon: Icons.email_outlined,
        color: Colors.indigo,
        screenBuilder: (_) => const EmailSetupScreen(),
      ),
    ModuleDefinition(
      moduleKey: 'EMAIL_OUTBOX',
      title: 'Bandeja correos',
      subtitle: 'Pendientes y sincronización',
      icon: Icons.outbox_outlined,
      color: Colors.indigo,
      screenBuilder: (_) => const EmailOutboxScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'EMAIL_ADMIN',
      title: 'Admin Correos',
      subtitle: 'Plantillas y listas',
      icon: Icons.mark_email_read_outlined,
      color: Colors.indigo.shade700,
      requiresAdmin: true,
      screenBuilder: (_) => const EmailAdminScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'CRONOGRAMA_PLANTILLAS',
      title: 'Plantillas Cronograma',
      subtitle: 'Administración de plantillas',
      icon: Icons.event_note,
      color: Colors.amber.shade700,
      requiresAdmin: true,
      screenBuilder: (_) => const CronogramaTemplatesAdminScreen(),
    ),
    ModuleDefinition(
      moduleKey: 'RENDICIONES',
      title: 'Rendiciones',
      subtitle: 'Gastos',
      icon: Icons.receipt_long,
      color: Colors.orange,
      isPlaceholder: true,
      screenBuilder: (_) => const SizedBox(), // Placeholder
    ),
  ];

  static List<ModuleDefinition> get all => List.unmodifiable(_all);

  static ModuleDefinition? byKey(String key) {
    try {
      return _all.firstWhere((m) => m.moduleKey == key);
    } catch (_) {
      return null;
    }
  }

  /// Módulos default cuando no hay configuración por empresa.
  static const List<String> defaultModuleKeys = [
    'INSPECCION',
    'VISITA_R003',
    'VISITA_R004',
    'EMAIL_OUTBOX',
    'RENDICIONES',
  ];
}
