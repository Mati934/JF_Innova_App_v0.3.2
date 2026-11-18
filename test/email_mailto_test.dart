// Tests de la construcción del mailto de respaldo (fallback sin adjunto).
//
// Bug real (reportado 2026-08-21): al redirigir a Outlook el correo se abría
// SIN destinatarios. Causas posibles que estos tests blindan:
//  - URI demasiado larga (Outlook/Android trunca o descarta parámetros).
//  - Separador de destinatarios no estándar.
//  - Falta de respaldo en cc.

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/email/services/email_template_service.dart';

void main() {
  group('EmailTemplateService.buildMailtoUri', () {
    test('incluye destinatarios en el path (to)', () {
      final uri = EmailTemplateService.buildMailtoUri(
        recipients: const ['a@x.cl', 'b@x.cl'],
        subject: 'Hola',
        body: 'Cuerpo',
      );
      expect(uri.toString(), startsWith('mailto:a@x.cl,b@x.cl?'));
    });

    test('varios destinatarios separados por coma (estándar RFC 6068)', () {
      final uri = EmailTemplateService.buildMailtoUri(
        recipients: const ['a@x.cl', 'b@x.cl', 'c@x.cl'],
        subject: 's',
        body: 'b',
      );
      expect(uri.toString(), contains('a@x.cl,b@x.cl,c@x.cl'));
    });

    test('incluye cc como respaldo con la misma lista', () {
      final uri = EmailTemplateService.buildMailtoUri(
        recipients: const ['a@x.cl', 'b@x.cl'],
        subject: 's',
        body: 'b',
      );
      // encodeComponent codifica '@' -> '%40' y ',' -> '%2C'.
      expect(uri.toString(), contains('cc=a%40x.cl%2Cb%40x.cl'));
      // Y decodificado, el cc debe ser la lista separada por coma.
      final cc = uri.queryParameters['cc'];
      expect(cc, 'a@x.cl,b@x.cl');
    });

    test('acota asunto y cuerpo largos para no romper la URI', () {
      final subjectLargo = 'S' * 500;
      final bodyLargo = 'B' * 5000;
      final uri = EmailTemplateService.buildMailtoUri(
        recipients: const ['a@x.cl'],
        subject: subjectLargo,
        body: bodyLargo,
      );
      final s = uri.toString();
      // subject acotado a 120 -> no debe contener las 500 S.
      expect(s.contains(subjectLargo), isFalse);
      // La URI completa debe mantenerse en un largo razonable.
      expect(s.length, lessThan(2200));
    });

    test('ignora destinatarios vacíos o con espacios', () {
      final uri = EmailTemplateService.buildMailtoUri(
        recipients: const ['  a@x.cl ', '', '   ', 'b@x.cl'],
        subject: 's',
        body: 'b',
      );
      expect(uri.toString(), startsWith('mailto:a@x.cl,b@x.cl?'));
    });

    test('escapa caracteres especiales del asunto y cuerpo', () {
      final uri = EmailTemplateService.buildMailtoUri(
        recipients: const ['a@x.cl'],
        subject: 'Inspección & observación ¿ok?',
        body: 'Línea 1\nLínea 2 = fin',
      );
      final s = uri.toString();
      // No debe romper el query string con & o = sin escapar en subject/body.
      expect(s.contains('subject=Inspecci'), isTrue);
      expect(s.contains('&body='), isTrue);
    });
  });
}
