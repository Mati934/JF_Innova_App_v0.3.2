import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_filter_sheet.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../controllers/ticket_list_controller.dart';
import '../widgets/ticket_card.dart';
import '../widgets/ticket_offline_block.dart';
import 'ticket_detail_screen.dart';
import 'ticket_solicitud_form_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  late final TicketListController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TicketListController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          appBar: GradientAppBar(
            title: const Text('Tickets'),
            actions: [
              if (!_ctrl.isBlocked)
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded),
                  tooltip: 'Filtros',
                  onPressed: _openFilterSheet,
                ),
            ],
          ),
          floatingActionButton: _ctrl.isBlocked
              ? null
              : FloatingActionButton.extended(
                  onPressed: _onNuevoTicket,
                  backgroundColor: AppTheme.primaryBlue,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo ticket'),
                ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_ctrl.isBlocked) {
      return TicketOfflineBlock(onRetry: () => _ctrl.cargarTickets());
    }
    if (_ctrl.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ctrl.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_ctrl.errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_ctrl.tickets.isEmpty) {
      return const Center(child: Text('No hay tickets para mostrar.'));
    }
    return RefreshIndicator(
      onRefresh: () => _ctrl.cargarTickets(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 90),
        itemCount: _ctrl.tickets.length,
        itemBuilder: (context, i) {
          final t = _ctrl.tickets[i];
          return TicketCard(
            ticket: t,
            generadoPorNombre: _ctrl.nombreDe(t.generadoPorId),
            tomadoPorNombre: t.tomadoPorId != null
                ? _ctrl.nombreDe(t.tomadoPorId)
                : null,
            esMio:
                t.tomadoPorId != null && t.tomadoPorId == _ctrl.usuarioActualId,
            onTap: () => _abrirDetalle(t.id),
            onTomar: () => _tomarTicket(t.id),
          );
        },
      ),
    );
  }

  Future<void> _abrirDetalle(String ticketId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticketId)),
    );
    _ctrl.cargarTickets();
  }

  Future<void> _tomarTicket(String ticketId) async {
    final error = await _ctrl.tomarTicket(ticketId);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red.shade700),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket tomado.')));
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CustomFilterSheet(
        currentFilters: _ctrl.activeFilters,
        filterDefs: _buildFilterDefs(),
        onApply: (filters) => _ctrl.applyFilters(filters),
      ),
    );
  }

  List<FilterDef> _buildFilterDefs() {
    return [
      const FilterDef(
        key: 'estado',
        label: 'Estado',
        icon: Icons.flag_outlined,
        items: [
          'Abierto',
          'Tomado',
          'Parcial',
          'Pendiente de revisión',
          'Cerrado',
        ],
        resolveId: _estadoLabelToValue,
        resolveDisplayName: _estadoValueToLabel,
      ),
      const FilterDef(
        key: 'tipo_ticket',
        label: 'Tipo',
        icon: Icons.category_outlined,
        items: ['Revisión de observaciones', 'Solicitud'],
        resolveId: _tipoLabelToValue,
        resolveDisplayName: _tipoValueToLabel,
      ),
      const FilterDef(
        key: 'tipo_inspeccion',
        label: 'Tipo de inspección',
        icon: Icons.assignment_outlined,
        items: ['Buceo', 'Embarcación'],
        resolveId: _tipoInspeccionLabelToValue,
        resolveDisplayName: _tipoInspeccionValueToLabel,
      ),
    ];
  }

  void _onNuevoTicket() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(
                  Icons.rule_folder_outlined,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: const Text('Desde una inspección'),
              subtitle: const Text(
                'Genera un ticket automático desde el historial (buceo/embarcación).',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: const Text('Solicitud'),
              subtitle: const Text(
                'Ticket libre, con un texto describiendo lo que se requiere.',
              ),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TicketSolicitudFormScreen(),
                  ),
                );
                _ctrl.cargarTickets();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

String _estadoLabelToValue(String label) => switch (label) {
  'Abierto' => 'ABIERTO',
  'Tomado' => 'TOMADO',
  'Parcial' => 'PARCIAL',
  'Pendiente de revisión' => 'FINALIZADO_PENDIENTE_REVISION',
  'Cerrado' => 'CERRADO',
  _ => label,
};

String _estadoValueToLabel(String value) => switch (value) {
  'ABIERTO' => 'Abierto',
  'TOMADO' => 'Tomado',
  'PARCIAL' => 'Parcial',
  'FINALIZADO_PENDIENTE_REVISION' => 'Pendiente de revisión',
  'CERRADO' => 'Cerrado',
  _ => value,
};

String _tipoLabelToValue(String label) => switch (label) {
  'Revisión de observaciones' => 'REVISION_OBSERVACIONES',
  'Solicitud' => 'SOLICITUD',
  _ => label,
};

String _tipoValueToLabel(String value) => switch (value) {
  'REVISION_OBSERVACIONES' => 'Revisión de observaciones',
  'SOLICITUD' => 'Solicitud',
  _ => value,
};

String _tipoInspeccionLabelToValue(String label) => switch (label) {
  'Buceo' => 'INSPECCION_BUCEO',
  'Embarcación' => 'INSPECCION_EMBARCACION',
  _ => label,
};

String _tipoInspeccionValueToLabel(String value) => switch (value) {
  'INSPECCION_BUCEO' => 'Buceo',
  'INSPECCION_EMBARCACION' => 'Embarcación',
  _ => value,
};
