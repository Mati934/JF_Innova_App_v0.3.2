import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
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
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: const GradientAppBar(
          title: Text("Registro de Visita (R-003)"),
        ),
        body: ctrl.isSaving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  32 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner introductorio R-003
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryBlue, Color(0xFF002244)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.handshake,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Registro de Visita',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Formulario R-003 · Completa los datos de la visita técnica.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SectionCard(
                      icon: Icons.business_center,
                      title: '1. Datos Generales',
                      child: Column(
                        children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      icon: Icons.event,
                      title: '2. Fecha y Horarios',
                      child: Column(
                        children: [
                          _DateCard(
                            label: 'Fecha de Visita',
                            value: ctrl.fechaVisitaStr,
                            onTap: () => ctrl.pickDate(context),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _TimePickerCard(
                                  label: "Inicio",
                                  time: ctrl.horaInicioStr,
                                  icon: Icons.play_circle_outline,
                                  onTap: () => ctrl.pickTime(context, true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TimePickerCard(
                                  label: "Término",
                                  time: ctrl.horaTerminoStr,
                                  icon: Icons.stop_circle_outlined,
                                  onTap: () => ctrl.pickTime(context, false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      icon: Icons.alternate_email,
                      title: '3. Correos del Informe',
                      child: Column(
                        children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      icon: Icons.checklist_rtl,
                      title: '4. Actividades Realizadas',
                      child: Column(
                        children: [
                          _ActivityCheck(
                            label: "Reunión",
                            icon: Icons.groups,
                            value: ctrl.model.checkReunion,
                            onChanged: (v) => ctrl.toggleCheck('reunion', v),
                          ),
                          _ActivityCheck(
                            label: "Instalación Señalética",
                            icon: Icons.signpost,
                            value: ctrl.model.checkSenaletica,
                            onChanged: (v) => ctrl.toggleCheck('senaletica', v),
                          ),
                          _ActivityCheck(
                            label: "Capacitación",
                            icon: Icons.school,
                            value: ctrl.model.checkCapacitacion,
                            onChanged: (v) => ctrl.toggleCheck('capacitacion', v),
                          ),
                          _ActivityCheck(
                            label: "Visita SSO",
                            icon: Icons.health_and_safety,
                            value: ctrl.model.checkVisitaSso,
                            onChanged: (v) => ctrl.toggleCheck('visita_sso', v),
                          ),
                          _ActivityCheck(
                            label: "Charla(s)",
                            icon: Icons.record_voice_over,
                            value: ctrl.model.checkCharla,
                            onChanged: (v) => ctrl.toggleCheck('charla', v),
                          ),
                          _ActivityCheck(
                            label: "Inv. Incidente",
                            icon: Icons.report_problem,
                            value: ctrl.model.checkInvestigacion,
                            onChanged: (v) =>
                                ctrl.toggleCheck('investigacion', v),
                          ),
                          _ActivityCheck(
                            label: "Inspección SSO",
                            icon: Icons.fact_check,
                            value: ctrl.model.checkInspeccionSso,
                            onChanged: (v) =>
                                ctrl.toggleCheck('inspeccion_sso', v),
                          ),
                          _ActivityCheck(
                            label: "Obs. Conductual",
                            icon: Icons.psychology,
                            value: ctrl.model.checkObsConductual,
                            onChanged: (v) => ctrl.toggleCheck('conductual', v),
                          ),
                          _ActivityCheck(
                            label: "Otro",
                            icon: Icons.more_horiz,
                            value: ctrl.model.checkOtro,
                            onChanged: (v) => ctrl.toggleCheck('otro', v),
                          ),
                          if (ctrl.model.checkOtro)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: TextField(
                                controller: ctrl.otroActividadCtrl,
                                decoration: InputDecoration(
                                  labelText: "Especifique 'Otro'",
                                  prefixIcon: const Icon(
                                    Icons.edit_note,
                                    color: Colors.grey,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      icon: Icons.assignment_outlined,
                      title: 'Tipo de Actividad',
                      child: Column(
                        children: [
                          _buildChecklistDropdown(context, ctrl),
                          if (ctrl.isLoadingPreguntas)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          if (ctrl.preguntasActivas.isNotEmpty &&
                              !ctrl.isLoadingPreguntas)
                            _buildChecklistCards(context, ctrl),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      icon: Icons.notes,
                      title: '5. Apuntes / Observaciones',
                      child: TextField(
                        controller: ctrl.observacionesCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText:
                              "Escriba aquí el desarrollo de la visita...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      icon: Icons.draw,
                      title: '6. Firma Digital',
                      child: GestureDetector(
                        onTap: () => _showSignatureDialog(context, ctrl),
                        child: Container(
                          width: double.infinity,
                          height: 110,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: ctrl.signatureImage != null
                                  ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                                  : Colors.grey.shade300,
                              width: ctrl.signatureImage != null ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: ctrl.signatureImage != null
                                ? Colors.white
                                : Colors.grey.shade50,
                          ),
                          child: ctrl.signatureImage != null
                              ? Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Image.memory(ctrl.signatureImage!),
                                )
                              : Center(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Toca aquí para firmar",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      icon: Icons.photo_library,
                      title: '7. Anexo Fotográfico',
                      child: GalleryInput(
                        images: ctrl.fotos,
                        onImagesChanged: (files) => ctrl.onFotosChanged(files),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                            color: AppTheme.primaryBlue,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => ctrl.previsualizarReporte(context),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text(
                          "PREVISUALIZAR PDF",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryBlue, Color(0xFF002244)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            final success = await ctrl.guardarVisita();
                            if (success && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("✅ Visita registrada con éxito"),
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
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                  "GUARDAR REGISTRO",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppTheme.primaryBlue,
              width: 1.6,
            ),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteInput({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required List<String> opciones,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
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
              textEditingController.text = controller.text;
              textEditingController.addListener(() {
                controller.text = textEditingController.text;
              });

              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(
                    icon,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 1.6,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
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
    final selected = ctrl.selectedTipoActividad;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected != null
              ? AppTheme.primaryBlue.withValues(alpha: 0.35)
              : Colors.grey.shade300,
          width: selected != null ? 1.5 : 1,
        ),
        boxShadow: selected != null
            ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.primaryBlue,
          ),
          hint: Text(
            'Registro de Visita (Sin checklist)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          borderRadius: BorderRadius.circular(12),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.list_alt, size: 18, color: Colors.grey),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Registro de Visita (Sin checklist)'),
                  ),
                ],
              ),
            ),
            ...ctrl.tiposChecklistDisponibles.map((t) {
              final tipo = t['tipo_actividad'] as String;
              return DropdownMenuItem<String?>(
                value: tipo,
                child: Row(
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      size: 18,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_formatTipoLabel(tipo))),
                  ],
                ),
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
    const labels = {
      // R005 - Condiciones Eléctricas
      'VISITA_005': 'Insp. Condiciones Eléctricas',
      'VISITA_R005': 'Insp. Condiciones Eléctricas',
      'ELECTRICIDAD_R005': 'Insp. Condiciones Eléctricas',
      // R006 - Pisos y Superficies
      'VISITA_006': 'Insp. Pisos y Superficies',
      'VISITA_R006': 'Insp. Pisos y Superficies',
      'PISOS_R006': 'Insp. Pisos y Superficies',
    };
    return labels[tipo] ?? tipo.replaceAll('_', ' ');
  }
}

/// Tarjeta blanca que agrupa una sección del formulario con header (icono + título).
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.06),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_calendar,
                size: 18,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCheck extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ActivityCheck({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: value
                    ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                    : Colors.grey.shade200,
                width: value ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: value ? AppTheme.primaryBlue : Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                      color: value
                          ? AppTheme.primaryBlue
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? AppTheme.primaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: value
                          ? AppTheme.primaryBlue
                          : Colors.grey.shade400,
                      width: 1.6,
                    ),
                  ),
                  child: value
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  const _TimePickerCard({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
