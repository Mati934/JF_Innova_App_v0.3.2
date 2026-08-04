import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../../../core/modules/hidroser_checklists.dart';
import '../../../../core/services/user_session.dart';
import '../../../../shared/services/image_service.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../inspection/presentation/widgets/category_header.dart';
import '../../../inspection/presentation/widgets/question_card.dart';
import '../../../email/services/email_dispatch_service.dart';
import '../../../email/services/email_flow_service.dart';
import '../../../email/services/email_pending_service.dart';
import '../../../../core/utils/safe_area_utils.dart';
import '../../domain/models/hidroser_lista.dart';
import '../controllers/hidroser_form_controller.dart';

class HidroserFormScreen extends StatelessWidget {
  final HidroserLista lista;
  final Map<String, dynamic>? borrador;
  const HidroserFormScreen({super.key, required this.lista, this.borrador});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          HidroserFormController(lista: lista, borradorInicial: borrador)
            ..init(),
      child: const _HidroserFormView(),
    );
  }
}

class _HidroserFormView extends StatelessWidget {
  const _HidroserFormView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HidroserFormController>();
    final safeBottom = SafeAreaUtils.safeBottomInset(context, extra: 16);
    final fechaFmt = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(ctrl.fechaRealizacion);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Autoguardado silencioso del borrador al retroceder, mismo patrón
        // que `ExtintorFormScreen`.
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
          backgroundColor: kHidroserColor,
          foregroundColor: Colors.white,
          title: const Text('Inspección Grúa Horquilla'),
        ),
        body: ctrl.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Datos de la inspección'),
                    _input(
                      ctrl.quienInspeccionaCtrl,
                      'Quien realiza la inspección',
                      Icons.person,
                    ),
                    _DateField(
                      fecha: fechaFmt,
                      onPick: () => _pickFecha(context),
                    ),
                    for (final def in ctrl.lista.camposExtra)
                      _input(
                        ctrl.camposExtraCtrls[def.clave]!,
                        def.label + (def.requerido ? ' *' : ''),
                        def.tipo == 'numero'
                            ? Icons.numbers
                            : Icons.text_fields,
                        keyboardType: def.tipo == 'numero'
                            ? TextInputType.number
                            : TextInputType.text,
                      ),
                    const SizedBox(height: 16),
                    _sectionTitle('Checklist (${ctrl.items.length} ítems)'),
                    if (ctrl.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No hay preguntas configuradas para esta lista.',
                        ),
                      )
                    else
                      _ChecklistCards(),
                    const SizedBox(height: 16),
                    _sectionTitle('Observaciones'),
                    TextField(
                      controller: ctrl.observacionesCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Observaciones generales…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('Galería general'),
                    GalleryInput(
                      images: ctrl.fotosGenerales,
                      onImagesChanged: ctrl.setFotosGenerales,
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('Firmas'),
                    _FirmaBlock(
                      titulo: 'Supervisor de turno',
                      nombreCtrl: ctrl.firmaSupervisorNombreCtrl,
                      imagen: ctrl.firmaSupervisorImage,
                      onFirmar: () => _firmar(context, isSupervisor: true),
                    ),
                    const SizedBox(height: 14),
                    _FirmaBlock(
                      titulo: 'Operador de grúa',
                      nombreCtrl: ctrl.firmaOperadorNombreCtrl,
                      imagen: ctrl.firmaOperadorImage,
                      onFirmar: () => _firmar(context, isSupervisor: false),
                    ),
                    const SizedBox(height: 24),
                    if (ctrl.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          ctrl.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: ctrl.isSaving
                                ? null
                                : () => ctrl.previsualizarReporte(context),
                            icon: const Icon(Icons.preview),
                            label: const Text('Previsualizar PDF'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kHidroserColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: ctrl.isSaving
                                ? null
                                : () => _guardar(context),
                            icon: ctrl.isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Guardar definitivo'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: safeBottom),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickFecha(BuildContext context) async {
    final ctrl = context.read<HidroserFormController>();
    final picked = await showDatePicker(
      context: context,
      initialDate: ctrl.fechaRealizacion,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ctrl.fechaRealizacion),
    );
    final time = t ?? TimeOfDay.fromDateTime(ctrl.fechaRealizacion);
    ctrl.setFecha(
      DateTime(picked.year, picked.month, picked.day, time.hour, time.minute),
    );
  }

  Future<void> _guardar(BuildContext context) async {
    final ctrl = context.read<HidroserFormController>();
    final ok = await ctrl.guardarDefinitivo();
    if (!context.mounted) return;
    if (ok) {
      await _tryOpenConfiguredEmail(context, ctrl);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspección guardada correctamente.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmarPrepararCorreo(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preparar correo'),
        content: const Text('¿Deseas preparar el correo en este momento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, preparar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _tryOpenConfiguredEmail(
    BuildContext context,
    HidroserFormController ctrl,
  ) async {
    final fechaIso = DateFormat('yyyy-MM-dd').format(ctrl.fechaRealizacion);
    final hora = DateFormat('HH:mm').format(ctrl.fechaRealizacion);

    final supervisor = ctrl.firmaSupervisorNombreCtrl.text.trim().isNotEmpty
        ? ctrl.firmaSupervisorNombreCtrl.text.trim()
        : (ctrl.quienInspeccionaCtrl.text.trim().isNotEmpty
              ? ctrl.quienInspeccionaCtrl.text.trim()
              : 'Supervisor responsable');

    final moduleKeys = <String>[
      if (ctrl.lista.codigo.toUpperCase() == 'GRUA_HORQUILLA_PFA')
        'hidroser_grua_horquilla',
      'hidroser',
    ];

    final dispatch = await EmailDispatchService().resolveForModules(
      moduleKeys: moduleKeys,
      empresaId: UserSession().empresaId,
      usuarioId: UserSession().userId,
      templateValues: {
        'fecha_inspeccion': fechaIso,
        'hora_inspeccion': hora,
        'supervisor_nombre': supervisor,
      },
    );

    if (dispatch == null || !context.mounted) return;

    final registroId = ctrl.lastSavedRegistroId ?? ctrl.inspeccionId;
    final empresaId = UserSession().empresaId;
    final usuarioId = UserSession().userId;

    if (!ctrl.lastSyncSucceeded) {
      await EmailPendingService().enqueuePending(
        registroId: registroId,
        moduleKey: dispatch.moduleKey,
        empresaId: empresaId,
        usuarioId: usuarioId,
        configId: dispatch.configId,
        listaId: dispatch.listaId,
        subject: dispatch.subject,
        body: dispatch.body,
        recipients: dispatch.suggestedRecipients,
        estado: 'pendiente_sync',
        attachmentPath: ctrl.lastSavedPdfPath,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correo pendiente: se ofrecerá cuando el registro sincronice.',
          ),
        ),
      );
      return;
    }

    final abrirCorreo = await _confirmarPrepararCorreo(context);
    if (!abrirCorreo) {
      await EmailPendingService().enqueuePending(
        registroId: registroId,
        moduleKey: dispatch.moduleKey,
        empresaId: empresaId,
        usuarioId: usuarioId,
        configId: dispatch.configId,
        listaId: dispatch.listaId,
        subject: dispatch.subject,
        body: dispatch.body,
        recipients: dispatch.suggestedRecipients,
        estado: 'pendiente',
        attachmentPath: ctrl.lastSavedPdfPath,
      );
      return;
    }

    if (!context.mounted) return;

    await EmailPendingService().markOpened(
      registroId: registroId,
      moduleKey: dispatch.moduleKey,
    );

    if (!context.mounted) return;

    final previewResult = await EmailFlowService.openPreview(
      context: context,
      subject: dispatch.subject,
      body: dispatch.body,
      recipients: dispatch.suggestedRecipients,
      suggestedRecipients: dispatch.suggestedRecipients,
      attachmentName: 'lista_verificacion_grua_horquilla.pdf',
      attachmentPath: ctrl.lastSavedPdfPath,
    );

    final sent = previewResult?['sent'] == true;
    if (sent) {
      await EmailPendingService().deleteByRegistro(
        registroId: registroId,
        moduleKey: dispatch.moduleKey,
      );
    } else {
      final recipientsDynamic = previewResult?['recipients'];
      final recipients = recipientsDynamic is List
          ? recipientsDynamic
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : dispatch.suggestedRecipients;

      await EmailPendingService().enqueuePending(
        registroId: registroId,
        moduleKey: dispatch.moduleKey,
        empresaId: empresaId,
        usuarioId: usuarioId,
        configId: dispatch.configId,
        listaId: dispatch.listaId,
        subject: (previewResult?['subject'] ?? dispatch.subject).toString(),
        body: (previewResult?['body'] ?? dispatch.body).toString(),
        recipients: recipients,
        estado: 'pendiente',
        attachmentPath:
            (previewResult?['attachment_path'] ?? ctrl.lastSavedPdfPath)
                ?.toString(),
      );
    }
  }

  Future<void> _firmar(
    BuildContext context, {
    required bool isSupervisor,
  }) async {
    final ctrl = context.read<HidroserFormController>();
    final sigCtrl = isSupervisor
        ? ctrl.signatureSupervisor
        : ctrl.signatureOperador;
    sigCtrl.clear();

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
                        backgroundColor: kHidroserColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final bytes = await sigCtrl.toPngBytes();
                        if (bytes != null) {
                          if (isSupervisor) {
                            ctrl.setFirmaSupervisorImage(bytes);
                          } else {
                            ctrl.setFirmaOperadorImage(bytes);
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
  }

  // --- helpers UI ---

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );

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

class _ChecklistCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HidroserFormController>();
    final grupos = ctrl.agruparPorCategoria();

    // Nota: `QuestionCard` y `CategoryHeader` ya traen su propio margen
    // horizontal interno (14px). El padding del SingleChildScrollView (16)
    // sumará un pequeño borde extra, pero no usamos margen negativo porque
    // dispara la assertion `margin.isNonNegative` del Container.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: grupos.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryHeader(nombre: entry.key),
            ...entry.value.map((item) {
              return QuestionCard(
                key: ValueKey(item.id),
                item: item,
                respuestaInicial: ctrl.respuestaDe(item.id),
                observacionInicial: ctrl.observacionDe(item.id),
                criticidadInicial: ctrl.criticidadDe(item.id),
                fotoInicial: ctrl.fotosPorPregunta[item.id],
                onRespuestaChanged: (v) => ctrl.setRespuestaById(item.id, v),
                onObservacionChanged: (v) =>
                    ctrl.setObservacionById(item.id, v),
                onCriticidadChanged: (v) => ctrl.setCriticidadById(item.id, v),
                onTomarFotoTap: () =>
                    _tomarFotoPregunta(context, ctrl, item.id),
              );
            }),
          ],
        );
      }).toList(),
    );
  }
}

void _tomarFotoPregunta(
  BuildContext context,
  HidroserFormController ctrl,
  String itemId,
) {
  ImageService.mostrarOpciones(
    context,
    soloUna: true,
    onFotoTomada: (File f) => ctrl.setFotoPregunta(itemId, f),
    onGaleriaSeleccionada: (List<File> files) {
      if (files.isNotEmpty) ctrl.setFotoPregunta(itemId, files.first);
    },
  );
}

class _DateField extends StatelessWidget {
  final String fecha;
  final VoidCallback onPick;
  const _DateField({required this.fecha, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onPick,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Fecha de la inspección',
            prefixIcon: Icon(Icons.event),
            border: OutlineInputBorder(),
          ),
          child: Text(fecha),
        ),
      ),
    );
  }
}

class _FirmaBlock extends StatelessWidget {
  final String titulo;
  final TextEditingController nombreCtrl;
  final dynamic imagen; // Uint8List?
  final VoidCallback onFirmar;
  const _FirmaBlock({
    required this.titulo,
    required this.nombreCtrl,
    required this.imagen,
    required this.onFirmar,
  });

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
          TextField(
            controller: nombreCtrl,
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
                child: imagen != null
                    ? Image.memory(imagen, fit: BoxFit.contain)
                    : const Center(child: Text('Sin firma')),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kHidroserColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: onFirmar,
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
