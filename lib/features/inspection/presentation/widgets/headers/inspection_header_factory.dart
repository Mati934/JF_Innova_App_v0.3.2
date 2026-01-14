import 'package:flutter/material.dart';
import '../../controllers/inspection_form_controller.dart';
import 'buceo_header_widget.dart'; // Asegúrate que importe el archivo donde pusimos las dos clases

class InspectionHeaderFactory {
  static Widget create(
    String tipoActividad,
    InspectionFormController controller,
  ) {
    switch (tipoActividad) {
      case 'INSPECCION_BUCEO':
        // AHORA SOLO DEVUELVE LA CUADRILLA
        return BuceoCuadrillaWidget(controller: controller);
      default:
        return const SizedBox.shrink();
    }
  }
}
