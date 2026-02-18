import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/inspection_setup_controller.dart';
import 'inspection_form_screen.dart';
// Asegúrate de que esta ruta sea la correcta hacia tu archivo shared
import '../../../../../shared/widgets/custom_dropdown.dart';

class InspectionSetupScreen extends StatelessWidget {
  const InspectionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InspectionSetupController(),
      child: const _InspectionSetupView(),
    );
  }
}

class _InspectionSetupView extends StatelessWidget {
  const _InspectionSetupView();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<InspectionSetupController>(context);

    // Listener para errores
    if (controller.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Faena'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      '📍 Ubicación y Estado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // --- ÁREA (Con lógica de ID a Nombre) ---
                    CustomDropdown(
                      label: 'Área / Región',
                      // 1. Convertimos la lista de Mapas a lista de Nombres (Strings)
                      items: controller.areas
                          .map((x) => x['nombre'].toString())
                          .toList(),
                      // 2. Buscamos el nombre correspondiente al ID actual
                      value: controller.areaId != null
                          ? controller.areas.firstWhere(
                              (element) => element['id'] == controller.areaId,
                              orElse: () => {'nombre': null},
                            )['nombre']
                          : null,
                      // 3. Al seleccionar nombre, buscamos su ID y lo seteamos
                      onChanged: (val) {
                        if (val != null) {
                          final selected = controller.areas.firstWhere(
                            (element) => element['nombre'] == val,
                          );
                          controller.setArea(selected['id']);
                        }
                      },
                      enableSearch: false,
                    ),

                    // --- CENTRO (Con lógica de ID a Nombre) ---
                    CustomDropdown(
                      label: 'Centro de Trabajo',
                      items: controller.centros
                          .map((x) => x['nombre'].toString())
                          .toList(),
                      value: controller.centroId != null
                          ? controller.centros.firstWhere(
                              (element) => element['id'] == controller.centroId,
                              orElse: () => {'nombre': null},
                            )['nombre']
                          : null,
                      onChanged: (val) {
                        if (val != null) {
                          final selected = controller.centros.firstWhere(
                            (element) => element['nombre'] == val,
                          );
                          controller.setCentro(selected['id']);
                        }
                      },
                    ),

                    // --- ESTADO PUERTO (Lista simple de Strings) ---
                    CustomDropdown(
                      label: 'Condición de Puerto',
                      items: controller.estadosPuerto,
                      value: controller.estadoPuerto,
                      onChanged: (val) => controller.setEstadoPuerto(val),
                      enableSearch: false,
                    ),

                    // --- BLOQUE PUERTO CERRADO ---
                    if (controller.estadoPuerto == 'CERRADO') ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '⚠️ Puerto Cerrado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                            const SizedBox(height: 10),
                            CustomDropdown(
                              label: 'Actividad Realizada',
                              items: controller.opcionesPuertoCerrado,
                              value: controller.actividadPuertoCerrado,
                              onChanged: (val) =>
                                  controller.setActividadPuertoCerrado(val),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // --- SECCIÓN TÉCNICA ---
                    if (controller.estadoPuerto == 'ABIERTO' ||
                        (controller.estadoPuerto == 'CERRADO' &&
                            controller.actividadPuertoCerrado ==
                                'PRE_INSPECCION')) ...[
                      const SizedBox(height: 30),
                      const Divider(),
                      const Text(
                        '📋 Datos del Reporte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // RADIO BUTTONS (Sin cambios, se ven bien nativos)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Tipo de Informe:",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () =>
                                        controller.setEsConsecutiva(false),
                                    child: Row(
                                      children: [
                                        Radio<bool>(
                                          value: false,
                                          groupValue: controller.esConsecutiva,
                                          onChanged: (val) =>
                                              controller.setEsConsecutiva(val!),
                                          activeColor: const Color(0xFF003366),
                                        ),
                                        const Text("INICIAL"),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  InkWell(
                                    onTap: () =>
                                        controller.setEsConsecutiva(true),
                                    child: Row(
                                      children: [
                                        Radio<bool>(
                                          value: true,
                                          groupValue: controller.esConsecutiva,
                                          onChanged: (val) =>
                                              controller.setEsConsecutiva(val!),
                                          activeColor: const Color(0xFF003366),
                                        ),
                                        const Text("CONSECUTIVA"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // N° INFORME (Solo lectura)
                      TextFormField(
                        controller: controller.numeroInformeController,
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'N° de Informe',
                          hintText: 'Automático al sincronizar',
                          prefixIcon: Icon(Icons.confirmation_number),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Color(0xFFF0F0F0),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // --- TIPO INSPECCIÓN ---
                      CustomDropdown(
                        label: 'Tipo de Inspección',
                        items: controller.tiposInspeccion,
                        value: controller.tipoActividad,
                        onChanged: (val) => controller.setTipoActividad(val),
                        enableSearch: false,
                      ),

                      if (controller.tipoActividad != null) ...[
                        // --- CONTRATISTA / NAVIERA ---
                        CustomDropdown(
                          label: controller.tipoActividad == 'INSPECCION_BUCEO'
                              ? 'Empresa de Buceo'
                              : 'Naviera',
                          items: controller.contratistas
                              .map((x) => x['nombre'].toString())
                              .toList(),
                          value: controller.contratistaId != null
                              ? controller.contratistas.firstWhere(
                                  (e) => e['id'] == controller.contratistaId,
                                  orElse: () => {'nombre': null},
                                )['nombre']
                              : null,
                          onChanged: (val) {
                            if (val != null) {
                              final selected = controller.contratistas
                                  .firstWhere((e) => e['nombre'] == val);
                              controller.setContratista(selected['id']);
                            }
                          },
                        ),

                        // --- EMBARCACIÓN ---
                        CustomDropdown(
                          label: 'Embarcación',
                          items: controller.embarcaciones
                              .map((x) => x['nombre'].toString())
                              .toList(),
                          value: controller.embarcacionId != null
                              ? controller.embarcaciones.firstWhere(
                                  (e) => e['id'] == controller.embarcacionId,
                                  orElse: () => {'nombre': null},
                                )['nombre']
                              : null,
                          onChanged: (val) {
                            if (val != null) {
                              final selected = controller.embarcaciones
                                  .firstWhere((e) => e['nombre'] == val);
                              controller.setEmbarcacion(selected['id']);
                            }
                          },
                          // Opcional: Aquí podrías activar el "onAddNew" si quisieras crear barcos
                        ),
                      ],
                    ],

                    const SizedBox(height: 40),

                    // BOTÓN GUARDAR (Sin cambios)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            controller.isSaving ||
                                !controller.validarFormulario()
                            ? null
                            : () async {
                                final success = await controller
                                    .guardarActividad();
                                if (success && context.mounted) {
                                  if (controller.esInspeccionCompleta) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InspectionFormScreen(
                                          activityId:
                                              controller.createdActivityId!,
                                          tipoActividad:
                                              controller.finalActivityType!,
                                          nombreCentro:
                                              controller.finalCentroNombre,
                                          numeroInformeInicial: controller
                                              .numeroInformeController
                                              .text,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Bitácora guardada.'),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: controller.isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          controller.isSaving ? 'GUARDANDO...' : 'COMENZAR',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}
