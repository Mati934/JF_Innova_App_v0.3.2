import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../domain/models/extintor_state.dart';
import 'punto_extintor_row.dart';

/// Tarjeta expandible para un extintor individual.
/// Incluye: matrícula, progreso, "Todo Cumple", "Clonar anterior", 18 ítems.
class ExtintorCard extends StatefulWidget {
  final ExtintorState extintor;
  final int index;
  final bool puedeClonarse; // = index > 0
  final void Function(EstadoExtintor e, String itemId) onResponder;
  final void Function(String obs, String itemId) onObservacion;
  final VoidCallback onTodoCumple;
  final VoidCallback onClonar;
  final void Function(String matricula) onMatriculaChanged;
  final void Function(String tipoExtintor) onTipoExtintorChanged;
  final VoidCallback onEliminar;
  final void Function(String path) onFotoAdded;
  final void Function(int fotoIndex) onFotoRemoved;

  const ExtintorCard({
    super.key,
    required this.extintor,
    required this.index,
    required this.puedeClonarse,
    required this.onResponder,
    required this.onObservacion,
    required this.onTodoCumple,
    required this.onClonar,
    required this.onMatriculaChanged,
    required this.onTipoExtintorChanged,
    required this.onEliminar,
    required this.onFotoAdded,
    required this.onFotoRemoved,
  });

  @override
  State<ExtintorCard> createState() => _ExtintorCardState();
}

class _ExtintorCardState extends State<ExtintorCard> {
  late final TextEditingController _matriculaCtrl;
  late final TextEditingController _tipoExtintorCtrl;

  @override
  void initState() {
    super.initState();
    _matriculaCtrl = TextEditingController(
      text: widget.extintor.matricula ?? '',
    );
    _matriculaCtrl.addListener(
      () => widget.onMatriculaChanged(_matriculaCtrl.text),
    );
    _tipoExtintorCtrl = TextEditingController(
      text: widget.extintor.tipoExtintor ?? '',
    );
    _tipoExtintorCtrl.addListener(
      () => widget.onTipoExtintorChanged(_tipoExtintorCtrl.text),
    );
  }

  @override
  void didUpdateWidget(ExtintorCard old) {
    super.didUpdateWidget(old);
    if (old.extintor.matricula != widget.extintor.matricula &&
        _matriculaCtrl.text != (widget.extintor.matricula ?? '')) {
      _matriculaCtrl.text = widget.extintor.matricula ?? '';
    }
    if (old.extintor.tipoExtintor != widget.extintor.tipoExtintor &&
        _tipoExtintorCtrl.text != (widget.extintor.tipoExtintor ?? '')) {
      _tipoExtintorCtrl.text = widget.extintor.tipoExtintor ?? '';
    }
  }

  @override
  void dispose() {
    _tipoExtintorCtrl.dispose();
    _matriculaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.extintor;
    final completados = e.puntosCompletados;
    final total = e.totalPuntos;
    final progreso = total > 0 ? completados / total : 0.0;
    final hayNC = e.puntosNC.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: hayNC
              ? Colors.red.shade300
              : e.estaCompleto
              ? Colors.green.shade300
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: e.expandido,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        // ── Header ──────────────────────────────────────────────
        title: Row(
          children: [
            // Título
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extintor #${e.numero}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  // Matrícula inline
                  SizedBox(
                    height: 28,
                    child: TextField(
                      controller: _matriculaCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Identificatorio / Ubicación',
                        hintStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: TextField(
                      controller: _tipoExtintorCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Tipo Extintor',
                        hintStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Chip progreso
            _ProgresoChip(completados: completados, total: total),

            const SizedBox(width: 8),

            // Barra de progreso circular pequeña
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: progreso,
                strokeWidth: 3,
                backgroundColor: Colors.grey.shade200,
                color: e.estaCompleto
                    ? Colors.green
                    : hayNC
                    ? Colors.red
                    : Colors.blue,
              ),
            ),
          ],
        ),
        // ── Acciones rápidas bajo el header ─────────────────────
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Row(
            children: [
              _AccionBtn(
                icon: Icons.done_all,
                label: 'Todo Cumple',
                color: Colors.green,
                onTap: widget.onTodoCumple,
              ),
              if (widget.puedeClonarse) ...[
                const SizedBox(width: 8),
                _AccionBtn(
                  icon: Icons.copy,
                  label: 'Igual al anterior',
                  color: Colors.blue,
                  onTap: widget.onClonar,
                ),
              ],
              const Spacer(),
              _AccionBtn(
                icon: Icons.delete_outline,
                label: 'Eliminar',
                color: Colors.red,
                onTap: widget.onEliminar,
              ),
            ],
          ),
        ),
        // ── Cuerpo: lista de ítems ───────────────────────────────
        children: [
          const Divider(height: 1),
          ...List.generate(e.puntos.length, (i) {
            final punto = e.puntos[i];
            return PuntoExtintorRow(
              key: ValueKey('${e.localId}_${punto.itemId}'),
              punto: punto,
              numero: i + 1,
              onEstadoChanged: (estado) =>
                  widget.onResponder(estado, punto.itemId),
              onObservacionChanged: (obs) =>
                  widget.onObservacion(obs, punto.itemId),
            );
          }),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GalleryInput(
              images: widget.extintor.fotoPaths.map((p) => File(p)).toList(),
              onImagesChanged: (newFiles) {
                final newPaths = newFiles.map((f) => f.path).toSet();
                final oldPaths = widget.extintor.fotoPaths.toSet();
                for (
                  int i = widget.extintor.fotoPaths.length - 1;
                  i >= 0;
                  i--
                ) {
                  if (!newPaths.contains(widget.extintor.fotoPaths[i])) {
                    widget.onFotoRemoved(i);
                  }
                }
                for (final f in newFiles) {
                  if (!oldPaths.contains(f.path)) {
                    widget.onFotoAdded(f.path);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgresoChip extends StatelessWidget {
  final int completados;
  final int total;

  const _ProgresoChip({required this.completados, required this.total});

  @override
  Widget build(BuildContext context) {
    final completo = completados == total && total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: completo ? Colors.green.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completo ? Colors.green.shade400 : Colors.grey.shade400,
        ),
      ),
      child: Text(
        '$completados/$total',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: completo ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _AccionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AccionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
