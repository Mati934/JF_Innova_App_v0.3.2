import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/ticket_repository.dart';
import '../screens/ticket_list_screen.dart';

/// Botón de acceso al módulo de Tickets pensado para el header oscuro del
/// Home: círculo translúcido + ícono blanco + burbuja roja con el conteo de
/// tickets `ABIERTO` (ver plan §9.1 y decisión 18). Se muestra solo si la
/// empresa tiene el módulo habilitado (lo decide quien lo instancia).
class TicketHeaderBadgeButton extends StatefulWidget {
  const TicketHeaderBadgeButton({super.key});

  @override
  State<TicketHeaderBadgeButton> createState() =>
      _TicketHeaderBadgeButtonState();
}

class _TicketHeaderBadgeButtonState extends State<TicketHeaderBadgeButton> {
  final _repo = TicketRepository();
  RealtimeChannel? _channel;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _cargarConteo();
    _channel = _repo.subscribeTickets(_cargarConteo);
  }

  @override
  void dispose() {
    if (_channel != null) _repo.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _cargarConteo() async {
    try {
      final n = await _repo.countAbiertos();
      if (mounted) setState(() => _count = n);
    } catch (_) {
      // Silencioso: si falla, simplemente no se actualiza el badge.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TicketListScreen()),
          );
          _cargarConteo();
        },
        child: Tooltip(
          message: 'Tickets',
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                if (_count > 0)
                  Positioned(
                    top: 2,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Text(
                        _count > 99 ? '99+' : '$_count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
