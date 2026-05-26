import 'package:flutter/material.dart';

/// Configuración del "módulo Hidroser".
///
/// Hidroser no es un módulo de datos separado: por debajo reusa el módulo
/// "Registro de Visita" (visitas_tecnicas_pendientes, controller, PDF, etc.).
/// Lo único propio es:
///   1. Un tile distinto en el Home (color/icono).
///   2. Un subconjunto de `tipo_actividad` (los checklists Hidroser).
///   3. AppBar/banner del formulario coloreado con el color Hidroser.
///
/// Cuando agreguemos un nuevo checklist Hidroser basta con sumar su código
/// `VISITA_R0XX` a [kHidroserChecklistTypes] y crear el seed SQL respectivo.
const Color kHidroserColor = Color(0xFF0277BD);
const Color kHidroserColorDark = Color(0xFF01579B);

const List<String> kHidroserChecklistTypes = <String>[
  'VISITA_R012', // Listado Verificación Grúas Horquillas
];

bool isHidroserChecklist(String? tipoActividad) =>
    tipoActividad != null && kHidroserChecklistTypes.contains(tipoActividad);
