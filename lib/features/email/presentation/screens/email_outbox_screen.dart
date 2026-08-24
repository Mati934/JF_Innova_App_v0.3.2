import 'package:flutter/material.dart';

import '../../services/email_flow_service.dart';
import '../../services/email_pending_service.dart';

class EmailOutboxScreen extends StatefulWidget {
  const EmailOutboxScreen({super.key});

  @override
  State<EmailOutboxScreen> createState() => _EmailOutboxScreenState();
}

class _EmailOutboxScreenState extends State<EmailOutboxScreen> {
  final _pendingService = EmailPendingService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _pendingService.listPendings();
      if (!mounted) return;
      setState(() => _items = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPending(Map<String, dynamic> row) async {
    final id = (row['id'] ?? '').toString();
    final estado = (row['estado'] ?? '').toString();
    if (id.isEmpty) return;

    if (estado == 'pendiente_sync') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este correo aún espera sincronización del registro.'),
        ),
      );
      return;
    }

    final payload = _pendingService.parsePayload(
      row['payload_json']?.toString(),
    );
    final subject = (payload['subject'] ?? '').toString();
    final body = (payload['body'] ?? '').toString();
    final recipientsDynamic = payload['recipients'];
    final recipients = recipientsDynamic is List
        ? recipientsDynamic.map((e) => e.toString()).toList()
        : <String>[];
    final comments = (payload['comments'] ?? '').toString();
    final attachmentPath = payload['attachment_path']?.toString();

    if (subject.isEmpty || body.isEmpty || recipients.isEmpty) {
      await _pendingService.markStatusById(
        id: id,
        status: 'error',
        lastError: 'Payload incompleto para abrir correo',
      );
      await _load();
      return;
    }

    await _pendingService.markStatusById(id: id, status: 'abierto');

    if (!mounted) return;
    final result = await EmailFlowService.openPreview(
      context: context,
      subject: subject,
      body: body,
      initialComments: comments,
      recipients: recipients,
      suggestedRecipients: recipients,
      attachmentPath: attachmentPath,
      attachmentName: attachmentPath == null || attachmentPath.isEmpty
          ? null
          : attachmentPath.split('\\').last,
    );

    final sent = result?['sent'] == true;
    if (sent) {
      await _pendingService.markPreparedExternally(
        registroId: (row['registro_id'] ?? '').toString(),
        moduleKey: (row['modulo_key'] ?? '').toString(),
        result: result ?? const {},
      );
      await _pendingService.deleteById(id);
    } else {
      final updatedRecipientsDynamic = result?['recipients'];
      final updatedRecipients = updatedRecipientsDynamic is List
          ? updatedRecipientsDynamic
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : recipients;

      await _pendingService.updatePayloadById(
        id: id,
        subject: (result?['subject'] ?? subject).toString(),
        body: (result?['body'] ?? body).toString(),
        comments: (result?['comments'] ?? comments).toString(),
        recipients: updatedRecipients.isEmpty ? recipients : updatedRecipients,
        attachmentPath: (result?['attachment_path'] ?? attachmentPath)
            ?.toString(),
        status: 'pendiente',
      );
    }

    await _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pendiente_sync':
        return Colors.orange;
      case 'pendiente':
        return Colors.blue;
      case 'abierto':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pendiente_sync':
        return 'Pendiente de sincronización';
      case 'pendiente':
        return 'Pendiente de envío';
      case 'abierto':
        return 'Abierto';
      case 'error':
        return 'Error';
      default:
        return status;
    }
  }

  /// Nombre legible del módulo (en vez de la clave cruda 'hidroser_grua_...').
  String _moduloLabel(String moduleKey) {
    final k = moduleKey.toLowerCase();
    if (k.contains('grua_horquilla')) return 'Grúa Horquilla';
    if (k.contains('hidroser')) return 'Hidroser';
    if (k.contains('buceo')) return 'Inspección Buceo';
    if (k.contains('embarcacion')) return 'Inspección Embarcación';
    if (k.contains('extintor')) return 'Extintores';
    if (k.contains('visita')) return 'Visita Técnica';
    if (k.contains('ast')) return 'AST';
    if (k.contains('merieux')) return 'Merieux';
    if (k.contains('prosesso')) return 'Prosesso';
    if (k.isEmpty) return 'Módulo desconocido';
    // Fallback: capitaliza la clave cruda para que al menos sea legible.
    return moduleKey
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Fecha corta legible (dd/MM HH:mm) a partir de un ISO string.
  String _fechaCorta(Object? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de correos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No hay correos pendientes.')),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, separatorIndex) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = _items[index];
                        final estado = (row['estado'] ?? '').toString();
                        final modulo = _moduloLabel(
                          (row['modulo_key'] ?? '').toString(),
                        );
                        final payload = _pendingService.parsePayload(
                          row['payload_json']?.toString(),
                        );
                        final subject = (payload['subject'] ?? '').toString();
                        final recipientsDyn = payload['recipients'];
                        final recipients = recipientsDyn is List
                            ? recipientsDyn
                                  .map((e) => e.toString().trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList()
                            : <String>[];
                        final para = recipients.isEmpty
                            ? 'Sin destinatarios'
                            : recipients.length == 1
                            ? 'Para: ${recipients.first}'
                            : 'Para: ${recipients.first} +${recipients.length - 1}';
                        final fecha = _fechaCorta(
                          row['updated_at'] ?? row['created_at'],
                        );

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(
                              estado,
                            ).withValues(alpha: 0.15),
                            child: Icon(
                              Icons.mark_email_unread_outlined,
                              color: _statusColor(estado),
                            ),
                          ),
                          title: Text(
                            subject.isEmpty ? 'Correo sin asunto' : subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '$para\n$modulo • ${_statusLabel(estado)} • $fecha',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            tooltip: 'Abrir',
                            onPressed: () => _openPending(row),
                          ),
                          onTap: () => _openPending(row),
                        );
                      },
                    ),
            ),
    );
  }
}
