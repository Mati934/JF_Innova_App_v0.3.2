import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../data/repositories/local_merieux_repository.dart';
import '../../domain/models/merieux_visita.dart';
import '../widgets/merieux_borrador_card.dart';
import 'merieux_visita_form_screen.dart';

/// Pantalla principal del submódulo "Merieux — Registro de Visita": lista
/// borradores en curso (mismo patrón que AstModuleScreen) y permite crear uno
/// nuevo. Los finalizados salen de aquí y aparecen en el historial general.
class MerieuxVisitaModuleScreen extends StatefulWidget {
  const MerieuxVisitaModuleScreen({super.key});

  @override
  State<MerieuxVisitaModuleScreen> createState() =>
      _MerieuxVisitaModuleScreenState();
}

class _MerieuxVisitaModuleScreenState extends State<MerieuxVisitaModuleScreen> {
  final _repo = LocalMerieuxRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<List<Map<String, dynamic>>> _cargar() =>
      _repo.getBorradores(tipoActividad: kMerieuxTipoVisitas);

  void _reload() {
    setState(() {
      _future = _cargar();
    });
  }

  Future<void> _nuevo() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MerieuxVisitaFormScreen()));
    if (mounted) _reload();
  }

  Future<void> _abrir(String id) async {
    final borrador = await _repo.getVisitaConRespuestasById(id);
    if (!mounted || borrador == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerieuxVisitaFormScreen(borrador: borrador),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _abrirPdf(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _confirmarEliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar borrador'),
        content: const Text(
          '¿Eliminar este borrador? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.eliminarBorrador(id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMerieuxAzul,
        foregroundColor: Colors.white,
        title: const Text('Merieux · Registro de Visita'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kMerieuxAzul,
        foregroundColor: Colors.white,
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nueva visita'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final visitas = snap.data ?? const [];
            if (visitas.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No tienes borradores.\n\nPulsa "Nueva visita" para crear uno.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: visitas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final v = visitas[i];
                final checklistTipo = v['checklist_tipo'] as String?;
                return MerieuxBorradorCard(
                  data: v,
                  icono: checklistTipo == null
                      ? Icons.description_outlined
                      : Icons.directions_car_filled_outlined,
                  tituloFallback: 'Merieux Visitas · Borrador',
                  chipExtra: _ChecklistChip(checklistTipo: checklistTipo),
                  onTap: () => _abrir(v['id'] as String),
                  onVerPdf: () => _abrirPdf(v['pdf_path_local'] as String?),
                  onEliminar: () => _confirmarEliminar(v['id'] as String),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Chip que indica si la visita incluye el checklist de Vehículos Livianos
/// o quedó "Sin checklist".
class _ChecklistChip extends StatelessWidget {
  final String? checklistTipo;
  const _ChecklistChip({required this.checklistTipo});

  @override
  Widget build(BuildContext context) {
    final esVehiculos = checklistTipo == kMerieuxChecklistVehiculosLivianos;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kMerieuxCyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kMerieuxCyan.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esVehiculos
                ? Icons.directions_car_filled_outlined
                : Icons.description_outlined,
            size: 14,
            color: kMerieuxAzul,
          ),
          const SizedBox(width: 5),
          Text(
            esVehiculos ? 'Vehículos Livianos' : 'Sin checklist',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: kMerieuxAzul,
            ),
          ),
        ],
      ),
    );
  }
}
