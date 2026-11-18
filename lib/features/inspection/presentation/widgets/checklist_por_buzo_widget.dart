import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/inspection_form_controller.dart';

/// Preguntas que se responden por cada buzo de la cuadrilla (formato Searov).
/// Cada buzo parte con todo en Cumple; el inspector cambia lo que falla.
class ChecklistPorBuzoWidget extends StatelessWidget {
  final InspectionFormController controller;

  const ChecklistPorBuzoWidget({super.key, required this.controller});

  static const _opciones = <(String, String)>[
    ('C', 'Cumple'),
    ('NC', 'No cumple'),
    ('N/A', 'N/A'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = controller.itemsPorBuzo;
    final buzos = controller.participantes;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Checklist por buzo',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            buzos.isEmpty
                ? 'Agrega buzos a la cuadrilla para responder estos ítems.'
                : 'Cada buzo parte con todo en Cumple. Marca lo que falla.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          for (final buzo in buzos)
            ExpansionTile(
              key: PageStorageKey('buzo_${buzo.personalId}'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                buzo.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: _resumen(buzo.respuestasPersonal, items.length),
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.pregunta,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: [
                            for (final (valor, etiqueta) in _opciones)
                              ButtonSegment(
                                value: valor,
                                label: Text(etiqueta),
                              ),
                          ],
                          selected: {buzo.respuestasPersonal[item.id] ?? 'C'},
                          onSelectionChanged: (sel) =>
                              controller.setRespuestaBuzo(
                                buzo.personalId,
                                item.id,
                                sel.first,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _resumen(Map<String, String> respuestas, int total) {
    final fallan = respuestas.values.where((v) => v == 'NC').length;
    return Text(
      fallan == 0 ? 'Todo cumple ($total ítems)' : '$fallan ítem(s) no cumplen',
      style: TextStyle(
        fontSize: 12,
        color: fallan == 0 ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }
}
