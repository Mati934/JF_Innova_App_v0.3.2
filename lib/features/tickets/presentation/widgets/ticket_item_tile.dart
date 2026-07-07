import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/image_service.dart';
import '../../domain/models/ticket_item_model.dart';

/// Fila de un [TicketItemModel] dentro del detalle del ticket: muestra la
/// descripción, la foto original (si existe) y el interruptor "Subsanado"
/// que exige foto obligatoria para activarse.
class TicketItemTile extends StatelessWidget {
  final TicketItemModel item;
  final bool puedeEditar;
  final bool procesando;
  final Future<void> Function(bool subsanado, File? foto) onCambiar;

  const TicketItemTile({
    super.key,
    required this.item,
    required this.puedeEditar,
    required this.procesando,
    required this.onCambiar,
  });

  Future<void> _onToggle(BuildContext context, bool nuevoValor) async {
    if (!nuevoValor) {
      await onCambiar(false, null);
      return;
    }
    ImageService.mostrarOpciones(
      context,
      soloUna: true,
      onFotoTomada: (file) => onCambiar(true, file),
      onGaleriaSeleccionada: (files) {
        if (files.isNotEmpty) onCambiar(true, files.first);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.subsanado ? Colors.green.shade300 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.descripcion,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          if (item.fotoOriginalUrl != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.fotoOriginalUrl!,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.subsanado ? 'Subsanado' : 'Pendiente de subsanar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: item.subsanado
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ),
              if (procesando)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: item.subsanado,
                  activeThumbColor: AppTheme.primaryBlue,
                  onChanged: puedeEditar ? (v) => _onToggle(context, v) : null,
                ),
            ],
          ),
          if (item.subsanado && item.fotoSubsanacionUrl != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.fotoSubsanacionUrl!,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
