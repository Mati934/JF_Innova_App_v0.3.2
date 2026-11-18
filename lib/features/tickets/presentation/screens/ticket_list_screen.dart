import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_filter_sheet.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
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
  String? _selectedAreaKey;
  String? _selectedAreaName;

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
    return PopScope<void>(
      canPop: _selectedAreaKey == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _volverAlResumen();
      },
      child: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F6F8),
            appBar: GradientAppBar(
              leading: _selectedAreaKey != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Volver al resumen general',
                      onPressed: _volverAlResumen,
                    )
                  : null,
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
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Nuevo ticket',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
            body: SafeArea(top: false, child: _buildBody()),
          );
        },
      ),
    );
  }

  void _volverAlResumen() {
    if (_selectedAreaKey == null || !mounted) return;
    setState(() {
      _selectedAreaKey = null;
      _selectedAreaName = null;
    });
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
    final resumenGlobal = _ctrl.resumenGlobal();
    final resumenAreas = _ctrl.resumenPorArea();

    if (_selectedAreaKey != null) {
      return _buildAreaTicketsView();
    }

    if (resumenAreas.isEmpty) {
      return const Center(
        child: Text('No hay áreas disponibles para mostrar.'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _ctrl.cargarTickets(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _GlobalSummaryCard(summary: resumenGlobal),
          const SizedBox(height: 18),
          _AreaSectionHeader(count: resumenAreas.length),
          const SizedBox(height: 12),
          ...resumenAreas.map(
            (area) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AreaSummaryCard(
                summary: area,
                onVerTickets: () {
                  setState(() {
                    _selectedAreaKey = area.areaKey;
                    _selectedAreaName = area.areaNombre;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaTicketsView() {
    final key = _selectedAreaKey;
    if (key == null) return const SizedBox.shrink();

    final areaTickets = _ctrl.tickets.where((t) {
      if (key == AreaTicketSummary.sinAreaKey) {
        return t.areaId == null || t.areaId!.isEmpty;
      }
      return t.areaId == key;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _ctrl.cargarTickets(),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 90),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _volverAlResumen();
                  },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Volver a áreas'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedAreaName ?? 'Área',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${areaTickets.length} ticket${areaTickets.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (areaTickets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay tickets en esta área.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...areaTickets.map((t) {
              final progreso = _ctrl.progresoDe(t.id);
              final referenciaItem = _ctrl.referenciaItemDe(t.id);
              return TicketCard(
                ticket: t,
                generadoPorNombre: _ctrl.nombreDe(t.generadoPorId),
                tomadoPorNombre: t.tomadoPorId != null
                    ? _ctrl.nombreDe(t.tomadoPorId)
                    : null,
                centroNombre: _ctrl.nombreCentro(t.centroId),
                embarcacionNombre: _ctrl.nombreEmbarcacion(t.embarcacionId),
                progreso: progreso,
                referenciaItem: referenciaItem,
                esMio:
                    t.tomadoPorId != null &&
                    t.tomadoPorId == _ctrl.usuarioActualId,
                onTap: () => _abrirDetalle(t.id),
                onTomar: () => _tomarTicket(t.id),
              );
            }),
        ],
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
    final defs = <FilterDef>[
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

    defs.add(
      _catalogFilterDef(
        key: 'area_id',
        label: 'Área',
        icon: Icons.apartment_outlined,
        catalogo: _ctrl.catalogoAreas,
      ),
    );
    defs.add(
      _catalogFilterDef(
        key: 'centro_id',
        label: 'Centro',
        icon: Icons.location_city_rounded,
        catalogo: _ctrl.catalogoCentros,
      ),
    );
    defs.add(
      _catalogFilterDef(
        key: 'embarcacion_id',
        label: 'Embarcación',
        icon: Icons.directions_boat_outlined,
        catalogo: _ctrl.catalogoEmbarcaciones,
      ),
    );
    defs.add(
      _catalogFilterDef(
        key: 'contratista_id',
        label: 'Contratista',
        icon: Icons.business_center_outlined,
        catalogo: _ctrl.catalogoContratistas,
      ),
    );

    return defs;
  }

  /// Arma un [FilterDef] genérico a partir de un catálogo `[{id, nombre}]`.
  FilterDef _catalogFilterDef({
    required String key,
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> catalogo,
  }) {
    final mapa = {
      for (final c in catalogo)
        c['id'].toString(): (c['nombre'] as String?) ?? '',
    };
    return FilterDef(
      key: key,
      label: label,
      icon: icon,
      items: mapa.values.toList(),
      enableSearch: mapa.length > 5,
      resolveId: (name) => mapa.entries
          .firstWhere(
            (e) => e.value == name,
            orElse: () => MapEntry(name, name),
          )
          .key,
      resolveDisplayName: (id) => mapa[id] ?? id,
    );
  }

  // Nota: la opción "Desde una inspección" se removió porque la generación
  // de tickets automáticos ya no es manual (ver sync_service.dart
  // _generarTicketsAutomaticosFinalizados). Solo queda la solicitud libre.
  void _onNuevoTicket() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TicketSolicitudFormScreen()),
    );
    _ctrl.cargarTickets();
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

class _AreaSectionHeader extends StatelessWidget {
  final int count;
  const _AreaSectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6E8EF)),
          ),
          child: const Icon(
            Icons.place_outlined,
            size: 16,
            color: Color(0xFF656B80),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Áreas',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF10162B),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE6E8EF)),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF656B80),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlobalSummaryCard extends StatelessWidget {
  final AreaTicketSummary summary;
  const _GlobalSummaryCard({required this.summary});

  int get _sinTomar => summary.abiertos;
  int get _tomados => summary.tomados + summary.parciales;
  int get _terminados => summary.hechos;
  int get _aprobados => summary.cerrados;
  int get _porAprobar => summary.faltanAprobacion;

  double _segment(int value) {
    if (summary.total == 0) return 0;
    return value / summary.total;
  }

  @override
  Widget build(BuildContext context) {
    final cumplimiento = summary.porcentajeHechos.clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A10172D),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 16,
                color: Color(0xFF656B80),
              ),
              SizedBox(width: 8),
              Text(
                'Resumen General',
                style: TextStyle(
                  color: Color(0xFF10162B),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 106,
                height: 106,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 106,
                      height: 106,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 9,
                        valueColor: AlwaysStoppedAnimation(Color(0xFFEEEFF3)),
                        backgroundColor: Color(0xFFEEEFF3),
                      ),
                    ),
                    SizedBox(
                      width: 106,
                      height: 106,
                      child: CircularProgressIndicator(
                        value: cumplimiento,
                        strokeWidth: 9,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF4C9A6C),
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(cumplimiento * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10162B),
                          ),
                        ),
                        const Text(
                          'Logrado',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8990A3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cumplimiento General',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8990A3),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${summary.total}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10162B),
                      ),
                    ),
                    const Text(
                      'Tickets Totales',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF656B80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FlowBar(
            sinTomarRatio: _segment(_sinTomar),
            tomadosRatio: _segment(_tomados),
            terminadosRatio: _segment(_terminados),
            aprobadosRatio: _segment(_aprobados),
          ),
          const SizedBox(height: 14),
          _FlowStats(
            sinTomar: _sinTomar,
            tomados: _tomados,
            terminados: _terminados,
            aprobados: _aprobados,
          ),
          const SizedBox(height: 14),
          _ApprovalBlock(aprobados: _aprobados, porAprobar: _porAprobar),
        ],
      ),
    );
  }
}

class _AreaSummaryCard extends StatelessWidget {
  final AreaTicketSummary summary;
  final VoidCallback onVerTickets;

  const _AreaSummaryCard({required this.summary, required this.onVerTickets});

  int get _sinTomar => summary.abiertos;
  int get _tomados => summary.tomados + summary.parciales;
  int get _terminados => summary.hechos;
  int get _aprobados => summary.cerrados;
  int get _porAprobar => summary.faltanAprobacion;

  double _segment(int value) {
    if (summary.total == 0) return 0;
    return value / summary.total;
  }

  @override
  Widget build(BuildContext context) {
    final cumplimiento = summary.porcentajeHechos;
    final hasDone = _terminados > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A10172D),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFE6E8EF)),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: Color(0xFF656B80),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.areaNombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10162B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.total} Ticket${summary.total == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8990A3),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: cumplimiento > 0
                      ? const Color(0xFFE7F4EC)
                      : const Color(0xFFEEEFF3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(cumplimiento * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cumplimiento > 0
                        ? const Color(0xFF2E7D53)
                        : const Color(0xFF8990A3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FlowBar(
            sinTomarRatio: _segment(_sinTomar),
            tomadosRatio: _segment(_tomados),
            terminadosRatio: _segment(_terminados),
            aprobadosRatio: _segment(_aprobados),
            height: 8,
          ),
          const SizedBox(height: 14),
          _FlowStats(
            sinTomar: _sinTomar,
            tomados: _tomados,
            terminados: _terminados,
            aprobados: _aprobados,
            compact: true,
          ),
          const SizedBox(height: 14),
          if (hasDone)
            _ApprovalBlock(aprobados: _aprobados, porAprobar: _porAprobar)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Aún No Hay Tickets Terminados En Esta Área',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8990A3),
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onVerTickets,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD7DAE4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ver Tickets Del Área',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D4258),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 18, color: Color(0xFF656B80)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowBar extends StatelessWidget {
  final double sinTomarRatio;
  final double tomadosRatio;
  final double terminadosRatio;
  final double aprobadosRatio;
  final double height;

  const _FlowBar({
    required this.sinTomarRatio,
    required this.tomadosRatio,
    required this.terminadosRatio,
    required this.aprobadosRatio,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final total =
        sinTomarRatio + tomadosRatio + terminadosRatio + aprobadosRatio;
    final hasData = total > 0;

    double normalize(double v) => hasData ? (v / total) : 0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEFF3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          if (normalize(sinTomarRatio) > 0)
            Expanded(
              flex: (normalize(sinTomarRatio) * 1000).round(),
              child: Container(color: const Color(0xFFA2A8B8)),
            ),
          if (normalize(tomadosRatio) > 0)
            Expanded(
              flex: (normalize(tomadosRatio) * 1000).round(),
              child: Container(color: const Color(0xFF3B65D6)),
            ),
          if (normalize(terminadosRatio) > 0)
            Expanded(
              flex: (normalize(terminadosRatio) * 1000).round(),
              child: Container(color: const Color(0xFFD69A3E)),
            ),
          if (normalize(aprobadosRatio) > 0)
            Expanded(
              flex: (normalize(aprobadosRatio) * 1000).round(),
              child: Container(color: const Color(0xFF4C9A6C)),
            ),
        ],
      ),
    );
  }
}

class _FlowStats extends StatelessWidget {
  final int sinTomar;
  final int tomados;
  final int terminados;
  final int aprobados;
  final bool compact;

  const _FlowStats({
    required this.sinTomar,
    required this.tomados,
    required this.terminados,
    required this.aprobados,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final numSize = compact ? 17.0 : 19.0;
    return Row(
      children: [
        Expanded(
          child: _FlowStatItem(
            color: const Color(0xFFA2A8B8),
            label: 'Sin Tomar',
            value: sinTomar,
            textColor: const Color(0xFF5C6275),
            numberSize: numSize,
          ),
        ),
        Expanded(
          child: _FlowStatItem(
            color: const Color(0xFF3B65D6),
            label: 'Tomados',
            value: tomados,
            textColor: const Color(0xFF2C4FB0),
            numberSize: numSize,
          ),
        ),
        Expanded(
          child: _FlowStatItem(
            color: const Color(0xFFD69A3E),
            label: 'Terminados',
            value: terminados,
            textColor: const Color(0xFF9C6510),
            numberSize: numSize,
          ),
        ),
        Expanded(
          child: _FlowStatItem(
            color: const Color(0xFF4C9A6C),
            label: 'Aprobados',
            value: aprobados,
            textColor: const Color(0xFF2E7D53),
            numberSize: numSize,
          ),
        ),
      ],
    );
  }
}

class _FlowStatItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final Color textColor;
  final double numberSize;

  const _FlowStatItem({
    required this.color,
    required this.label,
    required this.value,
    required this.textColor,
    required this.numberSize,
  });

  @override
  Widget build(BuildContext context) {
    final muted = value == 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: muted ? const Color(0xFFD7DAE4) : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8990A3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$value',
          style: TextStyle(
            fontSize: numberSize,
            fontWeight: FontWeight.w700,
            color: muted ? const Color(0xFFC7CAD5) : textColor,
          ),
        ),
      ],
    );
  }
}

class _ApprovalBlock extends StatelessWidget {
  final int aprobados;
  final int porAprobar;

  const _ApprovalBlock({required this.aprobados, required this.porAprobar});

  @override
  Widget build(BuildContext context) {
    final total = aprobados + porAprobar;
    final aprobadosRatio = total == 0 ? 0.0 : (aprobados / total);
    final porAprobarRatio = total == 0 ? 0.0 : (porAprobar / total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Terminados Aún Sin Aprobar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3D4258),
                  ),
                ),
              ),
              Text(
                '$aprobados / $total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8990A3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FlowBar(
            sinTomarRatio: 0,
            tomadosRatio: 0,
            terminadosRatio: porAprobarRatio,
            aprobadosRatio: aprobadosRatio,
            height: 8,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$aprobados Aprobados',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D53),
                ),
              ),
              Text(
                '$porAprobar Por Aprobar',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9C6510),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
