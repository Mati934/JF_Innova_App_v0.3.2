import 'package:flutter/material.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';

/// Tarjeta reutilizable para representar un [TicketModel] en cualquier listado.
///
/// Muestra: código, estado, descripción, solicitante, empresa, área,
/// responsable, fecha de creación y fecha tentativa de cierre.
class TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;
  final String? currentUserId;
  final VoidCallback? onDelete;

  // Nombres resueltos (pasados desde la pantalla que conoce los maestros)
  final String? solicitanteNombre;
  final String? responsableNombre;
  final String? empresaNombre;
  final String? areaNombre;
  final String? numeroInforme;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
    this.currentUserId,
    this.onDelete,
    this.solicitanteNombre,
    this.responsableNombre,
    this.empresaNombre,
    this.areaNombre,
    this.numeroInforme,
  });

  bool get _canDelete =>
      onDelete != null &&
      currentUserId != null &&
      ticket.solicitanteId == currentUserId;

  Color get _accentColor {
    switch (ticket.estado.toLowerCase()) {
      case 'abierto':
        return Colors.red.shade500;
      case 'en proceso':
      case 'en progreso':
        return Colors.blue.shade500;
      case 'resuelto':
        return Colors.green.shade500;
      case 'cerrado':
        return Colors.green.shade500;
      default:
        return Colors.orange.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black12,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de color izquierda según estado
              Container(width: 5, color: _accentColor),

              // Contenido principal
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 6),
                      _buildDescripcion(),
                      const SizedBox(height: 10),
                      Container(height: 1, color: Colors.grey.shade100),
                      const SizedBox(height: 8),
                      _buildInfoGrid(),
                      const SizedBox(height: 8),
                      _buildFooter(),
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

  // ---------------------------------------------------------------------------
  // Secciones
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          ticket.codigoTicket ?? 'Pendiente de sync',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: ticket.codigoTicket != null
                ? AppTheme.primaryBlue
                : Colors.grey.shade400,
            fontStyle: ticket.codigoTicket != null
                ? FontStyle.normal
                : FontStyle.italic,
          ),
        ),
        if (numeroInforme != null) ...[
          const SizedBox(width: 6),
          _InformeBadge(numero: numeroInforme!),
        ],
        const Spacer(),
        _EstadoChip(estado: ticket.estado),
        if (_canDelete) ...[
          const SizedBox(width: 2),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.red.shade300,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: 'Eliminar',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ],
    );
  }

  Widget _buildDescripcion() {
    return Text(
      ticket.descripcion,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
    );
  }

  Widget _buildInfoGrid() {
    final solicitante = solicitanteNombre ?? _shortId(ticket.solicitanteId);
    final empresa = empresaNombre ?? '—';
    final area = areaNombre ?? '—';
    final responsable = responsableNombre;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoItem(
                icon: Icons.person_outline_rounded,
                label: 'Solicitante',
                value: solicitante,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoItem(
                icon: Icons.business_rounded,
                label: 'Empresa',
                value: empresa,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _InfoItem(
                icon: Icons.engineering_outlined,
                label: 'Responsable',
                value: responsable ?? 'Sin asignar',
                dimmed: responsable == null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoItem(
                icon: Icons.category_outlined,
                label: 'Área',
                value: area,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final diasRestantes = ticket.fechaTentativaCierre != null
        ? ticket.fechaTentativaCierre!.difference(DateTime.now()).inDays
        : null;

    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 11,
          color: Colors.grey.shade400,
        ),
        const SizedBox(width: 3),
        Text(
          ticket.createdAt != null
              ? _formatDate(ticket.createdAt!)
              : 'Sin fecha',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
        if (ticket.fechaTentativaCierre != null) ...[
          const SizedBox(width: 10),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.event_outlined, size: 11, color: Colors.grey.shade400),
          const SizedBox(width: 3),
          Text(
            'Cierre: ${_formatDate(ticket.fechaTentativaCierre!)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
        const Spacer(),
        if (diasRestantes != null) _DiasRestantesBadge(dias: diasRestantes),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Ticket'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este ticket?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) onDelete?.call();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _shortId(String id) => id.length > 8 ? '${id.substring(0, 8)}...' : id;
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool dimmed;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 13,
            color: dimmed ? Colors.grey.shade300 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  height: 1.1,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: dimmed ? FontWeight.normal : FontWeight.w500,
                  color: dimmed ? Colors.grey.shade400 : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;

  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (bgColor, dotColor, textColor) = _colorsForEstado(
      estado.toLowerCase(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            estado.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color, Color) _colorsForEstado(String estado) {
    switch (estado) {
      case 'abierto':
        return (Colors.red.shade50, Colors.red.shade500, Colors.red.shade700);
      case 'en proceso':
      case 'en progreso':
        return (
          Colors.blue.shade50,
          Colors.blue.shade500,
          Colors.blue.shade700,
        );
      case 'resuelto':
        return (
          Colors.green.shade50,
          Colors.green.shade500,
          Colors.green.shade700,
        );
      case 'cerrado':
        return (
          Colors.green.shade50,
          Colors.green.shade500,
          Colors.green.shade700,
        );
      default:
        return (
          Colors.orange.shade50,
          Colors.orange.shade400,
          Colors.orange.shade800,
        );
    }
  }
}

class _InformeBadge extends StatelessWidget {
  final String numero;
  const _InformeBadge({required this.numero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 10,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 3),
          Text(
            numero,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiasRestantesBadge extends StatelessWidget {
  final int dias;
  const _DiasRestantesBadge({required this.dias});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (dias < 0) {
      color = Colors.red.shade600;
      label = 'Vencido';
    } else if (dias == 0) {
      color = Colors.orange.shade600;
      label = 'Hoy';
    } else {
      color = dias <= 3 ? Colors.orange.shade500 : Colors.grey.shade500;
      label = '$dias d';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
