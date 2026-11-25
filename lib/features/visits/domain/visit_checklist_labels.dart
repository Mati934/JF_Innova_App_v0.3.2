const Map<String, String> visitChecklistLabels = {
  'VISITA_R004': 'Inspección Extintores',
  'VISITA_005': 'Insp. Condiciones Eléctricas',
  'VISITA_R005': 'Insp. Condiciones Eléctricas',
  'ELECTRICIDAD_R005': 'Insp. Condiciones Eléctricas',
  'VISITA_006': 'Insp. Pisos y Superficies',
  'VISITA_R006': 'Insp. Pisos y Superficies',
  'PISOS_R006': 'Insp. Pisos y Superficies',
  'VISITA_R008': 'Chequeo Vehículos Livianos',
  'VEHICULOS_R008': 'Chequeo Vehículos Livianos',
  'VISITA_R011': 'Chequeo Máquina Soldadora',
  'SOLDADORA_R011': 'Chequeo Máquina Soldadora',
  'VISITA_R012': 'Verificación Grúas Horquillas',
  'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES': 'Chequeo de Herramientas Manuales',
  'VISITA_CHEQUEO_SOLDADORA_AL_ARCO': 'Chequeo de Soldadora al Arco',
  'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR': 'Chequeo de Taladro Destornillador',
  'VISITA_CHEQUEO_ESMERIL_ANGULAR': 'Chequeo de Esmeril Angular',
  'VISITA_CHEQUEO_EXTENSION_ELECTRICA': 'Chequeo de Extensión Eléctrica',
  'VISITA_R013': 'Chequeo de Herramientas Manuales',
  'VISITA_R014': 'Chequeo de Soldadora al Arco',
  'VISITA_R015': 'Chequeo de Taladro Destornillador',
  'VISITA_R016': 'Chequeo de Esmeril Angular',
  'VISITA_R017': 'Chequeo de Extensión Eléctrica',
};

String visitChecklistLabel(String? tipo) {
  if (tipo == null || tipo.isEmpty) return '';
  return visitChecklistLabels[tipo] ?? tipo.replaceAll('_', ' ');
}
