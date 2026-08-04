class EmailTemplateService {
  static String renderTemplate(String template, Map<String, String> values) {
    var rendered = template;
    for (final entry in values.entries) {
      rendered = rendered.replaceAll('{{${entry.key}}}', entry.value);
    }
    return rendered.replaceAll(RegExp(r'\{\{[^}]+\}\}'), '');
  }

  static String composeBody(String baseBody, String? additionalComments) {
    if ((additionalComments ?? '').trim().isEmpty) {
      return baseBody.trim();
    }

    return '''$baseBody

Observaciones adicionales:
$additionalComments''';
  }
}
