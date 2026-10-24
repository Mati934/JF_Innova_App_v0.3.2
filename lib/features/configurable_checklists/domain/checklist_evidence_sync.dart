import 'dart:convert';

Map<String, dynamic> buildChecklistEvidencePayload({
  required Map<String, dynamic> evidence,
  required Map<String, String> responseIdsByItemKey,
  required String storagePath,
}) {
  final type = evidence['tipo'];
  if (type != 'GENERAL' && type != 'RESPUESTA') {
    throw StateError('CHECKLIST_EVIDENCIA_TIPO_INVALIDO');
  }
  String? responseId;
  if (type == 'RESPUESTA') {
    final itemKey = evidence['respuesta_id']?.toString();
    responseId = responseIdsByItemKey[itemKey];
    if (responseId == null) {
      throw StateError('CHECKLIST_EVIDENCIA_RESPUESTA_REQUERIDA: $itemKey');
    }
  }
  final metadata = evidence['metadata'];
  return {
    'id': evidence['id'],
    'inspeccion_id': evidence['inspeccion_id'],
    'respuesta_id': responseId,
    'tipo': type,
    'storage_path': storagePath,
    'orden': evidence['orden'],
    'metadata': metadata is String ? jsonDecode(metadata) : metadata ?? {},
  };
}
