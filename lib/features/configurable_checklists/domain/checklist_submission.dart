import 'models/configurable_checklist.dart';

List<String> missingRequiredChecklistFields(
  Iterable<ChecklistCampoDefinicion> fields,
  Map<String, String> values,
) {
  return fields
      .where(
        (field) =>
            field.requerido && (values[field.clave] ?? '').trim().isEmpty,
      )
      .map((field) => field.etiqueta)
      .toList(growable: false);
}

List<String> missingChecklistResponses(
  Iterable<Map<String, dynamic>> items,
  Map<String, String?> responses,
) {
  return items
      .map((item) => item['id']?.toString() ?? '')
      .where((itemId) => itemId.isNotEmpty)
      .where((itemId) => !{'C', 'NC', 'N/A'}.contains(responses[itemId]))
      .toList(growable: false);
}
