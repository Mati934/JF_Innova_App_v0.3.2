import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/ticket_model.dart';

class TicketEstadoChip extends StatelessWidget {
  final TicketEstado estado;
  const TicketEstadoChip({super.key, required this.estado});

  Color get _color => switch (estado) {
    TicketEstado.abierto => Colors.orange.shade700,
    TicketEstado.tomado => AppTheme.primaryBlue,
    TicketEstado.parcial => Colors.deepPurple,
    TicketEstado.finalizadoPendienteRevision => Colors.teal.shade700,
    TicketEstado.cerrado => Colors.green.shade700,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado.label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Tarjeta que representa un [TicketModel] en el listado del módulo.
class TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final String generadoPorNombre;
  final String? tomadoPorNombre;
  final bool esMio;
  final VoidCallback onTap;
  final VoidCallback? onTomar;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.generadoPorNombre,
    required this.onTap,
    this.tomadoPorNombre,
    this.esMio = false,
    this.onTomar,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = ticket.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(ticket.createdAt!.toLocal())
        : '--';
    final puedeTomar =
        onTomar != null &&
        (ticket.estado == TicketEstado.abierto ||
            ticket.estado == TicketEstado.parcial);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esMio
              ? AppTheme.primaryBlue.withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: esMio ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.tituloVisible,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TicketEstadoChip(estado: ticket.estado),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _MiniChip(
                    icon: Icons.confirmation_number_outlined,
                    text: ticket.codigoTicket ?? 'Sin código',
                  ),
                  _MiniChip(
                    icon: ticket.tipoTicket == TicketTipo.solicitud
                        ? Icons.chat_bubble_outline
                        : Icons.rule_folder_outlined,
                    text: ticket.tipoTicket.label,
                  ),
                  if (ticket.rechazado)
                    const _MiniChip(
                      icon: Icons.report_gmailerrorred_outlined,
                      text: 'Rechazado',
                      color: Colors.red,
                    ),
                  if (ticket.estaVencido)
                    const _MiniChip(
                      icon: Icons.alarm_outlined,
                      text: 'Vencido',
                      color: Colors.red,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Generado por $generadoPorNombre · $fecha',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (tomadoPorNombre != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Tomado por $tomadoPorNombre',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (puedeTomar) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onTomar,
                    icon: const Icon(Icons.pan_tool_outlined, size: 16),
                    label: const Text('Tomar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _MiniChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: c)),
        ],
      ),
    );
  }
}
