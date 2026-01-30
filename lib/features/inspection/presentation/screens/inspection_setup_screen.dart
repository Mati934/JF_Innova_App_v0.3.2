import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/inspection_setup_controller.dart';
import 'inspection_form_screen.dart';

class InspectionSetupScreen extends StatelessWidget {
  const InspectionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos ChangeNotifierProvider para conectar la UI con el Controller
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

    // Listener para errores o navegación
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

                    // AREA
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Área / Región',
                        border: OutlineInputBorder(),
                      ),
                      value: controller.areaId,
                      items: controller.areas.map((x) {
                        return DropdownMenuItem(
                          value: x['id'] as String,
                          child: Text(x['nombre']),
                        );
                      }).toList(),
                      onChanged: controller.setArea,
                    ),
                    const SizedBox(height: 15),

                    // CENTRO
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Centro de Trabajo',
                        border: OutlineInputBorder(),
                      ),
                      value: controller.centroId,
                      items: controller.centros.map((x) {
                        return DropdownMenuItem(
                          value: x['id'] as String,
                          child: Text(x['nombre']),
                        );
                      }).toList(),
                      onChanged: controller.setCentro,
                    ),
                    const SizedBox(height: 15),

                    // ESTADO PUERTO
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Condición de Puerto',
                        border: const OutlineInputBorder(),
                        fillColor: controller.estadoPuerto == 'CERRADO'
                            ? Colors.red.shade50
                            : null,
                        filled: controller.estadoPuerto == 'CERRADO',
                      ),
                      value: controller.estadoPuerto,
                      items: controller.estadosPuerto.map((x) {
                        return DropdownMenuItem(value: x, child: Text(x));
                      }).toList(),
                      onChanged: controller.setEstadoPuerto,
                    ),

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
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Actividad Realizada',
                                border: OutlineInputBorder(),
                              ),
                              value: controller.actividadPuertoCerrado,
                              items: controller.opcionesPuertoCerrado.map((x) {
                                return DropdownMenuItem(
                                  value: x,
                                  child: Text(x.replaceAll('_', ' ')),
                                );
                              }).toList(),
                              onChanged: controller.setActividadPuertoCerrado,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // --- SECCIÓN TÉCNICA ---
                    // Se muestra si es ABIERTO o PRE_INSPECCION
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

                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5),
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
                            // Usamos un Row directo para tener control total del espacio
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  // --- OPCIÓN: INICIAL ---
                                  InkWell(
                                    onTap: () =>
                                        controller.setEsConsecutiva(false),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize
                                          .min, // Ocupa solo el espacio necesario
                                      children: [
                                        Radio<bool>(
                                          value: false,
                                          groupValue: controller.esConsecutiva,
                                          onChanged: (val) =>
                                              controller.setEsConsecutiva(val!),
                                          activeColor: const Color(0xFF003366),
                                          visualDensity: VisualDensity
                                              .compact, // Reduce el tamaño visual
                                          materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap, // Reduce área muerta
                                        ),
                                        const SizedBox(
                                          width: 4,
                                        ), // Pequeña separación
                                        const Text(
                                          "INICIAL",
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ), // Padding derecho para el área táctil
                                      ],
                                    ),
                                  ),

                                  const Spacer(), // Empuja la siguiente opción o usa SizedBox(width: 20)
                                  // --- OPCIÓN: CONSECUTIVA ---
                                  InkWell(
                                    onTap: () =>
                                        controller.setEsConsecutiva(true),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<bool>(
                                          value: true,
                                          groupValue: controller.esConsecutiva,
                                          onChanged: (val) =>
                                              controller.setEsConsecutiva(val!),
                                          activeColor: const Color(0xFF003366),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          "CONSECUTIVA",
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),

                      // -----------------------------------------------------------
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: controller.numeroInformeController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'N° de Informe',
                          hintText: 'Ej: 01',
                          prefixIcon: Icon(Icons.confirmation_number),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Inspección',
                          border: OutlineInputBorder(),
                        ),
                        value: controller.tipoActividad,
                        items: controller.tiposInspeccion.map((x) {
                          return DropdownMenuItem(value: x, child: Text(x));
                        }).toList(),
                        onChanged: controller.setTipoActividad,
                      ),
                      const SizedBox(height: 15),

                      if (controller.tipoActividad != null) ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                controller.tipoActividad == 'INSPECCION_BUCEO'
                                ? 'Empresa de Buceo'
                                : 'Naviera',
                            border: const OutlineInputBorder(),
                          ),
                          value: controller.contratistaId,
                          items: controller.contratistas.map((x) {
                            return DropdownMenuItem(
                              value: x['id'] as String,
                              child: Text(x['nombre']),
                            );
                          }).toList(),
                          onChanged: controller.setContratista,
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Embarcación',
                            border: OutlineInputBorder(),
                          ),
                          value: controller.embarcacionId,
                          items: controller.embarcaciones.map((x) {
                            return DropdownMenuItem(
                              value: x['id'] as String,
                              child: Text(x['nombre']),
                            );
                          }).toList(),
                          onChanged: controller.setEmbarcacion,
                        ),
                      ],
                    ],

                    const SizedBox(height: 40),

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
