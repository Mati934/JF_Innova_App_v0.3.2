import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/email/services/email_template_service.dart';

void main() {
  group('EmailTemplateService', () {
    test('renderiza variables y agrega observaciones adicionales', () {
      const template = '''
Estimado(a):
Se adjunta el registro realizado el día {{fecha_inspeccion}}.
Realizado por: {{supervisor_nombre}}
''';

      final rendered = EmailTemplateService.renderTemplate(template, {
        'fecha_inspeccion': '2026-07-29',
        'supervisor_nombre': 'Juan Pérez',
      });

      expect(rendered, contains('2026-07-29'));
      expect(rendered, contains('Juan Pérez'));
      expect(rendered, isNot(contains('{{')));
    });

    test('agrega observaciones adicionales al cuerpo', () {
      final body = EmailTemplateService.composeBody(
        'Hola',
        'Revisar antes de cerrar',
      );

      expect(body, contains('Revisar antes de cerrar'));
      expect(body, contains('Observaciones adicionales'));
    });
  });
}
