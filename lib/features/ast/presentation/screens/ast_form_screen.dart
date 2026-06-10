import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../shared/services/image_service.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../../shared/widgets/hallazgo_card.dart';
import '../controllers/ast_form_controller.dart';

const Color kAstColor = Color(0xFF003366);

class AstFormScreen extends StatelessWidget {
  final String informeId;
  const AstFormScreen({super.key, required this.informeId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AstFormController(informeId: informeId)..init(),
      child: const _AstFormView(),
    );
  }
}

class _AstFormView extends StatelessWidget {
  const _AstFormView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AstFormController>();
    final fechaFmt = ctrl.isLoading
        ? ''
        : DateFormat('dd/MM/yyyy HH:mm').format(ctrl.informe.fechaRealizacion);

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
          backgroundColor: kAstColor,
          foregroundColor: Colors.white,
          title: const Text('Análisis Seguro de Trabajo'),
        ),
        body: ctrl.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _AstBanner(),
                    const SizedBox(height: 16),
                    _sectionTitle('Datos del AST'),
                    _DatosResumen(ctrl: ctrl),
                    _DateField(
                      fecha: fechaFmt,
                      onPick: () => _pickFecha(context),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Descripción de la actividad'),
                    TextField(
                      controller: ctrl.descripcionCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe la actividad a realizar, su alcance y condiciones…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _sectionTitle(
                            'Hallazgos (${ctrl.hallazgos.length})',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: ctrl.agregarHallazgo,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Añadir hallazgo'),
                          style: TextButton.styleFrom(
                            foregroundColor: kAstColor,
                          ),
                        ),
                      ],
                    ),
                    if (ctrl.hallazgos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Aún no hay hallazgos. Pulsa "Añadir hallazgo" para registrar uno.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      const _HallazgosList(),
                    const SizedBox(height: 16),
                    _sectionTitle('Observaciones generales'),
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
                              backgroundColor: kAstColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: ctrl.isSaving
                                ? null
                                : () => _finalizar(context),
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickFecha(BuildContext context) async {
    final ctrl = context.read<AstFormController>();
    final picked = await showDatePicker(
      context: context,
      initialDate: ctrl.informe.fechaRealizacion,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ctrl.informe.fechaRealizacion),
    );
    final time = t ?? TimeOfDay.fromDateTime(ctrl.informe.fechaRealizacion);
    ctrl.setFecha(
      DateTime(picked.year, picked.month, picked.day, time.hour, time.minute),
    );
  }

  Future<void> _finalizar(BuildContext context) async {
    final ctrl = context.read<AstFormController>();
    final ok = await ctrl.finalizar();
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AST guardado. Se sincronizará en segundo plano.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );
}

class _AstBanner extends StatelessWidget {
  const _AstBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAstColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, color: kAstColor),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  TextSpan(
                    text: 'AST · ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kAstColor,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Análisis Seguro de Trabajo. Registra la actividad, sus hallazgos y evidencias.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatosResumen extends StatelessWidget {
  final AstFormController ctrl;
  const _DatosResumen({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final i = ctrl.informe;
    final rows = <List<String>>[
      ['Área', i.areaNombre ?? '—'],
      ['Centro', i.centroNombre ?? '—'],
      ['Empresa', i.contratistaNombre ?? '—'],
      if ((i.embarcacionNombre ?? '').isNotEmpty)
        ['Embarcación', i.embarcacionNombre!],
      ['Profesional', i.profesional],
      if ((ctrl.correlativo ?? '').isNotEmpty)
        ['N° Informe', ctrl.correlativo!],
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: rows
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        r[0],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(child: Text(r[1])),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HallazgosList extends StatelessWidget {
  const _HallazgosList();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AstFormController>();
    return Column(
      children: ctrl.hallazgos.map((h) {
        return HallazgoCard(
          key: ValueKey(h.id),
          numero: h.numero,
          tituloInicial: h.titulo,
          detalleInicial: h.detalle,
          fotoInicial: ctrl.fotoHallazgo(h.id),
          onTituloChanged: (v) => ctrl.setTituloHallazgo(h.id, v),
          onDetalleChanged: (v) => ctrl.setDetalleHallazgo(h.id, v),
          onTomarFoto: () => _tomarFoto(context, ctrl, h.id),
          onQuitarFoto: () => ctrl.quitarFotoHallazgo(h.id),
          onEliminar: () => ctrl.eliminarHallazgo(h.id),
        );
      }).toList(),
    );
  }

  void _tomarFoto(BuildContext context, AstFormController ctrl, String id) {
    ImageService.mostrarOpciones(
      context,
      soloUna: true,
      onFotoTomada: (File f) => ctrl.setFotoHallazgo(id, f),
      onGaleriaSeleccionada: (List<File> files) {
        if (files.isNotEmpty) ctrl.setFotoHallazgo(id, files.first);
      },
    );
  }
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
            labelText: 'Fecha de realización',
            prefixIcon: Icon(Icons.event),
            border: OutlineInputBorder(),
          ),
          child: Text(fecha),
        ),
      ),
    );
  }
}
