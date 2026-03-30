import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../../shared/services/image_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/visit_form_controller.dart';
import '../../../inspection/presentation/widgets/question_card.dart';
import '../../../inspection/presentation/widgets/category_header.dart';

class VisitFormScreen extends StatelessWidget {
  // CLEAN CODE: Recibimos el mapa del borrador de SQLite (opcional)
  final Map<String, dynamic>? borrador;

  const VisitFormScreen({super.key, this.borrador});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final ctrl = VisitFormController();
        // Si nos pasaron un borrador, lo cargamos INMEDIATAMENTE
        // antes de que la UI se dibuje. Adiós duplicados.
        if (borrador != null) {
          ctrl.cargarBorrador(borrador!);
        }
        return ctrl;
      },
      child: const _VisitFormView(),
    );
  }
}

class _VisitFormView extends StatelessWidget {
  const _VisitFormView();

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<VisitFormController>(context);

    // Si está cargando datos de SQLite iniciales, bloqueamos la UI
    if (ctrl.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🛡️ AQUÍ ENTRA EL POPSCOPE 🛡️
    return PopScope(
      canPop: false, // Bloqueamos la salida instantánea de Android
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Feedback visual rápido
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

        // Forzamos el guardado del borrador a SQLite
        await ctrl.guardarBorradorSilencioso();

        // Salimos de la pantalla manualmente
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Registro de Visita (R-003)"),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: ctrl.isSaving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader("1. Datos Generales"),
                    const SizedBox(height: 15),

                    _buildAutocompleteInput(
                      label: "Empresa",
                      icon: Icons.business_center,
                      controller: ctrl.empresaCtrl,
                      opciones: ctrl.historialEmpresas,
                    ),

                    _buildAutocompleteInput(
                      label: "Región",
                      icon: Icons.map,
                      controller: ctrl.regionCtrl,
                      opciones: ctrl.historialRegiones,
                    ),

                    _buildAutocompleteInput(
                      label: "Oficina / Área",
                      icon: Icons.business,
                      controller: ctrl.centroCtrl,
                      opciones: ctrl.historialCentros,
                    ),

                    _buildInput(
                      ctrl.jefaturaCtrl,
                      "Jefatura a cargo",
                      Icons.person,
                    ),
                    _buildInput(
                      ctrl.origenCtrl,
                      "Origen de la visita",
                      Icons.flag,
                    ),

                    const SizedBox(height: 20),
                    const _SectionHeader("2. Fecha y Horarios"),
                    const SizedBox(height: 10),

                    // WIDGET DE FECHA EDITABLE
                    InkWell(
                      onTap: () => ctrl.pickDate(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Fecha de Visita",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              ctrl.fechaVisitaStr,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: _TimePickerCard(
                            label: "Inicio",
                            time: ctrl.horaInicioStr,
                            onTap: () => ctrl.pickTime(context, true),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _TimePickerCard(
                            label: "Término",
                            time: ctrl.horaTerminoStr,
                            onTap: () => ctrl.pickTime(context, false),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const _SectionHeader("3. Correos Informe"),
                    const SizedBox(height: 10),
                    _buildInput(
                      ctrl.email1Ctrl,
                      "Correo Empresa 1",
                      Icons.email,
                      type: TextInputType.emailAddress,
                    ),
                    _buildInput(
                      ctrl.email2Ctrl,
                      "Correo Empresa 2 (Opcional)",
                      Icons.email_outlined,
                      type: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 20),
                    const _SectionHeader("4. Actividades Realizadas"),
                    Card(
                      elevation: 2,
                      surfaceTintColor: Colors.white,
                      child: Column(
                        children: [
                          _buildCheck(
                            ctrl,
                            'reunion',
                            "Reunión",
                            ctrl.model.checkReunion,
                          ),
                          _buildCheck(
                            ctrl,
                            'senaletica',
                            "Instalación Señalética",
                            ctrl.model.checkSenaletica,
                          ),
                          _buildCheck(
                            ctrl,
                            'capacitacion',
                            "Capacitación",
                            ctrl.model.checkCapacitacion,
                          ),
                          _buildCheck(
                            ctrl,
                            'visita_sso',
                            "Visita SSO",
                            ctrl.model.checkVisitaSso,
                          ),
                          _buildCheck(
                            ctrl,
                            'charla',
                            "Charla(s)",
                            ctrl.model.checkCharla,
                          ),
                          _buildCheck(
                            ctrl,
                            'investigacion',
                            "Inv. Incidente",
                            ctrl.model.checkInvestigacion,
                          ),
                          _buildCheck(
                            ctrl,
                            'inspeccion_sso',
                            "Inspección SSO",
                            ctrl.model.checkInspeccionSso,
                          ),
                          _buildCheck(
                            ctrl,
                            'conductual',
                            "Obs. Conductual",
                            ctrl.model.checkObsConductual,
                          ),
                          _buildCheck(
                            ctrl,
                            'otro',
                            "Otro",
                            ctrl.model.checkOtro,
                          ),

                          if (ctrl.model.checkOtro)
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: TextField(
                                controller: ctrl.otroActividadCtrl,
                                decoration: const InputDecoration(
                                  labelText: "Especifique 'Otro'",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // === SECCIÓN: TIPO DE ACTIVIDAD + CHECKLIST DINÁMICO ===
                    const SizedBox(height: 20),
                    const _SectionHeader("Tipo de Actividad"),
                    const SizedBox(height: 10),
                    _buildChecklistDropdown(context, ctrl),
                    if (ctrl.isLoadingPreguntas)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (ctrl.preguntasActivas.isNotEmpty &&
                        !ctrl.isLoadingPreguntas)
                      _buildChecklistCards(context, ctrl),

                    const SizedBox(height: 20),
                    const _SectionHeader("5. Apuntes / Observaciones"),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrl.observacionesCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "Escriba aquí el desarrollo de la visita...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const _SectionHeader("6. Firma Digital"),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _showSignatureDialog(context, ctrl),
                      child: Container(
                        width: double.infinity,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade50,
                        ),
                        child: ctrl.signatureImage != null
                            ? Image.memory(ctrl.signatureImage!)
                            : const Center(
                                child: Text("Toca aquí para firmar"),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const _SectionHeader("7. Anexo Fotográfico"),
                    const SizedBox(height: 10),
                    GalleryInput(
                      images: ctrl.fotos,
                      onImagesChanged: (files) => ctrl.onFotosChanged(files),
                    ),

                    const SizedBox(height: 30),

                    // BOTÓN SECUNDARIO: PREVISUALIZAR PDF
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          side: const BorderSide(
                            color: AppTheme.primaryBlue,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => ctrl.previsualizarReporte(context),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text(
                          "PREVISUALIZAR PDF",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // BOTÓN PRIMARIO: GUARDAR REGISTRO (Intacto)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final success = await ctrl.guardarVisita();
                          if (success && context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("✅ Visita registrada con éxito"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (context.mounted &&
                              ctrl.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ctrl.errorMessage!),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text(
                          "GUARDAR REGISTRO",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  void _showSignatureDialog(BuildContext context, VisitFormController ctrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: Signature(
                  controller: ctrl.signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        ctrl.signatureController.clear();
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: "Borrar",
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final signature = await ctrl.signatureController
                            .toPngBytes();
                        if (signature != null) {
                          ctrl.signatureImage = signature;
                          ctrl.notifyListeners();
                        }
                        Navigator.pop(context);
                      },
                      child: const Text("Confirmar"),
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

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCheck(
    VisitFormController ctrl,
    String key,
    String label,
    bool value,
  ) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => ctrl.toggleCheck(key, v!),
      activeColor: AppTheme.primaryBlue,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildAutocompleteInput({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required List<String> opciones,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          // Búsqueda insensible a mayúsculas/minúsculas
          return opciones.where((String opcion) {
            return opcion.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            );
          });
        },
        onSelected: (String selection) {
          controller.text = selection;
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              // Vinculamos el controlador del Autocomplete con el nuestro para no perder el estado
              textEditingController.text = controller.text;
              textEditingController.addListener(() {
                controller.text = textEditingController.text;
              });

              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              );
            },
      ),
    );
  }

  Widget _buildChecklistDropdown(
    BuildContext context,
    VisitFormController ctrl,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String?>(
        value: ctrl.selectedTipoActividad,
        isExpanded: true,
        underline: const SizedBox(),
        hint: const Text('Registro de Visita (Sin checklist)'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Registro de Visita (Sin checklist)'),
          ),
          ...ctrl.tiposChecklistDisponibles.map((t) {
            final tipo = t['tipo_actividad'] as String;
            return DropdownMenuItem<String?>(
              value: tipo,
              child: Text(_formatTipoLabel(tipo)),
            );
          }),
        ],
        onChanged: (value) {
          if (value == null) {
            ctrl.clearChecklist();
          } else {
            ctrl.loadPreguntas(value);
          }
        },
      ),
    );
  }

  Widget _buildChecklistCards(BuildContext context, VisitFormController ctrl) {
    final grupos = ctrl.agruparPorCategoria();
    final categorias = grupos.keys.toList();

    return Column(
      children: categorias.map((catNombre) {
        final items = grupos[catNombre]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryHeader(nombre: catNombre),
            ...items.map((item) {
              final respuesta = ctrl.respuestasMap[item.id];
              return QuestionCard(
                key: ValueKey(item.id),
                item: item,
                respuestaInicial: respuesta?.estado,
                observacionInicial: respuesta?.observacion,
                criticidadInicial: respuesta?.criticidad ?? item.criticidad,
                fotoInicial: respuesta?.fotoPath != null
                    ? File(respuesta!.fotoPath!)
                    : null,
                onRespuestaChanged: (val) =>
                    ctrl.updateRespuestaData(itemId: item.id, estado: val),
                onObservacionChanged: (val) =>
                    ctrl.updateRespuestaData(itemId: item.id, observacion: val),
                onCriticidadChanged: (val) =>
                    ctrl.updateRespuestaData(itemId: item.id, criticidad: val),
                onTomarFotoTap: () {
                  ImageService.mostrarOpciones(
                    context,
                    soloUna: true,
                    onFotoTomada: (file) => ctrl.updateRespuestaData(
                      itemId: item.id,
                      fotoPath: file.path,
                    ),
                    onGaleriaSeleccionada: (files) {
                      if (files.isNotEmpty) {
                        ctrl.updateRespuestaData(
                          itemId: item.id,
                          fotoPath: files.first.path,
                        );
                      }
                    },
                  );
                },
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  String _formatTipoLabel(String tipo) {
    const labels = {'VISITA_005': 'Condiciones Eléctricas Generales'};
    return labels[tipo] ?? tipo.replaceAll('_', ' ');
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePickerCard({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              time,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
