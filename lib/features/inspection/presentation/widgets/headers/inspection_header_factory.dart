import 'package:flutter/material.dart';
import '../../controllers/inspection_form_controller.dart';
import 'buceo_header_widget.dart';

class InspectionHeaderFactory {
  static Widget create(
    String tipoActividad,
    InspectionFormController controller,
  ) {
    switch (tipoActividad) {
      case 'INSPECCION_BUCEO':
        return Column(
          children: [
            BuceoCuadrillaWidget(controller: controller),
            BuceoTecnicoWidget(controller: controller),
          ],
        );
      case 'INSPECCION_EMBARCACION':
        return Column(
          children: [
            // DRY: Reusamos la cuadrilla. El usuario ingresará 'Patrón' o 'Maquinista' en el campo de cargo.
            BuceoCuadrillaWidget(controller: controller),
            EmbarcacionTecnicoWidget(controller: controller),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class EmbarcacionTecnicoWidget extends StatelessWidget {
  final InspectionFormController controller;

  const EmbarcacionTecnicoWidget({super.key, required this.controller});

  // Helper local para llamar al TimePicker
  Future<void> _seleccionarHora(BuildContext context, bool isInicio) async {
    final initial = controller.getHoraInicialReloj(isInicio);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.actualizarHora(isInicio, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Datos de la Embarcación",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const Divider(),
            const SizedBox(height: 10),

            // 🟢 NUEVO: SELECTOR DE HORARIOS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.blueGrey),
                  const SizedBox(width: 10),
                  const Text(
                    "Horario de Auditoría:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _seleccionarHora(context, true),
                    child: Text(
                      controller.horaInicioController.text.isEmpty
                          ? "--:--"
                          : controller.horaInicioController.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      " - ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () => _seleccionarHora(context, false),
                    child: Text(
                      controller.horaTerminoController.text.isEmpty
                          ? "--:--"
                          : controller.horaTerminoController.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // CAMPO DE CORREO
            TextFormField(
              controller: controller.correoEmpresaServiciosCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo Empresa de Servicios',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => controller.guardarBorrador(silent: true),
            ),
          ],
        ),
      ),
    );
  }
}
