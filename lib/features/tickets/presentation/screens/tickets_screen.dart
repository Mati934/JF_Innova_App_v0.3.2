import 'package:flutter/material.dart';
import '../controllers/tickets_controller.dart';
import 'crear_ticket_screen.dart';
import '../../domain/models/ticket_model.dart';
import 'package:intl/intl.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final TicketsController _controller = TicketsController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tickets'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
                onPressed: _controller.cargarTickets,
              ),
            ],
          ),
          body: _buildBody(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final creado = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CrearTicketScreen(controller: _controller),
                ),
              );
              if (creado == true) {
                _controller.cargarTickets();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Nuevo Ticket'),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _controller.errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _controller.cargarTickets,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No hay tickets todavía',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Presiona el botón para crear uno',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.cargarTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _controller.tickets.length,
        itemBuilder: (context, index) =>
            _TicketCard(ticket: _controller.tickets[index],
                controller: _controller),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final TicketsController controller;

  const _TicketCard({required this.ticket, required this.controller});

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Abierto':
        return Colors.blue;
      case 'En Progreso':
        return Colors.orange;
      case 'Cerrado':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _colorPrioridad(String prioridad) {
    switch (prioridad) {
      case 'Alta':
        return Colors.red;
      case 'Media':
        return Colors.orange;
      case 'Baja':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final esMio = ticket.creadoPor == controller.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título + badges
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.titulo,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _Badge(
                    label: ticket.prioridad,
                    color: _colorPrioridad(ticket.prioridad)),
                const SizedBox(width: 6),
                _Badge(
                    label: ticket.estado,
                    color: _colorEstado(ticket.estado)),
              ],
            ),

            if (ticket.descripcion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ticket.descripcion,
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  ticket.nombreCreador ?? 'Desconocido',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  fmt.format(ticket.fechaCreacion.toLocal()),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),

            // Acciones solo para el creador
            if (esMio) ...[
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cambiar estado
                  PopupMenuButton<String>(
                    tooltip: 'Cambiar estado',
                    onSelected: (estado) =>
                        controller.actualizarEstado(ticket.id, estado),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'Abierto', child: Text('Abierto')),
                      PopupMenuItem(
                          value: 'En Progreso', child: Text('En Progreso')),
                      PopupMenuItem(
                          value: 'Cerrado', child: Text('Cerrado')),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.edit, size: 14),
                      label: const Text('Estado', style: TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Eliminar
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Eliminar',
                    onPressed: () => _confirmarEliminar(context),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar ticket?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await controller.eliminarTicket(ticket.id);
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
