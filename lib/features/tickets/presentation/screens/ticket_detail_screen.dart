import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
import '../controllers/ticket_detail_controller.dart';
import '../widgets/ticket_card.dart';
import '../widgets/ticket_item_tile.dart';
import '../../domain/models/ticket_historial_entry.dart';
import '../../domain/models/ticket_model.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late final TicketDetailController _ctrl;
  bool _mostrarTodasSubsanadas = false;
  bool _mostrarHistorialCompleto = false;

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
        _buildHeaderCard(t),
        // Si el ticket no tiene observaciones asociadas (ej. ticket de tipo
        // SOLICITUD) no tiene sentido mostrar la sección: confunde al usuario
        // ver "Observaciones (0/0 subsanadas)" cuando no hay nada que subsanar.
        if (_ctrl.items.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildObservaciones(),
        ],
        const SizedBox(height: 18),
        _buildHistorialSection(),
      ],
    );
  }

  Widget _buildHeaderCard(TicketModel t) {
    final tipoInspeccionInfo = switch (t.tipoInspeccion) {
      'INSPECCION_BUCEO' => (Icons.anchor_outlined, 'Inspección de buceo'),
      'INSPECCION_EMBARCACION' => (
        Icons.directions_boat_outlined,
        'Inspección de embarcación',
      ),
      _ => null,
    };
    final infoItems = <_InfoItem>[
      if (tipoInspeccionInfo != null)
        _InfoItem(
          icon: tipoInspeccionInfo.$1,
          label: 'Tipo de inspección',
          value: tipoInspeccionInfo.$2,
        ),
      if (t.numeroInforme != null)
        _InfoItem(
          icon: Icons.description_outlined,
          label: 'Informe',
          value: 'N° ${t.numeroInforme}',
        ),
      if (_ctrl.nombreCentro != null)
        _InfoItem(
          icon: Icons.location_on_outlined,
          label: 'Centro',
          value: _ctrl.nombreCentro!,
        ),
      if (_ctrl.nombreEmbarcacion != null)
        _InfoItem(
          icon: Icons.directions_boat_outlined,
          label: 'Embarcación',
          value: _ctrl.nombreEmbarcacion!,
        ),
      if (t.fechaLimite != null)
        _InfoItem(
          icon: Icons.access_time_rounded,
          label: 'Vence',
          value: DateFormat('dd/MM/yyyy').format(t.fechaLimite!),
          valueColor: t.estaVencido ? Colors.red.shade700 : null,
        ),
      _InfoItem(
        icon: Icons.person_outline,
        label: 'Generado por',
        value: _ctrl.nombreDe(t.generadoPorId),
      ),
      if (t.tomadoPorId != null)
        _InfoItem(
          icon: Icons.person_search_outlined,
          label: 'Tomado por',
          value: _ctrl.nombreDe(t.tomadoPorId),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _HeaderChip(
                icon: Icons.confirmation_number_outlined,
                text: t.codigoTicket ?? 'Sin código',
              ),
              _HeaderChip(
                icon: Icons.category_outlined,
                text: t.tipoTicket.label,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t.tituloVisible,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TicketEstadoChip(estado: t.estado),
            ],
          ),
          const SizedBox(height: 6),
          if (t.rechazado && t.motivoRechazo != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
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
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            t.motivo,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (infoItems.isNotEmpty) ...[
            const Divider(height: 22),
            _buildInfoGrid(infoItems),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    final filas = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final segundo = i + 1 < items.length ? items[i + 1] : null;
      filas.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 10),
              Expanded(child: segundo ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: filas);
  }

  Widget _buildObservaciones() {
    final pendientes = _ctrl.items.where((i) => !i.subsanado).toList();
    final subsanados = _ctrl.items.where((i) => i.subsanado).toList();
    final subsanadosAMostrar = _mostrarTodasSubsanadas
        ? subsanados
        : subsanados.take(1).toList();
    final total = _ctrl.items.length;
    final progreso = total == 0 ? 0.0 : subsanados.length / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Observaciones',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            Text(
              '${subsanados.length}/$total subsanadas',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 6,
            backgroundColor: const Color(0xFFE3E7EB),
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in pendientes)
          TicketItemTile(
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
        for (final item in subsanadosAMostrar)
          TicketItemTile(
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
        if (subsanados.length > subsanadosAMostrar.length)
          _buildExpandButton(
            label:
                'Ver ${subsanados.length - subsanadosAMostrar.length} subsanadas más',
            onTap: () => setState(() => _mostrarTodasSubsanadas = true),
          )
        else if (_mostrarTodasSubsanadas && subsanados.length > 1)
          _buildExpandButton(
            label: 'Mostrar menos',
            expandido: true,
            onTap: () => setState(() => _mostrarTodasSubsanadas = false),
          ),
      ],
    );
  }

  Widget _buildHistorialSection() {
    // Más reciente primero: el usuario quiere ver la última acción arriba.
    final historial = _ctrl.historial.reversed.toList();
    final aMostrar = _mostrarHistorialCompleto
        ? historial
        : historial.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (historial.isEmpty)
                Text(
                  'Sin movimientos todavía.',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                ...aMostrar.map(_buildHistorialRow),
              if (historial.length > 2)
                _buildExpandButton(
                  label: _mostrarHistorialCompleto
                      ? 'Mostrar menos'
                      : 'Ver historial completo',
                  expandido: _mostrarHistorialCompleto,
                  onTap: () => setState(
                    () =>
                        _mostrarHistorialCompleto = !_mostrarHistorialCompleto,
                  ),
                  compacto: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandButton({
    required String label,
    required VoidCallback onTap,
    bool expandido = false,
    bool compacto = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: compacto ? 4 : 10),
      child: compacto
          ? TextButton.icon(
              onPressed: onTap,
              icon: Icon(
                expandido
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
              ),
              label: Text(label, style: const TextStyle(fontSize: 11.5)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(
                expandido
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
              ),
              label: Text(label, style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
    );
  }

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
              backgroundColor: AppTheme.primaryBlue,
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

/// Chip pequeño para el encabezado del detalle (código del ticket, tipo).
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeaderChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

/// Celda del grid de información del encabezado (icono + etiqueta + valor).
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: valueColor ?? const Color(0xFF12202B),
                  fontWeight: valueColor != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
