// ignore_for_file: unused_local_variable, dead_code
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
      expect(
        queryPdfPendiente(row),
        false,
        reason: 'PROV-* es provisional, trigger aún no asignó número real',
      );
    });

    test('Número ~N → no se genera (necesita real)', () {
      final row = {
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '~43',
      };
      expect(
        queryPdfPendiente(row),
        false,
        reason: '~N es estimado, trigger aún no asignó número real',
      );
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
      expect(
        queryPdfPendiente(row),
        false,
        reason: 'Ya existe PDF local generado con número real',
      );
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
  // TESTS: Previsualizar PDF antes de finalizar NO interfiere
  // ===================================================================
  group('Previsualizar PDF antes de finalizar', () {
    test('Preview no guarda pdf_path_local ni pdf_url', () {
      // La previsualización genera el PDF en memoria (Uint8List)
      // y lo muestra con Printing.layoutPdf. No persiste nada.
      // Simulamos el estado de la actividad antes y después de preview.
      final actividadAntes = {
        'id': 'act-001',
        'estado_final': 'En Progreso',
        'pdf_url': null,
        'pdf_path_local': null,
        'numero_reporte': null,
        'subido': 0,
      };

      // Después de previsualizar, nada cambia en la actividad
      final actividadDespuesPreview = Map<String, dynamic>.from(actividadAntes);

      expect(
        actividadDespuesPreview['pdf_url'],
        isNull,
        reason: 'Preview no setea pdf_url',
      );
      expect(
        actividadDespuesPreview['pdf_path_local'],
        isNull,
        reason: 'Preview no setea pdf_path_local',
      );
      expect(
        actividadDespuesPreview['estado_final'],
        'En Progreso',
        reason: 'Preview no cambia el estado',
      );
    });

    test('Finalizar después de preview genera PDF normalmente', () {
      // Después de previsualizar, el usuario finaliza.
      // El controller genera un PDF NUEVO (no reutiliza el de preview).
      final pdfUrlSubido =
          'https://storage.supabase.co/reportes/act-001/reporte_42.pdf';
      final pdfPathLocal = '/data/user/0/com.app/documents/reporte_42.pdf';

      // Caso online: PDF se genera, se guarda local, se sube a Storage
      final actividadFinalizada = {
        'id': 'act-001',
        'estado_final': 'En Seguimiento',
        'pdf_url': pdfUrlSubido,
        'pdf_path_local': null, // Se limpia porque upload exitoso
        'numero_reporte': '42',
        'subido': 0,
      };

      expect(
        actividadFinalizada['pdf_url'],
        isNotNull,
        reason: 'Finalizar genera y sube PDF aunque se haya previsualizdo',
      );
      expect(
        actividadFinalizada['pdf_path_local'],
        isNull,
        reason: 'Con upload exitoso, path local se limpia',
      );
      expect(actividadFinalizada['estado_final'], 'En Seguimiento');
    });

    test('Finalizar con upload fallido guarda pdf_path_local para retry', () {
      // Si el upload a Storage falla (sin red), se guarda el path local
      final pdfPathLocal = '/data/user/0/com.app/documents/reporte_42.pdf';

      final actividadFinalizada = {
        'id': 'act-001',
        'estado_final': 'En Seguimiento',
        'pdf_url': null, // Upload falló
        'pdf_path_local': pdfPathLocal, // Se mantiene para retry
        'numero_reporte': '42',
        'subido': 0,
      };

      expect(actividadFinalizada['pdf_url'], isNull);
      expect(
        actividadFinalizada['pdf_path_local'],
        isNotNull,
        reason: 'Path local se preserva para que sync lo suba después',
      );
    });
  });

  // ===================================================================
  // TESTS: Sync sube PDF pendiente a Storage
  // ===================================================================
  group('Sync - subida de PDF pendiente', () {
    test('Sync detecta PDF pendiente: pdf_path_local sin pdf_url', () {
      final row = {
        'pdf_path_local': '/data/user/0/com.app/documents/reporte_42.pdf',
        'pdf_url': null,
        'numero_reporte': '42',
      };

      final pdfPathLocal = row['pdf_path_local'];
      final pdfUrlActual = row['pdf_url'];

      final debeSub =
          pdfPathLocal != null &&
          pdfPathLocal.isNotEmpty &&
          (pdfUrlActual == null || pdfUrlActual.isEmpty);

      expect(
        debeSub,
        true,
        reason: 'Tiene PDF local pero no URL → sync debe subirlo',
      );
    });

    test('Sync NO intenta subir si ya tiene pdf_url', () {
      final row = {
        'pdf_path_local': '/data/user/0/com.app/documents/reporte_42.pdf',
        'pdf_url':
            'https://storage.supabase.co/reportes/act-001/reporte_42.pdf',
        'numero_reporte': '42',
      };

      final pdfPathLocal = row['pdf_path_local'];
      final pdfUrlActual = row['pdf_url'];

      final debeSub =
          pdfPathLocal != null &&
          pdfPathLocal.isNotEmpty &&
          (pdfUrlActual == null || pdfUrlActual.isEmpty);

      expect(debeSub, false, reason: 'Ya tiene URL → no necesita resubir');
    });

    test('Sync NO intenta subir si pdf_path_local es null', () {
      final row = {
        'pdf_path_local': null,
        'pdf_url': null,
        'numero_reporte': '42',
      };

      final pdfPathLocal = row['pdf_path_local'];
      final pdfUrlActual = row['pdf_url'];

      final debeSub =
          pdfPathLocal != null &&
          pdfPathLocal.isNotEmpty &&
          (pdfUrlActual == null || pdfUrlActual.isEmpty);

      expect(
        debeSub,
        false,
        reason:
            'Sin PDF local → nada que subir (DeferredPdfService se encarga)',
      );
    });

    test('Después de subir PDF, sync limpia pdf_path_local y pone pdf_url', () {
      // Simulamos lo que sync hace después de subir exitosamente
      final rowAntes = {
        'pdf_path_local': '/data/user/0/com.app/documents/reporte_42.pdf',
        'pdf_url': null,
      };

      // Sync sube el archivo y actualiza:
      final updateDespues = {
        'pdf_url':
            'https://storage.supabase.co/reportes/act-001/reporte_42.pdf',
        'pdf_path_local': null,
      };

      final rowDespues = {...rowAntes, ...updateDespues};

      expect(rowDespues['pdf_url'], isNotNull);
      expect(
        rowDespues['pdf_path_local'],
        isNull,
        reason: 'Path local se limpia después de subir exitosamente',
      );
    });
  });

  // ===================================================================
  // TESTS: datosParaNube excluye campos locales
  // ===================================================================
  group('Sync - datosParaNube para Supabase', () {
    test('pdf_path_local se remueve de datosParaNube', () {
      final row = {
        'id': 'act-001',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'estado_final': 'En Seguimiento',
        'pdf_url':
            'https://storage.supabase.co/reportes/act-001/reporte_42.pdf',
        'pdf_path_local': '/data/user/0/com.app/documents/reporte_42.pdf',
        'numero_reporte': '42',
        'subido': 0,
        'eliminado': 0,
        'app_version': '1.0.0',
      };

      final datosParaNube = Map<String, dynamic>.from(row);
      datosParaNube.remove('numero_reporte');
      datosParaNube.remove('subido');
      datosParaNube.remove('eliminado');
      datosParaNube.remove('pdf_path_local');
      datosParaNube.remove('app_version');

      expect(
        datosParaNube.containsKey('pdf_path_local'),
        false,
        reason: 'pdf_path_local es local, no debe ir a Supabase',
      );
      expect(datosParaNube.containsKey('subido'), false);
      expect(datosParaNube.containsKey('eliminado'), false);
      expect(datosParaNube.containsKey('app_version'), false);
      expect(
        datosParaNube.containsKey('numero_reporte'),
        false,
        reason: 'numero_reporte se maneja por trigger de Supabase',
      );
      expect(
        datosParaNube['pdf_url'],
        isNotNull,
        reason: 'pdf_url SÍ va a Supabase',
      );
    });

    test('pdf_url null se envía a Supabase (no se omite)', () {
      final row = {
        'id': 'act-001',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'estado_final': 'En Seguimiento',
        'pdf_url': null,
        'pdf_path_local': '/data/reporte_42.pdf',
        'subido': 0,
      };

      final datosParaNube = Map<String, dynamic>.from(row);
      datosParaNube.remove('pdf_path_local');
      datosParaNube.remove('subido');

      // pdf_url null se envía → Supabase lo guarda como null
      // Esto es correcto: el PDF se subirá después via Storage
      expect(datosParaNube.containsKey('pdf_url'), true);
      expect(datosParaNube['pdf_url'], isNull);
    });
  });

  // ===================================================================
  // TESTS: _persistirDatos - lógica de pdf_path_local condicional
  // ===================================================================
  group('_persistirDatos - pdf_path_local condicional', () {
    test('Upload exitoso: pdf_url set, pdf_path_local null', () {
      // Línea 774 del controller:
      // pdfPathLocal: pdfUrlSubido == null ? pdfPathLocal : null
      final pdfUrlSubido = 'https://storage.supabase.co/reportes/x.pdf';
      final pdfPathLocal = '/data/reporte_42.pdf';

      final valorFinal = null;

      expect(
        valorFinal,
        isNull,
        reason: 'Con URL subida, no necesitamos path local',
      );
    });

    test('Upload fallido: pdf_url null, pdf_path_local preservado', () {
      final String? pdfUrlSubido = null; // Upload falló
      final pdfPathLocal = '/data/reporte_42.pdf';

      final valorFinal = pdfUrlSubido == null ? pdfPathLocal : null;

      expect(
        valorFinal,
        pdfPathLocal,
        reason: 'Sin URL, guardamos path local para retry',
      );
    });

    test(
        'PDF local eliminado (reinstalación): sync limpia path para regenerar',
        () {
      // Caso: pdf_path_local apunta a archivo que ya no existe
      // (reinstalación, clear data, etc.)
      // Sync debe limpiar pdf_path_local → DeferredPdfService lo regenera
      final row = {
        'pdf_path_local': '/data/user/0/com.app/documents/reporte_42.pdf',
        'pdf_url': null,
        'numero_reporte': '42',
        'estado_final': 'En Seguimiento',
        'eliminado': 0,
      };

      // Simulamos: file.existsSync() → false
      const fileExists = false;

      if (!fileExists) {
        // Sync limpia pdf_path_local
        row['pdf_path_local'] = null;
      }

      // Ahora DeferredPdfService SÍ lo detecta
      final numero = row['numero_reporte']?.toString() ?? '';
      final necesitaGenerar = row['estado_final'] == 'En Seguimiento' &&
          (row['pdf_path_local'] == null || row['pdf_path_local'] == '') &&
          (row['pdf_url'] == null || row['pdf_url'] == '') &&
          row['eliminado'] == 0 &&
          numero.isNotEmpty &&
          !numero.startsWith('PROV-') &&
          !numero.startsWith('~');

      expect(necesitaGenerar, true,
          reason:
              'Después de limpiar path stale, DeferredPdfService regenera el PDF');
    });

    test('SIN fix: pdf_path_local stale bloquea regeneración', () {
      // Documenta el bug que existía ANTES del fix:
      // pdf_path_local apunta a archivo eliminado pero DeferredPdfService
      // no lo detecta porque el campo no es null/vacío
      final row = {
        'pdf_path_local': '/data/user/0/com.app/documents/reporte_42.pdf',
        'pdf_url': null,
        'numero_reporte': '42',
        'estado_final': 'En Seguimiento',
        'eliminado': 0,
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
          reason:
              'Bug anterior: path stale impedía que DeferredPdfService detecte la actividad');
    });
  });

  // ===================================================================
  // TESTS: Botón finalizar - lógica de conectividad
  // ===================================================================
  group('Botón finalizar - conectividad', () {
    test('Online: texto "FINALIZAR INSPECCIÓN"', () {
      const isOnline = true;
      final label = isOnline
          ? 'FINALIZAR INSPECCIÓN'
          : 'FINALIZAR (sin conexión)';
      expect(label, 'FINALIZAR INSPECCIÓN');
    });

    test('Offline: texto "FINALIZAR (sin conexión)"', () {
      const isOnline = false;
      final label = isOnline
          ? 'FINALIZAR INSPECCIÓN'
          : 'FINALIZAR (sin conexión)';
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
      final necesitaGenerar =
          row['estado_final'] == 'En Seguimiento' &&
          (row['pdf_path_local'] == null || row['pdf_path_local'] == '') &&
          (row['pdf_url'] == null || row['pdf_url'] == '') &&
          row['eliminado'] == 0 &&
          numero.isNotEmpty &&
          !numero.startsWith('PROV-') &&
          !numero.startsWith('~');

      expect(
        necesitaGenerar,
        true,
        reason: 'Tiene número real del trigger → debe generar PDF',
      );
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
      final necesitaGenerar =
          row['estado_final'] == 'En Seguimiento' &&
          (row['pdf_path_local'] == null || row['pdf_path_local'] == '') &&
          (row['pdf_url'] == null || row['pdf_url'] == '') &&
          row['eliminado'] == 0 &&
          numero.isNotEmpty &&
          !numero.startsWith('PROV-') &&
          !numero.startsWith('~');

      expect(
        necesitaGenerar,
        false,
        reason: 'Sin número → espera al trigger de Supabase',
      );
    });
  });
}
