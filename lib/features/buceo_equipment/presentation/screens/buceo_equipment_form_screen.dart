import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../../../shared/services/image_service.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../../inspection/presentation/widgets/category_header.dart';
import '../../../inspection/presentation/widgets/question_card.dart';
import '../../domain/models/buceo_equipment_variant.dart';
import '../controllers/buceo_equipment_form_controller.dart';

class BuceoEquipmentFormScreen extends StatelessWidget {
  final BuceoEquipmentVariant variant;
  final Map<String, dynamic>? borrador;

  const BuceoEquipmentFormScreen({
    super.key,
    required this.variant,
    this.borrador,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BuceoEquipmentFormController(
        variant: variant,
        borradorInicial: borrador,
      )..init(),
      child: _BuceoEquipmentFormView(variant: variant),
    );
  }
}

class _BuceoEquipmentFormView extends StatelessWidget {
  final BuceoEquipmentVariant variant;

  const _BuceoEquipmentFormView({required this.variant});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BuceoEquipmentFormController>();
    final fechaFmt = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(ctrl.fechaRealizacion);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardando borrador...'),
            duration: Duration(milliseconds: 800),
          ),
        );
        await ctrl.guardarBorradorSilencioso();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(variant.nombre),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
        body: ctrl.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Datos generales'),
                    _input(
                      ctrl.numeroInformeCtrl,
                      'Numero de informe *',
                      Icons.confirmation_number,
                      readOnly: true,
                    ),
                    _dateField(context, fechaFmt, () => _pickFecha(context)),
                    _input(ctrl.empresaCtrl, 'Empresa', Icons.business),
                    _input(ctrl.areaCtrl, 'Area', Icons.account_tree_outlined),
                    _input(ctrl.regionCtrl, 'Region', Icons.map_outlined),
                    _input(
                      ctrl.supervisorJefaturaCtrl,
                      'Supervisor o jefatura',
                      Icons.manage_accounts_outlined,
                    ),
                    _input(
                      ctrl.embarcacionCtrl,
                      'Embarcacion *',
                      Icons.directions_boat,
                    ),
                    _input(
                      ctrl.lugarFaenaCtrl,
                      'Lugar de faena',
                      Icons.place_outlined,
                    ),
                    _input(
                      ctrl.profesionalCtrl,
                      'Profesional',
                      Icons.person_outline,
                    ),
                    _input(
                      ctrl.profesionalCorreoCtrl,
                      'Correo profesional',
                      Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _input(
                      ctrl.profesionalFonoCtrl,
                      'Fono profesional',
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),

                    _sectionHeaderWithAction(
                      title: 'Compresores',
                      buttonText: 'Agregar',
                      onTap: ctrl.addCompresor,
                    ),
                    ...List.generate(
                      ctrl.compresores.length,
                      (i) => _compresorCard(context, ctrl, i),
                    ),
                    const SizedBox(height: 14),

                    _sectionHeaderWithAction(
                      title: 'Buzos (1 a 5)',
                      buttonText: 'Agregar',
                      onTap: ctrl.addBuzo,
                    ),
                    ...List.generate(
                      ctrl.buzos.length,
                      (i) => _buzoCard(context, ctrl, i),
                    ),
                    const SizedBox(height: 14),

                    _sectionTitle('Checklist (${ctrl.items.length} items)'),
                    if (ctrl.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No hay preguntas configuradas.'),
                      )
                    else
                      _ChecklistCards(),

                    const SizedBox(height: 14),
                    _sectionTitle('Observaciones generales'),
                    TextField(
                      controller: ctrl.observacionesCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Observaciones...',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),
                    _sectionTitle('Galeria general'),
                    GalleryInput(
                      images: ctrl.fotosGenerales,
                      onImagesChanged: ctrl.setFotosGenerales,
                    ),

                    const SizedBox(height: 18),
                    _sectionTitle('Firmas'),
                    _firmaBlock(
                      context,
                      title: 'Profesional',
                      nombreCtrl: ctrl.firmaProfesionalNombreCtrl,
                      image: ctrl.firmaProfesionalImage,
                      onFirmar: () => _firmar(context, supervisor: false),
                    ),
                    const SizedBox(height: 10),
                    _firmaBlock(
                      context,
                      title: 'Supervisor del servicio',
                      nombreCtrl: ctrl.firmaSupervisorNombreCtrl,
                      image: ctrl.firmaSupervisorImage,
                      onFirmar: () => _firmar(context, supervisor: true),
                    ),

                    if (ctrl.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          ctrl.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 18),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003366),
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
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sectionHeaderWithAction({
    required String title,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _sectionTitle(title),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add),
          label: Text(buttonText),
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dateField(BuildContext context, String fecha, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Fecha',
            prefixIcon: Icon(Icons.event),
            border: OutlineInputBorder(),
          ),
          child: Text(fecha),
        ),
      ),
    );
  }

  Widget _compresorCard(
    BuildContext context,
    BuceoEquipmentFormController ctrl,
    int index,
  ) {
    final data = ctrl.compresores[index];
    final isLast = ctrl.compresores.length > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['nombre'] ?? 'Compresor',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (isLast)
                  IconButton(
                    onPressed: () => ctrl.removeCompresor(index),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
              ],
            ),
            _input(
              TextEditingController(text: data['matricula'] ?? ''),
              'Matricula',
              Icons.badge,
              onChanged: (v) => ctrl.updateCompresor(index, 'matricula', v),
            ),
            Row(
              children: [
                Expanded(
                  child: _input(
                    TextEditingController(text: data['vigencia'] ?? ''),
                    'Vigencia',
                    Icons.date_range,
                    onChanged: (v) =>
                        ctrl.updateCompresor(index, 'vigencia', v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _input(
                    TextEditingController(text: data['ph'] ?? ''),
                    'PH',
                    Icons.schedule,
                    onChanged: (v) => ctrl.updateCompresor(index, 'ph', v),
                  ),
                ),
              ],
            ),
            _input(
              TextEditingController(text: data['buzosCargo'] ?? ''),
              'Numero de buzos a cargo',
              Icons.groups,
              keyboardType: TextInputType.number,
              onChanged: (v) => ctrl.updateCompresor(index, 'buzosCargo', v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buzoCard(
    BuildContext context,
    BuceoEquipmentFormController ctrl,
    int index,
  ) {
    final data = ctrl.buzos[index];
    final removable = ctrl.buzos.length > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['titulo'] ?? 'Buzo',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (removable)
                  IconButton(
                    onPressed: () => ctrl.removeBuzo(index),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
              ],
            ),
            _input(
              TextEditingController(text: data['nombre'] ?? ''),
              'Nombre',
              Icons.person,
              onChanged: (v) => ctrl.updateBuzo(index, 'nombre', v),
            ),
            Row(
              children: [
                Expanded(
                  child: _input(
                    TextEditingController(text: data['matricula'] ?? ''),
                    'Matricula',
                    Icons.badge,
                    onChanged: (v) => ctrl.updateBuzo(index, 'matricula', v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _input(
                    TextEditingController(text: data['profundidad'] ?? ''),
                    'Profundidad',
                    Icons.height,
                    onChanged: (v) => ctrl.updateBuzo(index, 'profundidad', v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _firmaBlock(
    BuildContext context, {
    required String title,
    required TextEditingController nombreCtrl,
    required dynamic image,
    required VoidCallback onFirmar,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                child: image != null
                    ? Image.memory(image, fit: BoxFit.contain)
                    : const Center(child: Text('Sin firma')),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onFirmar,
                icon: const Icon(Icons.draw),
                label: Text(image != null ? 'Re-firmar' : 'Firmar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickFecha(BuildContext context) async {
    final ctrl = context.read<BuceoEquipmentFormController>();
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
    final ctrl = context.read<BuceoEquipmentFormController>();
    final ok = await ctrl.guardarDefinitivo();
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inspeccion guardada.')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _firmar(BuildContext context, {required bool supervisor}) async {
    final ctrl = context.read<BuceoEquipmentFormController>();
    final sigCtrl = supervisor
        ? ctrl.signatureSupervisor
        : ctrl.signatureProfesional;
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
                      onPressed: () async {
                        final bytes = await sigCtrl.toPngBytes();
                        if (supervisor) {
                          ctrl.setFirmaSupervisor(bytes);
                        } else {
                          ctrl.setFirmaProfesional(bytes);
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
}

class _ChecklistCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BuceoEquipmentFormController>();
    final gruposGenerales = <String, List<FormularioItem>>{};
    for (final m in ctrl.checklistItemsGenerales) {
      final item = FormularioItem(
        id: m['id'].toString(),
        pregunta: (m['pregunta'] ?? '').toString(),
        categoria: (m['categoria'] ?? 'General').toString(),
        criticidad: (m['criticidad'] ?? 'Tolerable').toString(),
      );
      gruposGenerales.putIfAbsent(item.categoria, () => []).add(item);
    }

    final personalMatrix = ctrl.personalChecklistMatrix();
    final personalPreguntas = personalMatrix.keys.toList();
    final buzosVisibles = ctrl.buzosChecklistVisibles();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (personalPreguntas.isNotEmpty) ...[
          CategoryHeader(nombre: 'Checklist por buzo'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Checklist')),
                ...buzosVisibles.map(
                  (idx) => DataColumn(label: Text('BUZO $idx')),
                ),
              ],
              rows: personalPreguntas.map((preguntaBase) {
                DataCell buildTickCell(int buzoIdx) {
                  final estado =
                      ctrl.respuestaPorPreguntaBuzo(preguntaBase, buzoIdx) ??
                      'NC';
                  final checked = estado == 'C';
                  return DataCell(
                    Checkbox(
                      value: checked,
                      onChanged: (value) {
                        ctrl.setRespuestaPreguntaBuzo(
                          preguntaBase,
                          buzoIdx,
                          value == true ? 'C' : 'NC',
                        );
                      },
                    ),
                  );
                }

                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 420, child: Text(preguntaBase))),
                    ...buzosVisibles.map(buildTickCell),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...gruposGenerales.entries.map((entry) {
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
                  onCriticidadChanged: (v) =>
                      ctrl.setCriticidadById(item.id, v),
                  onTomarFotoTap: () =>
                      _tomarFotoPregunta(context, ctrl, item.id),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}

void _tomarFotoPregunta(
  BuildContext context,
  BuceoEquipmentFormController ctrl,
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
