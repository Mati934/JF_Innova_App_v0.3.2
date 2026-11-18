import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// Campo de firma "toca para firmar": muestra una vista previa (o "Sin
/// firma") + un botón que abre un diálogo con el pad de firma. Mismo patrón
/// que usan Hidroser/Prosesso (`_FirmaBlock` + `showDialog` con [Signature]),
/// extraído acá como widget compartido para no duplicarlo en cada módulo
/// nuevo.
class TapToSignField extends StatelessWidget {
  final String titulo;
  final Uint8List? imagen;
  final ValueChanged<Uint8List> onFirmado;
  final Color color;

  const TapToSignField({
    super.key,
    required this.titulo,
    required this.imagen,
    required this.onFirmado,
    this.color = Colors.blue,
  });

  Future<void> _abrirDialogoFirma(BuildContext context) async {
    final sigCtrl = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: Signature(
                  controller: sigCtrl,
                  backgroundColor: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Borrar',
                      onPressed: sigCtrl.clear,
                      icon: const Icon(Icons.clear),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final bytes = await sigCtrl.toPngBytes();
                        if (bytes != null) onFirmado(bytes);
                        if (!dialogCtx.mounted) return;
                        Navigator.of(dialogCtx).pop();
                      },
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    sigCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 140,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: imagen != null
                    ? Image.memory(imagen!, fit: BoxFit.contain)
                    : const Center(child: Text('Sin firma')),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _abrirDialogoFirma(context),
                icon: const Icon(Icons.draw),
                label: Text(imagen != null ? 'Re-firmar' : 'Firmar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
