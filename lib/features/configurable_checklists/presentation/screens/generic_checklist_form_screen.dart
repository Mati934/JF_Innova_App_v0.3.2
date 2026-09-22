import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../../../core/utils/safe_area_utils.dart';
import '../../../../shared/services/image_service.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../inspection/presentation/widgets/category_header.dart';
import '../../../inspection/presentation/widgets/question_card.dart';
import '../checklist_icons.dart';
import '../../domain/models/configurable_checklist.dart';
import '../controllers/configurable_checklist_form_controller.dart';

class GenericChecklistFormScreen extends StatelessWidget {
  final ConfigurableChecklist checklist;
  final String? draftId;

  const GenericChecklistFormScreen({
    super.key,
    required this.checklist,
    this.draftId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConfigurableChecklistFormController(
        checklist: checklist,
        draftId: draftId,
      )..load(),
      child: const _GenericChecklistFormView(),
    );
  }
}

class _GenericChecklistFormView extends StatelessWidget {
  const _GenericChecklistFormView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConfigurableChecklistFormController>();
    final accent = checklistColorFromHex(controller.checklist.color);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveAndClose(context, controller);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          title: Text(controller.checklist.nombreVisible),
          actions: [
            IconButton(
              tooltip: controller.isPreviewing
                  ? 'Preparando vista previa…'
                  : 'Previsualizar PDF',
              onPressed: (controller.isSaving || controller.isPreviewing)
                  ? null
                  : () => _previewPdf(context, controller),
              icon: controller.isPreviewing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.preview_outlined),
            ),
          ],
        ),
        body: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.errorMessage != null
            ? _ErrorState(message: controller.errorMessage!)
            : Stack(
                children: [
                  SafeArea(
                    child: _ChecklistBody(
                      controller: controller,
                      onFinalize: () => _finalize(context, controller),
                    ),
                  ),
                  if (controller.isPreviewing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.2),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                'Cargando previsualizador…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _previewPdf(
    BuildContext context,
    ConfigurableChecklistFormController controller,
  ) async {
    try {
      final pdf = await controller.previsualizarPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name: controller.checklist.nombreVisible,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error CHECKLIST_PREVIEW: $e')));
      }
    }
  }

  Future<void> _saveAndClose(
    BuildContext context,
    ConfigurableChecklistFormController controller,
  ) async {
    if (controller.canSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardando borrador...'),
          duration: Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await controller.guardarBorradorSilencioso();
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _finalize(
    BuildContext context,
    ConfigurableChecklistFormController controller,
  ) async {
    try {
      await controller.finalize();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              controller.lastSyncSucceeded
                  ? 'Checklist finalizado y sincronizado.'
                  : 'Checklist guardado. Se sincronizará en segundo plano.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error CHECKLIST_FINALIZE: $e')));
      }
    }
  }
}

class _ChecklistBody extends StatelessWidget {
  final ConfigurableChecklistFormController controller;
  final VoidCallback onFinalize;

  const _ChecklistBody({required this.controller, required this.onFinalize});

  @override
  Widget build(BuildContext context) {
    final safeBottom = SafeAreaUtils.safeBottomInset(context, extra: 16);
    final fechaFmt = DateFormat(
      'dd/MM/yyyy',
    ).format(controller.fechaRealizacion);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Versión ${controller.version!.version}  ·  $fechaFmt',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _sectionTitle('Datos generales'),
          _input(controller.supervisorCtrl, 'Supervisor a cargo', Icons.badge),
          _input(
            controller.supervisorCorreoCtrl,
            'Correo de supervisor',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          ...controller.camposPorSeccion.entries.expand(
            (entry) => _buildCamposSeccion(context, entry.key, entry.value),
          ),
          const SizedBox(height: 8),
          _sectionTitle(
            '${controller.checklist.nombreVisible} (${controller.items.length} ítems)',
          ),
          ...controller.groupedItems.entries.expand((entry) {
            return <Widget>[
              CategoryHeader(nombre: entry.key),
              ...entry.value.map(
                (item) => QuestionCard(
                  key: ValueKey(item.id),
                  item: item,
                  respuestaInicial: controller.respuestaDe(item.id),
                  observacionInicial: controller.observacionDe(item.id),
                  criticidadInicial: controller.criticidadDe(item.id),
                  fotoInicial: controller.fotosPorPregunta[item.id],
                  onRespuestaChanged: (value) =>
                      controller.setRespuesta(item.id, value),
                  onObservacionChanged: (value) =>
                      controller.setObservacion(item.id, value),
                  onCriticidadChanged: (value) =>
                      controller.setCriticidad(item.id, value),
                  onTomarFotoTap: () => _tomarFoto(context, item.id),
                ),
              ),
            ];
          }),
          if (controller.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Este checklist no tiene preguntas publicadas.'),
            ),
          const SizedBox(height: 8),
          _sectionTitle('Apuntes / Observaciones'),
          TextField(
            controller: controller.apuntesObservacionesCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Apuntes y observaciones generales…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Fotos generales'),
          GalleryInput(
            images: controller.fotosGenerales,
            onImagesChanged: (files) => controller.setFotosGenerales(files),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Firma'),
          _FirmaBlock(controller: controller),
          if (controller.missingResponses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Responde todos los ítems (C / NC / N-A) para poder finalizar.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: controller.canFinalize && !controller.isSaving
                  ? onFinalize
                  : null,
              icon: controller.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.task_alt_outlined),
              label: Text(
                controller.isSaving ? 'Finalizando...' : 'Finalizar checklist',
              ),
            ),
          ),
          SizedBox(height: safeBottom + 24),
        ],
      ),
    );
  }

  Future<void> _tomarFoto(BuildContext context, String itemId) async {
    ImageService.mostrarOpciones(
      context,
      soloUna: true,
      onFotoTomada: (file) => controller.setFotoPregunta(itemId, file),
      onGaleriaSeleccionada: (files) {
        if (files.isNotEmpty) controller.setFotoPregunta(itemId, files.first);
      },
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );

  /// Renderiza los campos dinámicos de una sección del catálogo
  /// (`checklist_campo_definiciones` + `checklist_campo_asignaciones`),
  /// eligiendo el widget según `def.tipo`. Agregar un campo nuevo a un
  /// checklist NO requiere tocar este switch: solo el tipo debe existir acá.
  List<Widget> _buildCamposSeccion(
    BuildContext context,
    String seccion,
    List<ChecklistCampoDefinicion> defs,
  ) {
    final fields = <Widget>[
      if (seccion != 'Datos generales') _sectionTitle(seccion),
    ];
    for (var index = 0; index < defs.length; index++) {
      final current = defs[index];
      final next = index + 1 < defs.length ? defs[index + 1] : null;
      if (current.tipo == 'hora' && next?.tipo == 'hora') {
        fields.add(
          Row(
            children: [
              Expanded(child: _buildCampo(context, current)),
              const SizedBox(width: 12),
              Expanded(child: _buildCampo(context, next!)),
            ],
          ),
        );
        index++;
      } else {
        fields.add(_buildCampo(context, current));
      }
    }
    return fields;
  }

  Widget _buildCampo(BuildContext context, ChecklistCampoDefinicion def) {
    final label = def.requerido ? '${def.etiqueta} *' : def.etiqueta;
    switch (def.tipo) {
      case 'hora':
        return _TimeField(
          label: label,
          value: controller.camposHora[def.clave],
          onPick: (t) => controller.setCampoHora(def.clave, t),
        );
      case 'fecha':
        return _DateField(
          label: label,
          value: controller.camposFecha[def.clave],
          onPick: (d) => controller.setCampoFecha(def.clave, d),
        );
      case 'booleano':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            value: controller.camposBooleano[def.clave] ?? false,
            onChanged: (v) => controller.setCampoBooleano(def.clave, v),
          ),
        );
      case 'seleccion_unica':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
            initialValue: controller.camposSeleccionUnica[def.clave],
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            items: def.opciones
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) {
              if (v != null) controller.setCampoSeleccionUnica(def.clave, v);
            },
          ),
        );
      case 'seleccion_multiple':
        final seleccionadas =
            controller.camposSeleccionMultiple[def.clave] ?? const <String>{};
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Wrap(
                spacing: 8,
                children: def.opciones
                    .map(
                      (o) => FilterChip(
                        label: Text(o),
                        selected: seleccionadas.contains(o),
                        onSelected: (_) => controller
                            .toggleCampoSeleccionMultiple(def.clave, o),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      case 'numero':
        return _input(
          controller.camposTextoCtrls[def.clave]!,
          label,
          Icons.numbers,
          keyboardType: TextInputType.number,
        );
      case 'email':
        return _input(
          controller.camposTextoCtrls[def.clave]!,
          label,
          Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        );
      case 'telefono':
        return _input(
          controller.camposTextoCtrls[def.clave]!,
          label,
          Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        );
      case 'texto_largo':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: controller.camposTextoCtrls[def.clave],
            maxLines: 3,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        );
      default: // texto
        return _input(
          controller.camposTextoCtrls[def.clave]!,
          label,
          Icons.text_fields,
        );
    }
  }

  Widget _input(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (picked != null) onPick(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
          child: Text(
            value == null ? '—' : DateFormat('dd/MM/yyyy').format(value!),
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onPick;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: value ?? TimeOfDay.now(),
          );
          if (picked != null) onPick(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.schedule),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
          child: Text(value == null ? '—' : value!.format(context)),
        ),
      ),
    );
  }
}

class _FirmaBlock extends StatelessWidget {
  final ConfigurableChecklistFormController controller;

  const _FirmaBlock({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller.firmaNombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre de quien firma',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: controller.firmaImagen != null
              ? Image.memory(controller.firmaImagen!, fit: BoxFit.contain)
              : Text(
                  'Sin firma capturada',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _firmar(context),
          icon: const Icon(Icons.draw_outlined),
          label: const Text('Capturar firma'),
        ),
      ],
    );
  }

  Future<void> _firmar(BuildContext context) async {
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
                      onPressed: () async {
                        final bytes = await sigCtrl.toPngBytes();
                        if (bytes != null) {
                          controller.setFirmaImagen(bytes);
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

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No se pudo cargar el checklist.\nCódigo: $message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
