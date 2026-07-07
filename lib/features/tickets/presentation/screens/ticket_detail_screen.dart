import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
import '../controllers/ticket_detail_controller.dart';
import '../widgets/ticket_card.dart';
import '../widgets/ticket_item_tile.dart';
import '../../domain/models/ticket_historial_entry.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late final TicketDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TicketDetailController(widget.ticketId);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String? mensaje, {bool esError = true}) {
    if (mensaje == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _tomar() async {
    final error = await _ctrl.tomar();
    _mostrarMensaje(
      error ?? (error == null ? 'Ticket tomado.' : null),
      esError: error != null,
    );
  }

  Future<void> _soltar() async {
    final error = await _ctrl.soltar();
    _mostrarMensaje(
      error ?? 'Ticket soltado (quedó parcial).',
      esError: error != null,
    );
  }

  Future<void> _aprobar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aprobar ticket'),
        content: const Text(
          'El ticket quedará Cerrado en forma definitiva. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final error = await _ctrl.aprobar();
    _mostrarMensaje(
      error ?? 'Ticket aprobado y cerrado.',
      esError: error != null,
    );
  }

  Future<void> _finalizar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar ticket'),
        content: const Text(
          'El ticket pasará a "Pendiente de revisión" para que un administrador '
          'lo apruebe o rechace. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final error = await _ctrl.finalizar();
    _mostrarMensaje(
      error ?? 'Ticket finalizado, pendiente de revisión.',
      esError: error != null,
    );
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ticket'),
        content: const Text(
          'El ticket dejará de aparecer en el listado para todos. Esta acción '
          'no se puede deshacer. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final error = await _ctrl.eliminar();
    if (!mounted) return;
    if (error != null) {
      _mostrarMensaje(error, esError: true);
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _rechazar() async {
    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar ticket'),
        content: TextField(
          controller: motivoCtrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, motivoCtrl.text.trim());
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (motivo == null || motivo.isEmpty) return;
    final error = await _ctrl.rechazar(motivo);
    _mostrarMensaje(error ?? 'Ticket rechazado.', esError: error != null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          appBar: GradientAppBar(
            title: Text(_ctrl.ticket?.codigoTicket ?? 'Ticket'),
            actions: [
              if (_ctrl.puedoEliminar)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar ticket',
                  onPressed: _ctrl.isProcessing ? null : _eliminar,
                ),
            ],
          ),
          body: _buildBody(),
          bottomNavigationBar: _buildAcciones(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_ctrl.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ctrl.errorMessage != null || _ctrl.ticket == null) {
      return Center(child: Text(_ctrl.errorMessage ?? 'No encontrado'));
    }
    final t = _ctrl.ticket!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.tituloVisible,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TicketEstadoChip(estado: t.estado),
          ],
        ),
        const SizedBox(height: 8),
        if (t.rechazado && t.motivoRechazo != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rechazado por ${_ctrl.nombreDe(t.rechazadoPorId)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.motivoRechazo!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 12.5),
                ),
              ],
            ),
          ),
        Text(t.motivo, style: const TextStyle(fontSize: 13.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Generado por: ${_ctrl.nombreDe(t.generadoPorId)}',
              style: _metaStyle,
            ),
            if (t.tomadoPorId != null)
              Text(
                'Tomado por: ${_ctrl.nombreDe(t.tomadoPorId)}',
                style: _metaStyle,
              ),
            if (t.numeroInforme != null)
              Text('Informe: ${t.numeroInforme}', style: _metaStyle),
            if (t.fechaLimite != null)
              Text(
                'Vence: ${DateFormat('dd/MM/yyyy').format(t.fechaLimite!)}',
                style: _metaStyle.copyWith(
                  color: t.estaVencido ? Colors.red.shade700 : null,
                  fontWeight: t.estaVencido ? FontWeight.bold : null,
                ),
              ),
          ],
        ),
        // Si el ticket no tiene observaciones asociadas (ej. ticket de tipo
        // SOLICITUD) no tiene sentido mostrar la sección: confunde al usuario
        // ver "Observaciones (0/0 subsanadas)" cuando no hay nada que subsanar.
        if (_ctrl.items.isNotEmpty) ...[
          const Divider(height: 32),
          Text(
            'Observaciones (${_ctrl.items.where((i) => i.subsanado).length}/${_ctrl.items.length} subsanadas)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ..._ctrl.items.map(
            (item) => TicketItemTile(
              item: item,
              puedeEditar: _ctrl.puedoSubsanar && !_ctrl.isProcessing,
              procesando: _ctrl.isProcessing,
              onCambiar: (subsanado, foto) async {
                final error = await _ctrl.marcarItem(
                  item: item,
                  subsanado: subsanado,
                  foto: foto,
                );
                _mostrarMensaje(error, esError: true);
              },
            ),
          ),
        ],
        const Divider(height: 32),
        const Text(
          'Historial',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (_ctrl.historial.isEmpty)
          Text(
            'Sin movimientos todavía.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ..._ctrl.historial.map(_buildHistorialRow),
      ],
    );
  }

  TextStyle get _metaStyle =>
      TextStyle(fontSize: 12, color: Colors.grey.shade700);

  Widget _buildHistorialRow(TicketHistorialEntry h) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 6, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_ctrl.nombreDe(h.usuarioId)} · ${h.accion.label}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (h.comentario != null && h.comentario!.isNotEmpty)
                  Text(
                    h.comentario!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                if (h.createdAt != null)
                  Text(
                    DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(h.createdAt!.toLocal()),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildAcciones() {
    if (_ctrl.ticket == null) return null;
    final acciones = <Widget>[];

    if (_ctrl.puedoTomar) {
      acciones.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: _ctrl.isProcessing ? null : _tomar,
            icon: const Icon(Icons.pan_tool_outlined),
            label: const Text('Tomar ticket'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
          ),
        ),
      );
    }
    if (_ctrl.puedoSoltar) {
      acciones.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _ctrl.isProcessing ? null : _soltar,
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Soltar'),
          ),
        ),
      );
    }
    if (_ctrl.puedoFinalizar) {
      acciones.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: _ctrl.isProcessing ? null : _finalizar,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Finalizar'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
            ),
          ),
        ),
      );
    }
    if (_ctrl.puedoRevisar) {
      acciones.addAll([
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _ctrl.isProcessing ? null : _rechazar,
            icon: const Icon(Icons.close_rounded, color: Colors.red),
            label: const Text('Rechazar', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _ctrl.isProcessing ? null : _aprobar,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Aprobar'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
          ),
        ),
      ]);
    }

    if (acciones.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            for (int i = 0; i < acciones.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              acciones[i],
            ],
          ],
        ),
      ),
    );
  }
}
