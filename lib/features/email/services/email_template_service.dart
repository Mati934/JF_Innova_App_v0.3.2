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

  /// Construye un URI `mailto:` robusto para el fallback sin adjunto.
  ///
  /// Reglas para que Outlook/Android NO ignore los destinatarios:
  /// - Varios destinatarios van separados por COMA (estándar RFC 6068).
  /// - Se agrega `cc` con la misma lista como respaldo (algunos clientes
  ///   solo respetan uno de los dos).
  /// - Asunto y cuerpo se acotan: si la URI supera ~2000 caracteres, varios
  ///   clientes de correo la truncan o descartan los parámetros (esto causaba
  ///   que el correo se abriera SIN destinatarios).
  static Uri buildMailtoUri({
    required List<String> recipients,
    required String subject,
    required String body,
    int maxSubjectLength = 120,
    int maxBodyLength = 900,
  }) {
    final limpios = recipients
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final para = limpios.join(',');
    String acotar(String texto, int max) =>
        texto.length <= max ? texto : texto.substring(0, max);
    final subjectSafe = Uri.encodeComponent(acotar(subject, maxSubjectLength));
    final bodySafe = Uri.encodeComponent(acotar(body, maxBodyLength));
    final ccSafe = Uri.encodeComponent(para);
    return Uri.parse(
      'mailto:$para?subject=$subjectSafe&body=$bodySafe&cc=$ccSafe',
    );
  }
}
