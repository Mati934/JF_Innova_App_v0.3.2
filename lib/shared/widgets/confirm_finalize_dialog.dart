import 'package:flutter/material.dart';

/// Diálogo reutilizable para confirmar acciones de finalización/guardado
/// definitivo en TODOS los módulos de la app.
///
/// Uso típico:
/// ```dart
/// final ok = await showConfirmFinalizeDialog(
///   context,
///   title: 'Finalizar inspección',
///   message: '¿Estás seguro de finalizar?',
/// );
/// if (ok != true) return;
/// ```
///
/// Devuelve `true` si el usuario confirma, `false`/`null` si cancela.
Future<bool> showConfirmFinalizeDialog(
  BuildContext context, {
  String title = '¿Estás seguro?',
  String message =
      '¿Estás seguro de finalizar? Esta acción no se puede deshacer.',
  String confirmLabel = 'Finalizar',
  String cancelLabel = 'Cancelar',
  Color confirmColor = const Color(0xFFC8102E),
  IconData icon = Icons.warning_amber_rounded,
  Widget? extraContent,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(icon, color: confirmColor),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (extraContent != null) ...[
            const SizedBox(height: 12),
            extraContent,
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
