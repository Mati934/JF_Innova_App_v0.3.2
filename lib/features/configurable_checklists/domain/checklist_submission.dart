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
