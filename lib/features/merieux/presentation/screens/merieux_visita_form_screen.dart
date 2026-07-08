import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/tap_to_sign_field.dart';
import '../../../inspection/presentation/widgets/category_header.dart';
import '../../../inspection/presentation/widgets/question_card.dart';
import '../controllers/merieux_visita_form_controller.dart';

const Color kMerieuxAzul = Color(0xFF1B3B6F);
const Color kMerieuxCyan = Color(0xFF29ABE2);
const Color kMerieuxVerde = Color(0xFFA8C93A);

/// Formulario del submódulo "Merieux — Registro de Visita" (encabezado +
/// checklist opcional de Vehículos Livianos).
class MerieuxVisitaFormScreen extends StatelessWidget {
  final Map<String, dynamic>? borrador;
  const MerieuxVisitaFormScreen({super.key, this.borrador});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          MerieuxVisitaFormController(borradorInicial: borrador)..init(),
      child: const _MerieuxVisitaFormView(),
    );
  }
}

class _MerieuxVisitaFormView extends StatelessWidget {
  const _MerieuxVisitaFormView();

  Future<void> _pickHora(
    BuildContext context,
    TextEditingController ctrl,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      ctrl.text = picked.format(context);
    }
  }

  Future<void> _guardar(
    BuildContext context,
    MerieuxVisitaFormController ctrl, {
    required bool definitivo,
  }) async {
    final ok = definitivo
        ? await ctrl.guardarDefinitivo()
        : await ctrl.guardarBorrador();
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(definitivo ? 'Visita guardada.' : 'Borrador guardado.'),
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
    final ctrl = context.watch<MerieuxVisitaFormController>();

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
          title: const Text('Merieux · Registro de Visita'),
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
                    const SizedBox(height: 8),
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
                    _sectionTitle('Checklist'),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: ctrl.incluirChecklistVehiculos,
                      activeThumbColor: kMerieuxAzul,
                      title: const Text('Incluir checklist Vehículos Livianos'),
                      subtitle: const Text(
                        'Si está apagado, queda como Registro de Visita (Sin checklist).',
                      ),
                      onChanged: ctrl.toggleIncluirChecklist,
                    ),
                    if (ctrl.incluirChecklistVehiculos) ...[
                      const CategoryHeader(nombre: 'Vehículos Livianos'),
                      for (final item in ctrl.checklistItems)
                        QuestionCard(
                          item: item,
                          respuestaInicial: ctrl.respuestaDe(item.id),
                          observacionInicial: null,
                          criticidadInicial: 'Tolerable',
                          onRespuestaChanged: (v) =>
                              ctrl.setRespuestaById(item.id, v),
                          onObservacionChanged: (v) =>
                              ctrl.setObservacionById(item.id, v),
                          onCriticidadChanged: (_) {},
                        ),
                    ],
                    const SizedBox(height: 14),
                    _sectionTitle('Observaciones'),
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
