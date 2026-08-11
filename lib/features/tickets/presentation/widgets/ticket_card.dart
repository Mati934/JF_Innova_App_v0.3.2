import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/ticket_model.dart';
import '../../domain/models/ticket_item_model.dart';

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

/// Color de urgencia de un ticket (independiente del color de su estado):
/// rojo si está vencido, ámbar si vence pronto, azul si va normal, gris si
/// ya está cerrado. Se usa como barra lateral de [TicketCard] para poder
/// identificar de un vistazo qué tickets requieren atención.
class _Urgencia {
  final Color color;
  final String? etiqueta;
  final IconData? etiquetaIcon;
  const _Urgencia({required this.color, this.etiqueta, this.etiquetaIcon});
}

/// Tarjeta que representa un [TicketModel] en el listado del módulo.
class TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final String generadoPorNombre;
  final String? tomadoPorNombre;
  final String? centroNombre;
  final String? embarcacionNombre;
  final ({int total, int subsanados})? progreso;
  final ({int? numeroPregunta, String? categoria, String origenItem})?
  referenciaItem;
  final bool esMio;
  final VoidCallback onTap;
  final VoidCallback? onTomar;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.generadoPorNombre,
    required this.onTap,
    this.tomadoPorNombre,
    this.centroNombre,
    this.embarcacionNombre,
    this.progreso,
    this.referenciaItem,
    this.esMio = false,
    this.onTomar,
  });

  String _buildItemBadgeText() {
    final ref = referenciaItem;
    if (ref == null) {
      if (progreso != null) {
        return '${progreso!.subsanados}/${progreso!.total} subsanadas';
      }
      return 'Sin observaciones';
    }

    final categoria = (ref.categoria ?? '').trim();
    if (ref.origenItem == TicketItemOrigen.fotoObservacion.value) {
      if (categoria.isNotEmpty) return 'Foto observación · $categoria';
      return 'Foto observación';
    }

    final numero = ref.numeroPregunta;
    if (numero != null && categoria.isNotEmpty) {
      return 'Ítem $numero · $categoria';
    }
    if (numero != null) return 'Ítem $numero';
    if (categoria.isNotEmpty) return categoria;
    return 'Ítem de observación';
  }

  _Urgencia get _urgencia {
    if (ticket.estado == TicketEstado.cerrado) {
      return const _Urgencia(color: Color(0xFF455A64));
    }
    final limite = ticket.fechaLimite;
    if (ticket.estaVencido && limite != null) {
      final dias = DateTime.now().difference(limite).inDays;
      final texto = dias <= 0
          ? 'Vencido hoy'
          : 'Vencido hace $dias día${dias == 1 ? '' : 's'}';
      return _Urgencia(
        color: const Color(0xFFB71C1C),
        etiqueta: texto,
        etiquetaIcon: Icons.warning_amber_rounded,
      );
    }
    if (limite != null) {
      final dias = limite.difference(DateTime.now()).inDays;
      if (dias <= 3) {
        final texto = dias <= 0
            ? 'Vence hoy'
            : 'Vence en $dias día${dias == 1 ? '' : 's'}';
        return _Urgencia(
          color: const Color(0xFFF9A825),
          etiqueta: texto,
          etiquetaIcon: Icons.schedule_rounded,
        );
      }
    }
    return const _Urgencia(color: AppTheme.primaryBlue);
  }

  String? get _tipoInspeccionLabel => switch (ticket.tipoInspeccion) {
    'INSPECCION_BUCEO' => 'Inspección de buceo',
    'INSPECCION_EMBARCACION' => 'Inspección de embarcación',
    _ => null,
  };

  IconData get _tipoInspeccionIcon =>
      ticket.tipoInspeccion == 'INSPECCION_EMBARCACION'
      ? Icons.directions_boat_outlined
      : Icons.anchor_outlined;

  String get _lineaInferior {
    final fecha = ticket.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(ticket.createdAt!.toLocal())
        : '--';
    if (ticket.estado == TicketEstado.cerrado) {
      final revisado = ticket.revisadoAt;
      return revisado != null
          ? 'Revisado · cerrado el ${DateFormat('dd/MM/yyyy').format(revisado.toLocal())}'
          : 'Cerrado';
    }
    if (tomadoPorNombre != null) return 'Tomado por $tomadoPorNombre · $fecha';
    return 'Generado por $generadoPorNombre · $fecha';
  }

  @override
  Widget build(BuildContext context) {
    final urgencia = _urgencia;
    final puedeTomar =
        onTomar != null &&
        (ticket.estado == TicketEstado.abierto ||
            ticket.estado == TicketEstado.parcial);
    final tipoInspeccion = _tipoInspeccionLabel;
    final (IconData, String)? ubicacion = centroNombre != null
        ? (Icons.location_on_outlined, 'Centro $centroNombre')
        : embarcacionNombre != null
        ? (Icons.directions_boat_outlined, 'Embarcación $embarcacionNombre')
        : null;

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: urgencia.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                        ],
                      ),
                      if (tipoInspeccion != null ||
                          ticket.numeroInforme != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (tipoInspeccion != null)
                              _MiniChip(
                                icon: _tipoInspeccionIcon,
                                text: tipoInspeccion,
                                color: AppTheme.primaryBlue,
                              ),
                            if (ticket.numeroInforme != null)
                              _MiniChip(
                                icon: Icons.description_outlined,
                                text: 'Informe ${ticket.numeroInforme}',
                              ),
                          ],
                        ),
                      ],
                      if (ubicacion != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              ubicacion.$1,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ubicacion.$2,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (progreso != null && progreso!.total > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: progreso!.subsanados / progreso!.total,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFEEF1F3),
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _buildItemBadgeText(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lineaInferior,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (urgencia.etiqueta != null) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: urgencia.color.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          urgencia.etiquetaIcon,
                                          size: 12,
                                          color: urgencia.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          urgencia.etiqueta!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: urgencia.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (puedeTomar)
                            FilledButton(
                              onPressed: onTomar,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Tomar'),
                            )
                          else
                            OutlinedButton(
                              onPressed: onTap,
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    ticket.estado == TicketEstado.cerrado
                                    ? const Color(0xFF455A64)
                                    : AppTheme.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                ticket.estado == TicketEstado.tomado
                                    ? 'Ver progreso'
                                    : 'Ver detalle',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
