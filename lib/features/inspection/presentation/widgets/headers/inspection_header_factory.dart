import 'package:flutter/material.dart';
import '../../controllers/inspection_form_controller.dart';
import 'buceo_header_widget.dart'; // Asegúrate que aquí estén tus widgets

class InspectionHeaderFactory {
  static Widget create(
    String tipoActividad,
    InspectionFormController controller,
  ) {
    switch (tipoActividad) {
      case 'INSPECCION_BUCEO':
        // AHORA DEVOLVEMOS LOS DOS BLOQUES JUNTOS AL INICIO
        return Column(
          children: [
            BuceoCuadrillaWidget(controller: controller),
            BuceoTecnicoWidget(controller: controller), // <--- Lo movimos aquí
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
