import 'dart:async';

import 'package:flutter/material.dart';

/// Muestra el estado final de la faena antes de confirmar la finalización.
/// El botón "Siguiente" se habilita recién después de [segundosEspera] para
/// obligar a leer el resultado. Devuelve `true` si el usuario continúa.
Future<bool> showEstadoFaenaWarningDialog(
  BuildContext context, {
  required String estado,
  required bool aprobada,
  String? detalle,
  int segundosEspera = 3,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EstadoFaenaWarningDialog(
      estado: estado,
      aprobada: aprobada,
      detalle: detalle,
      segundosEspera: segundosEspera,
    ),
  );
  return result == true;
}

class _EstadoFaenaWarningDialog extends StatefulWidget {
  const _EstadoFaenaWarningDialog({
    required this.estado,
    required this.aprobada,
    required this.detalle,
    required this.segundosEspera,
  });

  final String estado;
  final bool aprobada;
  final String? detalle;
  final int segundosEspera;

  @override
  State<_EstadoFaenaWarningDialog> createState() =>
      _EstadoFaenaWarningDialogState();
}

class _EstadoFaenaWarningDialogState extends State<_EstadoFaenaWarningDialog> {
  late int _restante = widget.segundosEspera;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_restante > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _restante--);
        if (_restante <= 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.aprobada ? Colors.green.shade700 : Colors.red.shade700;
    final fondo = widget.aprobada ? Colors.green.shade50 : Colors.red.shade50;
    final habilitado = _restante <= 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(
            widget.aprobada
                ? Icons.verified_outlined
                : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Estado final de la faena')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: fondo,
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.estado.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.detalle ??
                'Este será el estado registrado en el informe. '
                    'Revísalo antes de continuar.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Volver'),
        ),
        ElevatedButton(
          onPressed: habilitado ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Text(habilitado ? 'Siguiente' : 'Siguiente ($_restante)'),
        ),
      ],
    );
  }
}
