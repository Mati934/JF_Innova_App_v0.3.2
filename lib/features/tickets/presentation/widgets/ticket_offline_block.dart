import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Estado que se muestra cuando el módulo de Tickets requiere internet
/// (el módulo es 100% online, ver docs/planificacion/02_en_progreso/PLAN_TICKETS_MVP.md §7).
class TicketOfflineBlock extends StatelessWidget {
  final VoidCallback onRetry;
  const TicketOfflineBlock({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Necesitas conexión a internet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'El módulo de Tickets funciona en línea para que todos vean '
              'los cambios al instante. Conéctate e intenta de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
