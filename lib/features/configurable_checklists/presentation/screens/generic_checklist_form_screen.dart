import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../inspection/presentation/widgets/category_header.dart';
import '../../../inspection/presentation/widgets/question_card.dart';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveAndClose(context, controller);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(controller.checklist.nombre),
          actions: [
            IconButton(
              tooltip: 'Guardar borrador',
              onPressed: controller.canSave
                  ? () => _saveDraft(context, controller)
                  : null,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.errorMessage != null
            ? _ErrorState(message: controller.errorMessage!)
            : _ChecklistBody(controller: controller),
      ),
    );
  }

  Future<void> _saveDraft(
    BuildContext context,
    ConfigurableChecklistFormController controller,
  ) async {
    try {
      await controller.saveDraft();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Borrador guardado localmente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error CHECKLIST_DRAFT: $e')));
      }
    }
  }

  Future<void> _saveAndClose(
    BuildContext context,
    ConfigurableChecklistFormController controller,
  ) async {
    if (controller.canSave) {
      await _saveDraft(context, controller);
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _ChecklistBody extends StatelessWidget {
  final ConfigurableChecklistFormController controller;

  const _ChecklistBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Borrador local | Version ${controller.version!.version}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
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
                onRespuestaChanged: (value) =>
                    controller.setRespuesta(item.id, value),
                onObservacionChanged: (value) =>
                    controller.setObservacion(item.id, value),
                onCriticidadChanged: (value) =>
                    controller.setCriticidad(item.id, value),
              ),
            ),
          ];
        }),
        if (controller.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Este checklist no tiene preguntas publicadas.'),
          ),
      ],
    );
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
