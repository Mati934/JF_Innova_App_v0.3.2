import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart'; // 👈 IMPORTANTE: Agregada la importación
import '../../../../core/theme/app_theme.dart';
import '../controllers/visit_form_controller.dart';

class VisitFormScreen extends StatelessWidget {
  const VisitFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VisitFormController(),
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

    return Scaffold(
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
                  const _SectionHeader("2. Horarios"),
                  const SizedBox(height: 10),
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
                        _buildCheck(ctrl, 'otro', "Otro", ctrl.model.checkOtro),

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

                  // 👇 AQUI ESTÁ EL CAMBIO PRINCIPAL: SECCIÓN 6 👇
                  const _SectionHeader("6. Anexo Fotográfico"),
                  const SizedBox(height: 10),
                  GalleryInput(
                    images: ctrl
                        .fotos, // Pasa la lista de Files desde el Controller
                    onImagesChanged: (files) =>
                        ctrl.onFotosChanged(files), // Actualiza el Controller
                  ),

                  // 👆 FIN DEL CAMBIO 👆
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

                  // BOTÓN PRIMARIO: GUARDAR REGISTRO
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
