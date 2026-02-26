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

// NUEVO WIDGET ESPECÍFICO PARA EMBARCACIONES
class EmbarcacionTecnicoWidget extends StatelessWidget {
  final InspectionFormController controller;

  const EmbarcacionTecnicoWidget({Key? key, required this.controller})
    : super(key: key);

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
            TextFormField(
              controller: controller.correoEmpresaServiciosCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo Empresa de Servicios (Para envío de PDF)',
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
