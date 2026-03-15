import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/features/tickets/data/repositories/local_ticket_repository.dart';
import 'package:jf_innova_app/features/tickets/data/repositories/supabase_ticket_repository.dart';
import 'package:jf_innova_app/features/tickets/presentation/controllers/ticket_controller.dart';
import 'package:jf_innova_app/features/tickets/presentation/screens/ticket_detail_screen.dart';
import 'package:jf_innova_app/features/tickets/presentation/screens/ticket_form_screen.dart';
import 'package:jf_innova_app/features/tickets/presentation/widgets/ticket_card.dart';
import 'package:jf_innova_app/shared/widgets/custom_filter_sheet.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  late final TicketController _controller;
  Map<String, String> _activeFilters = {};

  // Mapas de lookup para resolver IDs a nombres legibles
  Map<String, String> _usuariosMap = {};
  Map<String, String> _empresasMap = {};
  Map<String, String> _areasMap = {};
  Map<String, String> _actividadesMap = {}; // actividadId → numero_reporte

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _controller = TicketController(LocalTicketRepository());
    _controller.loadTickets();
    _loadLookups();
    _syncDesdeSupabase();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _syncDesdeSupabase() async {
    try {
      await SupabaseTicketRepository().descargarTicketsDesdeSupabase();
      if (mounted) _controller.loadTickets();
    } catch (_) {}
  }

  Future<void> _loadLookups() async {
    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getAllUsuarios(),
        db.getAllEmpresas(),
        db.getAreas(),
      ]);

      // Cargar informes desde Supabase para mostrar numero_reporte en tarjetas
      final actividadesMap = <String, String>{};
      try {
        final response = await Supabase.instance.client
            .from('actividades')
            .select('id, numero_informe')
            .not('numero_informe', 'is', null);
        for (final e in List<Map<String, dynamic>>.from(response)) {
          final id = e['id'] as String?;
          final num = e['numero_informe'];
          if (id != null && num != null) {
            actividadesMap[id] = num.toString();
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _usuariosMap = {
          for (final u in results[0])
            u['id'] as String: (u['nombre_completo'] as String?) ?? '',
        };
        _empresasMap = {
          for (final e in results[1])
            e['id'] as String: (e['nombre'] as String?) ?? '',
        };
        _areasMap = {
          for (final a in results[2])
            a['id'] as String: (a['nombre'] as String?) ?? '',
        };
        _actividadesMap = actividadesMap;
      });
    } catch (e) {
      debugPrint('❌ [TicketListScreen] Error cargando lookups: $e');
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
        currentFilters: _activeFilters,
        onApply: (filters) {
          setState(() => _activeFilters = filters);
          _controller.applyFilters(filters);
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() => _activeFilters = {});
    _controller.applyFilters({});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filtrar',
                onPressed: _openFilterSheet,
              ),
              if (_activeFilters.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.logoYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        tooltip: 'Nuevo Ticket',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TicketFormScreen(controller: _controller),
            ),
          ).then((_) => _loadLookups());
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.errorMessage != null) {
            return _buildErrorState(_controller.errorMessage!);
          }

          if (_controller.tickets.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _controller.tickets.length,
            itemBuilder: (context, index) {
              final ticket = _controller.tickets[index];
              return TicketCard(
                ticket: ticket,
                currentUserId: _currentUserId,
                solicitanteNombre: _usuariosMap[ticket.solicitanteId],
                responsableNombre: ticket.responsableId != null
                    ? _usuariosMap[ticket.responsableId!]
                    : null,
                empresaNombre: _empresasMap[ticket.empresaId],
                areaNombre: ticket.areaId != null
                    ? _areasMap[ticket.areaId!]
                    : null,
                numeroInforme: ticket.actividadId != null
                    ? _actividadesMap[ticket.actividadId!]
                    : null,
                onDelete: () => _controller.deleteTicket(ticket.id),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TicketDetailScreen(
                      ticket: ticket,
                      controller: _controller,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _activeFilters.isNotEmpty
                ? 'Ningún ticket coincide con los filtros aplicados.'
                : 'No hay tickets registrados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          if (_activeFilters.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Limpiar filtros'),
              onPressed: _clearFilters,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.logoRed,
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppTheme.logoRed)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _controller.loadTickets,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
