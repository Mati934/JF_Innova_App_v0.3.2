import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_error_utils.dart';
import '../../services/sync_service.dart';

class SyncPendingScreen extends StatefulWidget {
  const SyncPendingScreen({super.key});

  @override
  State<SyncPendingScreen> createState() => _SyncPendingScreenState();
}

class _SyncPendingScreenState extends State<SyncPendingScreen> {
  final SyncService _syncService = SyncService();

  bool _loading = true;
  bool _syncing = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final data = await _syncService.listarPendientesSincronizacion();
      if (!mounted) return;
      setState(() => _items = data);
    } catch (e, st) {
      final code = await AppErrorUtils.capture(
        e,
        st,
        scope: 'PDG',
        reason: 'SyncPendingScreen._cargar',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppErrorUtils.buildErrorSnackBar(
          message: 'No se pudieron cargar los pendientes.',
          code: code,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sincronizarAhora() async {
    setState(() => _syncing = true);
    try {
      await _syncService.sincronizarTodo();
      await _cargar();
      if (!mounted) return;
      final count = _items.length;
      final mensaje = count == 0
          ? 'Todo sincronizado.'
          : 'Aun hay $count pendientes por sincronizar.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: count == 0 ? Colors.green.shade700 : Colors.orange,
        ),
      );
    } catch (e, st) {
      final code = await AppErrorUtils.capture(
        e,
        st,
        scope: 'SNC',
        reason: 'SyncPendingScreen._sincronizarAhora',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppErrorUtils.buildErrorSnackBar(
          message: 'Error al sincronizar pendientes.',
          code: code,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientesPdf = _items
        .where((e) => e['pdf_pendiente'] == true)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendientes de sincronizacion'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar ahora',
            onPressed: _syncing ? null : _sincronizarAhora,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _ResumenPendientesCard(
                        total: _items.length,
                        pendientesPdf: pendientesPdf,
                      ),
                    ),
                  ),
                  if (_items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('No hay pendientes de sincronizacion.'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      sliver: SliverList.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _PendingTile(item: item);
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ResumenPendientesCard extends StatelessWidget {
  final int total;
  final int pendientesPdf;

  const _ResumenPendientesCard({
    required this.total,
    required this.pendientesPdf,
  });

  @override
  Widget build(BuildContext context) {
    final pendientesData = total - pendientesPdf;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Total: $total | Datos: $pendientesData | PDF: $pendientesPdf',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _PendingTile({required this.item});

  IconData _iconFor(String modulo) {
    final up = modulo.toUpperCase();
    if (up.contains('EXTINTOR')) return Icons.fire_extinguisher;
    if (up.contains('VISITA')) return Icons.assignment_outlined;
    if (up.contains('HIDROSER')) return Icons.engineering;
    if (up.contains('BUCEO')) return Icons.scuba_diving;
    if (up.contains('AST')) return Icons.health_and_safety;
    if (up.contains('MERIEUX')) return Icons.assignment;
    return Icons.assignment_turned_in;
  }

  @override
  Widget build(BuildContext context) {
    final modulo = item['modulo']?.toString() ?? 'MODULO';
    final estado = item['estado_final']?.toString() ?? 'Pendiente';
    final tipo = item['tipo_actividad']?.toString() ?? modulo;
    final motivo = item['motivo']?.toString() ?? 'Pendiente de sincronizar';
    final numero = item['numero_reporte']?.toString();

    final fechaRaw = item['fecha_realizacion']?.toString();
    final fecha = DateTime.tryParse(fechaRaw ?? '');
    final fechaFmt = fecha == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconFor(modulo))),
        title: Text(tipo),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Text('Modulo: $modulo'),
            Text('Estado: $estado'),
            Text('Motivo: $motivo'),
            Text('Fecha: $fechaFmt'),
            if (numero != null && numero.isNotEmpty) Text('N°: $numero'),
          ],
        ),
      ),
    );
  }
}
