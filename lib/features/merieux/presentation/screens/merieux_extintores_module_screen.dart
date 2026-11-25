import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../data/repositories/local_merieux_repository.dart';
import '../../domain/models/merieux_visita.dart';
import '../widgets/merieux_borrador_card.dart';
import 'merieux_extintores_form_screen.dart';
import 'merieux_visita_form_screen.dart' show kMerieuxAzul;

/// Pantalla principal del submódulo "Merieux — Mantención de Extintores":
/// lista borradores en curso y permite crear uno nuevo.
class MerieuxExtintoresModuleScreen extends StatefulWidget {
  const MerieuxExtintoresModuleScreen({super.key});

  @override
  State<MerieuxExtintoresModuleScreen> createState() =>
      _MerieuxExtintoresModuleScreenState();
}

class _MerieuxExtintoresModuleScreenState
    extends State<MerieuxExtintoresModuleScreen> {
  final _repo = LocalMerieuxRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<List<Map<String, dynamic>>> _cargar() =>
      _repo.getBorradores(tipoActividad: kMerieuxTipoExtintores);

  void _reload() {
    setState(() {
      _future = _cargar();
    });
  }

  Future<void> _nuevo() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MerieuxExtintoresFormScreen()),
    );
    if (mounted) _reload();
  }

  Future<void> _abrir(String id) async {
    final borrador = await _repo.getVisitaConRespuestasById(id);
    if (!mounted || borrador == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerieuxExtintoresFormScreen(borrador: borrador),
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
        title: const Text('Merieux · Mantención de Extintores'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kMerieuxAzul,
        foregroundColor: Colors.white,
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo registro'),
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
                        'No tienes borradores.\n\nPulsa "Nuevo registro" para crear uno.',
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
                final numExtintores = (v['num_extintores'] as int?) ?? 0;
                return MerieuxBorradorCard(
                  data: v,
                  icono: Icons.fire_extinguisher,
                  tituloFallback: 'Merieux Extintores · Borrador',
                  chipExtra: _ExtintoresChip(cantidad: numExtintores),
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

/// Chip que muestra la cantidad de extintores cargados en el borrador.
class _ExtintoresChip extends StatelessWidget {
  final int cantidad;
  const _ExtintoresChip({required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kMerieuxAzul.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kMerieuxAzul.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fire_extinguisher, size: 14, color: kMerieuxAzul),
          const SizedBox(width: 5),
          Text(
            cantidad == 1 ? '1 extintor' : '$cantidad extintores',
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
