import 'package:flutter/material.dart';

import '../../../../core/modules/hidroser_checklists.dart';
import '../../data/repositories/local_hidroser_repository.dart';
import '../../domain/models/hidroser_lista.dart';
import 'hidroser_form_screen.dart';

/// Pantalla principal del módulo Hidroser: lista las listas de chequeo
/// disponibles para la empresa activa.
class HidroserModuleScreen extends StatefulWidget {
  const HidroserModuleScreen({super.key});

  @override
  State<HidroserModuleScreen> createState() => _HidroserModuleScreenState();
}

class _HidroserModuleScreenState extends State<HidroserModuleScreen> {
  final _repo = LocalHidroserRepository();
  late Future<List<HidroserLista>> _futureListas;

  @override
  void initState() {
    super.initState();
    _futureListas = _repo.getListasActivas();
  }

  Future<void> _reload() async {
    setState(() {
      _futureListas = _repo.getListasActivas();
    });
  }

  IconData _iconFromName(String? name) {
    switch (name) {
      case 'forklift':
      case 'precision_manufacturing':
        return Icons.precision_manufacturing;
      case 'directions_car':
        return Icons.directions_car;
      case 'build':
        return Icons.build;
      default:
        return Icons.checklist;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kHidroserColor,
        foregroundColor: Colors.white,
        title: const Text('Hidroser · Listas de chequeo'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<HidroserLista>>(
          future: _futureListas,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Error: ${snap.error}')),
                ],
              );
            }
            final listas = snap.data ?? const <HidroserLista>[];
            if (listas.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No hay listas de chequeo Hidroser disponibles.\n\n'
                        'Sincroniza con la nube o pide al administrador '
                        'que active una lista para tu empresa.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemCount: listas.length,
              itemBuilder: (context, i) {
                final l = listas[i];
                return _ListaCard(
                  lista: l,
                  icon: _iconFromName(l.icono),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HidroserFormScreen(lista: l),
                      ),
                    );
                    if (mounted) _reload();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ListaCard extends StatelessWidget {
  final HidroserLista lista;
  final IconData icon;
  final VoidCallback onTap;

  const _ListaCard({
    required this.lista,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 30,
                backgroundColor: kHidroserColor.withValues(alpha: 0.12),
                foregroundColor: kHidroserColorDark,
                child: Icon(icon, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                lista.nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (lista.subtitulo != null && lista.subtitulo!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  lista.subtitulo!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
