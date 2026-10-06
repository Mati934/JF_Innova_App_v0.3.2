import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/tap_to_sign_field.dart';
import '../../../prosesso/presentation/widgets/prosesso_extintor_card.dart';
import '../controllers/merieux_extintores_form_controller.dart';
import 'merieux_visita_form_screen.dart' show kMerieuxAzul;

/// Formulario del submódulo "Merieux — Mantención de Extintores": mismo
/// encabezado que Merieux Visitas + grilla de N extintores (checklist de 9
/// preguntas c/u, igual que Prosesso).
class MerieuxExtintoresFormScreen extends StatelessWidget {
  final Map<String, dynamic>? borrador;
  const MerieuxExtintoresFormScreen({super.key, this.borrador});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          MerieuxExtintoresFormController(borradorInicial: borrador)..init(),
      child: const _MerieuxExtintoresFormView(),
    );
  }
}

class _MerieuxExtintoresFormView extends StatelessWidget {
  const _MerieuxExtintoresFormView();

  Future<void> _pickHora(
    BuildContext context,
    TextEditingController ctrl,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) ctrl.text = picked.format(context);
  }

  Future<void> _guardar(
    BuildContext context,
    MerieuxExtintoresFormController ctrl, {
    required bool definitivo,
  }) async {
    final ok = definitivo
        ? await ctrl.guardarDefinitivo()
        : await ctrl.guardarBorrador();
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            definitivo ? 'Registro guardado.' : 'Borrador guardado.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.errorMessage ?? 'No se pudo guardar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MerieuxExtintoresFormController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 15),
                Text('Guardando borrador...'),
              ],
            ),
            duration: Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await ctrl.guardarBorradorSilencioso();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kMerieuxAzul,
          foregroundColor: Colors.white,
          title: const Text('Merieux · Mantención de Extintores'),
        ),
        floatingActionButton: ctrl.isSaving
            ? null
            : FloatingActionButton.extended(
                backgroundColor: kMerieuxAzul,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.check),
                label: const Text('Finalizar'),
                onPressed: () => _guardar(context, ctrl, definitivo: true),
              ),
        body: ctrl.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Profesional'),
                    _input(
                      ctrl.profesionalCtrl,
                      'Profesional',
                      Icons.badge_outlined,
                    ),
                    _input(
                      ctrl.fonoProfesionalCtrl,
                      'Fono',
                      Icons.phone,
                      type: TextInputType.phone,
                    ),
                    _input(
                      ctrl.correoProfesionalCtrl,
                      'Correo',
                      Icons.alternate_email,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Datos de la visita'),
                    _input(ctrl.regionCtrl, 'Región', Icons.map),
                    _input(ctrl.areaCtrl, 'Área', Icons.business),
                    _input(ctrl.jefaturaCtrl, 'Jefatura a cargo', Icons.person),
                    _input(
                      ctrl.origenCtrl,
                      'Origen de la actividad',
                      Icons.flag,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _HoraField(
                            label: 'Hora de inicio',
                            controller: ctrl.horaInicioCtrl,
                            onTap: () =>
                                _pickHora(context, ctrl.horaInicioCtrl),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HoraField(
                            label: 'Hora de término',
                            controller: ctrl.horaTerminoCtrl,
                            onTap: () =>
                                _pickHora(context, ctrl.horaTerminoCtrl),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Correos del informe'),
                    _input(
                      ctrl.correo1Ctrl,
                      'Correo 1',
                      Icons.email,
                      type: TextInputType.emailAddress,
                    ),
                    _input(
                      ctrl.correo2Ctrl,
                      'Correo 2 (opcional)',
                      Icons.email_outlined,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Extintores (${ctrl.extintores.length})'),
                    for (var i = 0; i < ctrl.extintores.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ProsessoExtintorCard(
                          controller: ctrl,
                          index: i,
                          extintor: ctrl.extintores[i],
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: ctrl.agregarExtintor,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar extintor'),
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Observaciones generales'),
                    TextField(
                      controller: ctrl.observacionesCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Firma'),
                    _input(
                      ctrl.firmaNombreCtrl,
                      'Nombre de quien firma',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 10),
                    TapToSignField(
                      titulo: 'Firma',
                      imagen: ctrl.signatureImage,
                      color: kMerieuxAzul,
                      onFirmado: ctrl.setSignatureImage,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => ctrl.previsualizarReporte(context),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Previsualizar PDF'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HoraField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;
  const _HoraField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(controller.text.isEmpty ? '--:--' : controller.text),
      ),
    );
  }
}

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
  ),
);

Widget _input(
  TextEditingController controller,
  String label,
  IconData icon, {
  TextInputType? type,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(
    controller: controller,
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    ),
  ),
);
