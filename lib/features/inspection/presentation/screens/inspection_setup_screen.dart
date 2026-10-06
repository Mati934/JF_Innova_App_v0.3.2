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
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Configuración de Faena'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    // Banner azul superior
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF003366), Color(0xFF002244)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF003366,
                            ).withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Antes de comenzar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Completa la información de la faena',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Sección 1: Ubicación y Estado ──
                    _SetupSection(
                      icon: Icons.place_outlined,
                      title: 'Ubicación y Estado',
                      children: [
                        CustomDropdown(
                          label: 'Área / Región',
                          items: controller.areas
                              .map((x) => x['nombre'].toString())
                              .toList(),
                          value: controller.areaId != null
                              ? controller.areas.firstWhere(
                                  (element) =>
                                      element['id'] == controller.areaId,
                                  orElse: () => {'nombre': null},
                                )['nombre']
                              : null,
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
                        CustomDropdown(
                          label: 'Centro de Trabajo',
                          items: controller.centros
                              .map((x) => x['nombre'].toString())
                              .toList(),
                          value: controller.centroId != null
                              ? controller.centros.firstWhere(
                                  (element) =>
                                      element['id'] == controller.centroId,
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
                        CustomDropdown(
                          label: 'Condición de Puerto',
                          items: controller.estadosPuerto,
                          value: controller.estadoPuerto,
                          onChanged: (val) => controller.setEstadoPuerto(val),
                          enableSearch: false,
                        ),
                        if (controller.estadoPuerto == 'CERRADO') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 18,
                                      color: Colors.deepOrange,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Puerto Cerrado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ],
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
                      ],
                    ),

                    // ── Sección 2: Datos del Reporte ──
                    if (controller.estadoPuerto == 'ABIERTO' ||
                        (controller.estadoPuerto == 'CERRADO' &&
                            controller.actividadPuertoCerrado ==
                                'PRE_INSPECCION')) ...[
                      _SetupSection(
                        icon: Icons.description_outlined,
                        title: 'Datos del Reporte',
                        children: [
                          _SegmentedSelector(
                            label: 'Tipo de Informe',
                            value: controller.esConsecutiva,
                            opciones: const [
                              MapEntry(false, 'INICIAL'),
                              MapEntry(true, 'CONSECUTIVA'),
                            ],
                            onChanged: (v) => controller.setEsConsecutiva(v),
                          ),
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 12),
                          CustomDropdown(
                            label: 'Tipo de Inspección',
                            items: controller.tiposInspeccion,
                            value: controller.tipoActividad,
                            onChanged: (val) =>
                                controller.setTipoActividad(val),
                            enableSearch: false,
                          ),
                          if (controller.tipoActividad != null) ...[
                            CustomDropdown(
                              label:
                                  controller.tipoActividad == 'INSPECCION_BUCEO'
                                  ? 'Empresa de Buceo'
                                  : 'Naviera',
                              items: controller.contratistas
                                  .map((x) => x['nombre'].toString())
                                  .toList(),
                              value: controller.contratistaId != null
                                  ? controller.contratistas.firstWhere(
                                      (e) =>
                                          e['id'] == controller.contratistaId,
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
                            CustomDropdown(
                              label: 'Embarcación',
                              items: controller.embarcaciones
                                  .map((x) => x['nombre'].toString())
                                  .toList(),
                              value: controller.embarcacionId != null
                                  ? controller.embarcaciones.firstWhere(
                                      (e) =>
                                          e['id'] == controller.embarcacionId,
                                      orElse: () => {'nombre': null},
                                    )['nombre']
                                  : null,
                              onChanged: (val) {
                                if (val != null) {
                                  final selected = controller.embarcaciones
                                      .firstWhere((e) => e['nombre'] == val);
                                  controller.setEmbarcacion(
                                    selected['id']?.toString(),
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // BOTÓN COMENZAR
                    SizedBox(
                      width: double.infinity,
                      height: 54,
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
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: const Color(
                            0xFF003366,
                          ).withValues(alpha: 0.4),
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
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          controller.isSaving ? 'GUARDANDO...' : 'COMENZAR',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
}

/// Sección visual con header (icono + título) y children apilados.
class _SetupSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SetupSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF003366).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF003366)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Selector segmentado tipo "pill" para elegir entre 2 opciones.
class _SegmentedSelector<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<MapEntry<T, String>> opciones;
  final ValueChanged<T> onChanged;

  const _SegmentedSelector({
    required this.label,
    required this.value,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: opciones.map((entry) {
              final selected = entry.key == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF003366)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
