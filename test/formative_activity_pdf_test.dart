import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/formative_activities/services/formative_activity_pdf_service.dart';

import 'helpers/pdf_test_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = FormativeActivityPdfService();
  final data = <String, dynamic>{
    'empresa_nombre': 'Empresa de prueba',
    'numero_reporte': '123',
    'fecha_realizacion': '2026-10-21',
    'hora_inicio': '09:00',
    'hora_termino': '09:30',
    'hh_con_relator': 2.5,
    'actividad_formativa_tipo': 'CHARLA',
    'relator_nombre': 'Relator de prueba',
    'asistentes': 4,
    'descripcion': 'Descripción de la actividad.',
  };
  final photo = File('assets/images/aquachile.png').absolute.path;

  for (final company in ['Empresa de prueba', 'Otra empresa']) {
    test('PDF header uses the record company: $company', () async {
      final bytes = await service.generate(
        data: {...data, 'empresa_nombre': company},
        signatureBytes: null,
      );
      final text = pdfText(bytes);
      expect(text, contains('$company Registro de Actividad Formativa'));
      expect(text, isNot(contains('SERVIMAF')));
      expect(
        text,
        contains(FormativeActivityPdfService.footerText.replaceAll('  ', ' ')),
      );
    });
  }

  test('PDF footer contact and independent version are exact', () {
    expect(
      FormativeActivityPdfService.footerText,
      'Generado por Servimaf  |  +56 9 8383 3177  |  v0.1.4',
    );
  });

  for (var count = 0; count <= 3; count++) {
    test(
      'PDF with $count photos fits one page and keeps its exact footer',
      () async {
        final bytes = await service.generate(
          data: data,
          signatureBytes: null,
          photoPaths: List.filled(count, photo),
        );
        expect(pdfPageCount(bytes), 1);
        expect(pdfImageDrawCount(bytes), count);
        final text = pdfText(bytes);
        expect(
          text,
          contains(
            FormativeActivityPdfService.footerText.replaceAll('  ', ' '),
          ),
        );
        expect(text, contains('Descripción de la actividad.'));
        expect(text, contains('ASISTENTES /'));
        expect(text, contains('OYENTES'));
        expect(text, contains('4'));
        expect(text, isNot(contains('HALLAZGOS')));
        expect(FormativeActivityPdfService.pdfVersion, '0.1.4');
      },
    );
  }

  test(
    'long description spans pages without losing its end or any photo',
    () async {
      final bytes = await service.generate(
        data: {
          ...data,
          'descripcion':
              '${List.filled(500, 'Contenido extenso de la actividad.').join(' ')} FINCONTENIDO',
        },
        signatureBytes: null,
        photoPaths: List.filled(11, photo),
      );
      expect(pdfPageCount(bytes), greaterThan(1));
      expect(pdfImageDrawCount(bytes), 11);
      expect(pdfText(bytes), contains('FINCONTENIDO'));
      // A sentence can cross a page boundary with header/footer between words.
      for (final word in ['Contenido', 'extenso', 'actividad.']) {
        expect(
          RegExp(RegExp.escape(word)).allMatches(pdfText(bytes)),
          hasLength(500),
        );
      }
    },
  );

  test('legacy record and caller without photos remain supported', () async {
    final bytes = await service.generate(data: const {}, signatureBytes: null);
    expect(pdfPageCount(bytes), 1);
    expect(pdfImageDrawCount(bytes), 0);
    expect(
      pdfText(bytes),
      contains(FormativeActivityPdfService.footerText.replaceAll('  ', ' ')),
    );
  });
}
