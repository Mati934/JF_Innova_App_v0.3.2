import 'dart:io';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/inspection_form_controller.dart';

/// Quién realiza y quién recibe la inspección, con firma en pizarra.
/// Formato Searov: el usuario de la app es general por empresa, así que el
/// nombre del inspector se escribe aquí y sale en el PDF.
class FirmasInspeccionWidget extends StatelessWidget {
  final InspectionFormController controller;
  final bool esBuceo;

  const FirmasInspeccionWidget({
    super.key,
    required this.controller,
    required this.esBuceo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Firmas',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _FirmaBlock(
            titulo: esBuceo
                ? 'Quien realiza la inspección (nombre / cargo) *'
                : 'Quien realiza la inspección *',
            nombreCtrl: controller.inspectorNombreCtrl,
            firmaPath: controller.firmaInspectorPath,
            onNombreChanged: controller.onFirmanteChanged,
            onFirmar: () => _firmar(context, inspector: true),
          ),
          const SizedBox(height: 12),
          _FirmaBlock(
            titulo: esBuceo
                ? 'Jefe de centro, supervisor de buceo o rep. empresa contratista'
                : 'Quien recibe la inspección',
            nombreCtrl: controller.recibeNombreCtrl,
            firmaPath: controller.firmaRecibePath,
            onNombreChanged: controller.onFirmanteChanged,
            onFirmar: () => _firmar(context, inspector: false),
          ),
        ],
      ),
    );
  }

  Future<void> _firmar(BuildContext context, {required bool inspector}) async {
    final sigCtrl = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
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
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (sigCtrl.isNotEmpty) {
                          final bytes = await sigCtrl.toPngBytes();
                          if (bytes != null) {
                            await controller.guardarFirma(
                              inspector: inspector,
                              png: bytes,
                            );
                          }
                        }
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
}

class _FirmaBlock extends StatelessWidget {
  final String titulo;
  final TextEditingController nombreCtrl;
  final String? firmaPath;
  final VoidCallback onNombreChanged;
  final VoidCallback onFirmar;

  const _FirmaBlock({
    required this.titulo,
    required this.nombreCtrl,
    required this.firmaPath,
    required this.onNombreChanged,
    required this.onFirmar,
  });

  @override
  Widget build(BuildContext context) {
    final tieneFirma = firmaPath != null && File(firmaPath!).existsSync();
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
          TextField(
            controller: nombreCtrl,
            onChanged: (_) => onNombreChanged(),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
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
                child: tieneFirma
                    ? Image.file(
                        File(firmaPath!),
                        key: ValueKey(firmaPath),
                        fit: BoxFit.contain,
                      )
                    : const Center(child: Text('Sin firma')),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: onFirmar,
                icon: const Icon(Icons.draw),
                label: Text(tieneFirma ? 'Re-firmar' : 'Firmar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
