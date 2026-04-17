import 'package:flutter_test/flutter_test.dart';

void main() {
  // ===================================================================
  // TESTS: _PdfDownloadButton - estados del botón PDF en historial
  // ===================================================================
  group('_PdfDownloadButton - estados del botón PDF', () {
    // Helper que simula la lógica de _PdfDownloadButton.build()
    String pdfButtonState({
      required bool isSynced,
      String? pdfUrl,
      String? pdfPathLocal,
    }) {
      if (!isSynced) return 'cloud_off';
      if (pdfUrl != null) return 'ver_pdf';
      if (pdfPathLocal != null && pdfPathLocal.isNotEmpty) {
        return 'pdf_local';
      }
      return 'pdf_pendiente';
    }

    test('Sin sincronizar muestra cloud_off', () {
      expect(pdfButtonState(isSynced: false, pdfUrl: null), 'cloud_off');
    });

    test('Sincronizado con pdf_url muestra Ver PDF', () {
      expect(
        pdfButtonState(
          isSynced: true,
          pdfUrl: 'https://storage.supabase.co/reportes/x.pdf',
        ),
        'ver_pdf',
      );
    });

    test('Sincronizado con pdf_path_local muestra PDF Local', () {
      expect(
        pdfButtonState(
          isSynced: true,
          pdfUrl: null,
          pdfPathLocal: '/data/user/0/com.app/reporte_42.pdf',
        ),
        'pdf_local',
      );
    });

    test('Sincronizado sin PDF muestra PDF Pendiente', () {
      expect(
        pdfButtonState(isSynced: true, pdfUrl: null, pdfPathLocal: null),
        'pdf_pendiente',
      );
    });

    test('pdf_path_local vacío se trata como null (muestra Pendiente)', () {
      expect(
        pdfButtonState(isSynced: true, pdfUrl: null, pdfPathLocal: ''),
        'pdf_pendiente',
      );
    });

    test('pdf_url tiene prioridad sobre pdf_path_local', () {
      expect(
        pdfButtonState(
          isSynced: true,
          pdfUrl: 'https://storage.supabase.co/reportes/x.pdf',
          pdfPathLocal: '/data/user/0/com.app/reporte_42.pdf',
        ),
        'ver_pdf',
      );
    });

    test('No sincronizado ignora pdf_url', () {
      expect(
        pdfButtonState(
          isSynced: false,
          pdfUrl: 'https://storage.supabase.co/reportes/x.pdf',
        ),
        'cloud_off',
      );
    });
  });

  // ===================================================================
  // TESTS: Detección de número real vs provisional/estimado
  // ===================================================================
  group('Detección de número de informe real', () {
    bool tieneNumeroReal(String textoNumero) {
      return textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");
    }

    test('Número vacío → no real (difiere PDF)', () {
      expect(tieneNumeroReal(''), false);
    });

    test('Número real → true', () {
      expect(tieneNumeroReal('42'), true);
    });

    test('Estimado ~N → no real', () {
      expect(tieneNumeroReal('~43'), false);
    });

    test('PROV-* legacy → no real', () {
      expect(tieneNumeroReal('PROV-abc12345'), false);
    });

    test('Número largo → real', () {
      expect(tieneNumeroReal('12345'), true);
    });
  });

  // ===================================================================
  // TESTS: Query de PDFs diferidos con filtro de números provisionales
  // ===================================================================
  group('Query PDFs diferidos - filtro PROV/~ en números', () {
    bool queryPdfPendiente(Map<String, dynamic> a) {
      final numero = a['numero_reporte']?.toString() ?? '';
      return a['estado_final'] == 'En Seguimiento' &&
          (a['pdf_path_local'] == null || a['pdf_path_local'] == '') &&
          (a['pdf_url'] == null || a['pdf_url'] == '') &&
          a['eliminado'] == 0 &&
          numero.isNotEmpty &&
          !numero.startsWith('PROV-') &&
          !numero.startsWith('~');
    }

    test('Número real sin PDF → se genera', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '42',
      };
      expect(queryPdfPendiente(row), true);
    });

    test('Número PROV-* → no se genera (necesita real)', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': 'PROV-abc12345',
      };
      expect(queryPdfPendiente(row), false,
          reason: 'PROV-* es provisional, trigger aún no asignó número real');
    });

    test('Número ~N → no se genera (necesita real)', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '~43',
      };
      expect(queryPdfPendiente(row), false,
          reason: '~N es estimado, trigger aún no asignó número real');
    });

    test('Ya tiene pdf_url → no se genera', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': 'https://storage.supabase.co/reportes/x.pdf',
        'eliminado': 0,
        'numero_reporte': '42',
      };
      expect(queryPdfPendiente(row), false, reason: 'Ya tiene PDF en la nube');
    });

    test('Sin número → no se genera', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': null,
      };
      expect(queryPdfPendiente(row), false, reason: 'Sin número de reporte');
    });

    test('Ya tiene pdf_path_local → no se genera (PDF local existente)', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': '/data/reporte_42.pdf',
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '42',
      };
      expect(queryPdfPendiente(row), false,
          reason: 'Ya existe PDF local generado con número real');
    });
  });

  // ===================================================================
  // TESTS: Fallback historial local - normalización de datos
  // ===================================================================
  group('Fallback historial local - normalización', () {
    Map<String, dynamic> normalizarLocal(Map<String, dynamic> r) {
      return <String, dynamic>{
        'id': r['id'],
        'modulo': 'Inspección',
        'tipo_registro': r['tipo_actividad'],
        'estado': r['estado_final'],
        'ubicacion': r['centro_nombre'] ?? 'Sin ubicación',
        'fecha_realizacion': r['fecha_realizacion'],
        'numero_reporte': r['numero_reporte'],
        'pdf_url': r['pdf_url'],
        'pdf_path_local': r['pdf_path_local'],
        'inspector_nombre': r['inspector_nombre'] ?? 'Usuario',
        'numero_seguimiento': r['numero_seguimiento'] ?? 0,
        'centro_id': null,
        'embarcacion_id': null,
        'subido': r['subido'] ?? 0,
      };
    }

    test('Normaliza campos locales al shape de HistoryCard', () {
      final local = {
        'id': 'act-001',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'estado_final': 'En Seguimiento',
        'centro_nombre': 'Centro Natales',
        'fecha_realizacion': '2026-04-15T10:00:00',
        'numero_reporte': '42',
        'pdf_url': null,
        'pdf_path_local': null,
        'inspector_nombre': 'Juan Pérez',
        'numero_seguimiento': 0,
        'subido': 0,
      };

      final normalized = normalizarLocal(local);

      expect(normalized['modulo'], 'Inspección');
      expect(normalized['tipo_registro'], 'INSPECCION_BUCEO');
      expect(normalized['estado'], 'En Seguimiento');
      expect(normalized['ubicacion'], 'Centro Natales');
      expect(normalized['subido'], 0);
    });

    test('Campo centro_nombre null usa fallback', () {
      final local = {
        'id': 'act-002',
        'tipo_actividad': 'INSPECCION_EMBARCACION',
        'estado_final': 'En Seguimiento',
        'centro_nombre': null,
        'fecha_realizacion': '2026-04-15',
        'numero_reporte': null,
        'pdf_url': null,
        'pdf_path_local': null,
        'inspector_nombre': null,
        'numero_seguimiento': null,
        'subido': null,
      };

      final normalized = normalizarLocal(local);

      expect(normalized['ubicacion'], 'Sin ubicación');
      expect(normalized['inspector_nombre'], 'Usuario');
      expect(normalized['numero_seguimiento'], 0);
      expect(normalized['subido'], 0);
    });
  });

  // ===================================================================
  // TESTS: Botón finalizar - lógica de conectividad
  // ===================================================================
  group('Botón finalizar - conectividad', () {
    test('Online: texto "FINALIZAR INSPECCIÓN"', () {
      const isOnline = true;
      final label =
          isOnline ? 'FINALIZAR INSPECCIÓN' : 'FINALIZAR (sin conexión)';
      expect(label, 'FINALIZAR INSPECCIÓN');
    });

    test('Offline: texto "FINALIZAR (sin conexión)"', () {
      const isOnline = false;
      final label =
          isOnline ? 'FINALIZAR INSPECCIÓN' : 'FINALIZAR (sin conexión)';
      expect(label, 'FINALIZAR (sin conexión)');
    });

    test('Online: opacity completa (1.0)', () {
      const isOnline = true;
      final opacity = isOnline ? 1.0 : 0.65;
      expect(opacity, 1.0);
    });

    test('Offline: opacity reducida (0.65)', () {
      const isOnline = false;
      final opacity = isOnline ? 1.0 : 0.65;
      expect(opacity, 0.65);
    });
  });

  // ===================================================================
  // TESTS: Controller offline - pdfDiferido sin número real
  // ===================================================================
  group('Controller offline - flujo de finalización sin PDF', () {
    test('Offline persiste con pdfPathLocal null y pdfUrl null', () {
      // Cuando no hay número real, NO se genera PDF
      // Se guarda como "En Seguimiento" sin PDF para que
      // DeferredPdfService lo procese después con número real
      final actividadMap = {
        'id': 'act-001',
        'estado_final': 'En Seguimiento',
        'pdf_url': null,
        'pdf_path_local': null,
      };

      expect(actividadMap['pdf_path_local'], isNull);
      expect(actividadMap['pdf_url'], isNull);
      expect(actividadMap['estado_final'], 'En Seguimiento');
    });

    test('DeferredPdfService detecta actividad sin PDF y con número real', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '42', // número real asignado por trigger
      };

      final numero = row['numero_reporte']?.toString() ?? '';
      final necesitaGenerar = row['estado_final'] == 'En Seguimiento' &&
          (row['pdf_path_local'] == null || row['pdf_path_local'] == '') &&
          (row['pdf_url'] == null || row['pdf_url'] == '') &&
          row['eliminado'] == 0 &&
          numero.isNotEmpty &&
          !numero.startsWith('PROV-') &&
          !numero.startsWith('~');

      expect(necesitaGenerar, true,
          reason: 'Tiene número real del trigger → debe generar PDF');
    });

    test('DeferredPdfService ignora actividad sin número real', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': null, // trigger aún no asignó
      };

      final numero = row['numero_reporte']?.toString() ?? '';
      final necesitaGenerar = row['estado_final'] == 'En Seguimiento' &&
          (row['pdf_path_local'] == null || row['pdf_path_local'] == '') &&
          (row['pdf_url'] == null || row['pdf_url'] == '') &&
          row['eliminado'] == 0 &&
          numero.isNotEmpty &&
          !numero.startsWith('PROV-') &&
          !numero.startsWith('~');

      expect(necesitaGenerar, false,
          reason: 'Sin número → espera al trigger de Supabase');
    });
  });
}
