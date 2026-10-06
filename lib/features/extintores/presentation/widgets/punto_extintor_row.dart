import 'package:flutter/material.dart';
import '../../domain/models/extintor_state.dart';

/// Fila compacta con botones C / NC / NA para un punto de inspección.
/// Si el estado es NC, expande un campo de observación.
class PuntoExtintorRow extends StatefulWidget {
  final PuntoExtintorState punto;
  final void Function(EstadoExtintor estado) onEstadoChanged;
  final void Function(String obs) onObservacionChanged;
  final int numero;

  const PuntoExtintorRow({
    super.key,
    required this.punto,
    required this.onEstadoChanged,
    required this.onObservacionChanged,
    required this.numero,
  });

  @override
  State<PuntoExtintorRow> createState() => _PuntoExtintorRowState();
}

class _PuntoExtintorRowState extends State<PuntoExtintorRow> {
  late final TextEditingController _obsCtrl;

  @override
  void initState() {
    super.initState();
    _obsCtrl = TextEditingController(text: widget.punto.observacion ?? '');
    _obsCtrl.addListener(() => widget.onObservacionChanged(_obsCtrl.text));
  }

  @override
  void didUpdateWidget(PuntoExtintorRow old) {
    super.didUpdateWidget(old);
    // Sincronizar si el texto cambió externamente (ej: clonar)
    if (old.punto.observacion != widget.punto.observacion &&
        _obsCtrl.text != (widget.punto.observacion ?? '')) {
      _obsCtrl.text = widget.punto.observacion ?? '';
    }
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.punto.estado;
    final esNC = estado == EstadoExtintor.noCumple;
    final colorEstado = _colorEstado(estado);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colorEstado, width: 3)),
        color: esNC ? Colors.red.shade50 : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fila principal ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Número
                SizedBox(
                  width: 24,
                  child: Text(
                    '${widget.numero}.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Descripción
                Expanded(
                  child: Text(
                    widget.punto.pregunta,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                // Botones C / NC / NA
                _BotonEstado(
                  label: 'C',
                  activo: estado == EstadoExtintor.cumple,
                  color: Colors.green,
                  onTap: () => widget.onEstadoChanged(EstadoExtintor.cumple),
                ),
                const SizedBox(width: 4),
                _BotonEstado(
                  label: 'NC',
                  activo: estado == EstadoExtintor.noCumple,
                  color: Colors.red,
                  onTap: () => widget.onEstadoChanged(EstadoExtintor.noCumple),
                ),
                const SizedBox(width: 4),
                _BotonEstado(
                  label: 'NA',
                  activo: estado == EstadoExtintor.noAplica,
                  color: Colors.grey,
                  onTap: () => widget.onEstadoChanged(EstadoExtintor.noAplica),
                ),
              ],
            ),
          ),

          // ── Campo observación (solo si NC) ─────────────────────
          if (esNC)
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 12, bottom: 8),
              child: TextField(
                controller: _obsCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Observación (opcional)...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.red.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ),

          const Divider(height: 1, indent: 36),
        ],
      ),
    );
  }

  Color _colorEstado(EstadoExtintor? e) => switch (e) {
    EstadoExtintor.cumple => Colors.green,
    EstadoExtintor.noCumple => Colors.red,
    EstadoExtintor.noAplica => Colors.grey,
    null => Colors.transparent,
  };
}

class _BotonEstado extends StatelessWidget {
  final String label;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  const _BotonEstado({
    required this.label,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: activo ? color : Colors.transparent,
          border: Border.all(color: activo ? color : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: activo ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
