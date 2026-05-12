import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jf_innova_app/features/visits/presentation/screens/visit_form_screen.dart';
import '../controllers/home_controller.dart';
import '../../domain/draft_card_data.dart';
import '../../domain/draft_card_mapper.dart';
import '../../../inspection/presentation/screens/inspection_form_screen.dart';
import '../../../extintores/presentation/screens/extintor_form_screen.dart';
import '../../../prosesso/presentation/screens/prosesso_form_screen.dart';

class DraftListWidget extends StatelessWidget {
  final HomeController controller;

  const DraftListWidget({super.key, required this.controller});

  Future<void> _confirmarEliminar(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Borrador?"),
        content: const Text("Se perderán los datos de esta inspección."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.eliminarBorrador(id);
    }
  }

  Future<void> _abrirBorrador(BuildContext context, DraftCardData card) async {
    final raw = card.raw;
    Widget destino;

    switch (card.kind) {
      case DraftKind.inspeccionExtintores:
        destino = ExtintorFormScreen(borrador: raw);
        break;
      case DraftKind.mantencionProsesso:
        destino = ProsessoFormScreen(borradorInicial: raw);
        break;
      case DraftKind.visitaTecnica:
      case DraftKind.visitaChecklistElectricidad:
      case DraftKind.visitaChecklistPisos:
      case DraftKind.visitaChecklistOtro:
        destino = VisitFormScreen(borrador: raw);
        break;
      default:
        destino = InspectionFormScreen(
          activityId: raw['id']?.toString() ?? card.id,
          tipoActividad: raw['tipo_actividad']?.toString() ?? '',
          centroId: raw['centro_id']?.toString() ?? '',
          nombreCentro: raw['nombre_centro']?.toString() ?? '',
        );
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => destino));
    controller.cargarBorradores();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (controller.isLoadingBorradores) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (controller.borradores.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(30),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 50,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  "No tienes inspecciones en curso",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.borradores.length,
          itemBuilder: (context, index) {
            final card = controller.borradores[index];
            return _DraftCardTile(
              card: card,
              onTap: () => _abrirBorrador(context, card),
              onDelete: () => _confirmarEliminar(context, card.id),
            );
          },
        );
      },
    );
  }
}

/// Tarjeta visual "tonta" — no conoce repositorios ni navegación.
class _DraftCardTile extends StatelessWidget {
  final DraftCardData card;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCardTile({
    required this.card,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmtFecha = DateFormat('dd/MM/yyyy HH:mm').format(card.fecha);
    final relativo = DraftCardMapper.tiempoRelativo(card.fecha);
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade700,
    );

    final chips = <Widget>[];
    if (card.numeroReporte != null) {
      chips.add(_chip(Icons.tag, 'Nº ${card.numeroReporte}'));
    }
    if (card.region != null) {
      chips.add(_chip(Icons.public, card.region!));
    }
    if (card.empresa != null) {
      chips.add(_chip(Icons.business, card.empresa!));
    }
    if (card.horaRango != null) {
      chips.add(_chip(Icons.schedule, card.horaRango!));
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: card.color.withValues(alpha: 0.15),
                child: Icon(card.icon, color: card.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (card.centro != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              card.centro!,
                              style: mutedStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          size: 14,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$fmtFecha  ·  $relativo',
                            style: mutedStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 4, children: chips),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: onDelete,
                tooltip: 'Eliminar borrador',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}
