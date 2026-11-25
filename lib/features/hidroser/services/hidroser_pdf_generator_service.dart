import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models/pdf/hidroser_report_data.dart';

/// PARÁMETROS PARA ISOLATE — espejo del patrón de Visitas.
class HidroserPdfIsolateParams {
  final HidroserReportData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List? logoBytes;

  HidroserPdfIsolateParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    this.logoBytes,
  });
}

/// ENTRY POINT para `compute()`.
Future<Uint8List> generateHidroserPdfEntryPoint(
  HidroserPdfIsolateParams params,
) async {
  final service = HidroserPdfGeneratorService();
  return service._generateSync(params);
}

/// Generador de PDF adaptable a cualquier lista del módulo Hidroser.
///
/// Diseño:
/// - El encabezado se compone de bloques opcionales (logo, título, fecha,
///   correlativo, profesional).
/// - Los "datos del encabezado de la lista" se renderizan desde
///   [HidroserReportData.headerFields], por lo que cada lista puede tener
///   campos distintos sin tocar este servicio.
/// - El checklist se agrupa por categoría (mismo formato visual que Visitas
///   para mantener consistencia de marca).
/// - Las firmas son una lista — se pueden mostrar 0, 1 o 2 (o más) firmas.
class HidroserPdfGeneratorService {
  static const String _pdfVersion = '0.1.0';

  Future<Uint8List> _generateSync(HidroserPdfIsolateParams params) async {
    final pdf = pw.Document();
    final data = params.data;

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(params.fontRegular.buffer.asByteData()),
      bold: pw.Font.ttf(params.fontBold.buffer.asByteData()),
    );

    pw.MemoryImage? logoImage;
    if (params.logoBytes != null) {
      logoImage = pw.MemoryImage(params.logoBytes!);
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
        ),
        header: (ctx) => _buildHeader(logoImage, data),
        footer: _buildFooter,
        build: (ctx) => [
          pw.SizedBox(height: 8),
          if (data.profesional.isNotEmpty ||
              data.fonoProfesional.isNotEmpty ||
              data.correoProfesional.isNotEmpty) ...[
            _buildDatosProfesional(data),
            pw.SizedBox(height: 10),
          ],
          if (data.headerFields.isNotEmpty) ...[
            _buildHeaderFields(data),
            pw.SizedBox(height: 10),
          ],
          _buildObservaciones(data),
          pw.SizedBox(height: 20),
          if (data.firmas.isNotEmpty) _buildFirmas(data.firmas),
          // Checklist con foto por pregunta dentro de la celda.
          if (data.checklistItems.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            ..._buildChecklistSection(data),
          ],
          // Anexo fotográfico (galería general) SIEMPRE al final.
          ..._buildGalleryChunked(data.fotosPaths),
        ],
      ),
    );

    return pdf.save();
  }

  // -------------------------------------------------------------------------
  // HEADER / FOOTER
  // -------------------------------------------------------------------------

  pw.Widget _buildHeader(pw.MemoryImage? logo, HidroserReportData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  data.empresaProveedor,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  data.tituloLista,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (data.subtitulo != null && data.subtitulo!.isNotEmpty)
                  pw.Text(
                    data.subtitulo!,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logo != null) pw.Container(height: 40, child: pw.Image(logo)),
              pw.SizedBox(height: 5),
              pw.Text(
                'Fecha: ${data.fecha}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (data.correlativo != null && data.correlativo!.isNotEmpty)
                pw.Text(
                  'N° ${data.correlativo!}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.Text(
                'Versión: $_pdfVersion',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Módulo Hidroser  |  Generado por JF Innova  |  v$_pdfVersion',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
            ),
            pw.Text(
              'Pág. ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // BLOQUES
  // -------------------------------------------------------------------------

  pw.Widget _buildDatosProfesional(HidroserReportData data) {
    return _tableSection('Datos del profesional', [
      if (data.profesional.isNotEmpty)
        _tableRow('Profesional', data.profesional),
      if (data.fonoProfesional.isNotEmpty)
        _tableRow('Fono', data.fonoProfesional),
      if (data.correoProfesional.isNotEmpty)
        _tableRow('Correo', data.correoProfesional),
    ]);
  }

  pw.Widget _buildHeaderFields(HidroserReportData data) {
    return _tableSection('Datos de la inspección', [
      for (final f in data.headerFields) _tableRow(f.label, f.valor),
    ]);
  }

  pw.Widget _buildObservaciones(HidroserReportData data) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(5),
            color: PdfColors.grey200,
            child: pw.Text(
              'Observaciones',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              data.observaciones.isNotEmpty
                  ? data.observaciones
                  : 'Sin observaciones registradas.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFirmas(List<HidroserFirmaDto> firmas) {
    return pw.Row(
      mainAxisAlignment: firmas.length == 1
          ? pw.MainAxisAlignment.center
          : pw.MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: firmas.map(_buildFirmaBlock).toList(),
    );
  }

  pw.Widget _buildFirmaBlock(HidroserFirmaDto firma) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (firma.imagen != null)
          pw.Image(
            pw.MemoryImage(firma.imagen!),
            width: 140,
            height: 50,
            fit: pw.BoxFit.contain,
          )
        else
          pw.SizedBox(width: 140, height: 50),
        pw.Container(
          width: 140,
          height: 1,
          color: PdfColors.black,
          margin: const pw.EdgeInsets.only(top: 4, bottom: 4),
        ),
        pw.Text(
          firma.rol,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        if (firma.nombre != null && firma.nombre!.isNotEmpty)
          pw.Text(
            firma.nombre!,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
      ],
    );
  }

  List<pw.Widget> _buildChecklistSection(HidroserReportData data) {
    final Map<String, List<HidroserChecklistItemDto>> grouped = {};
    for (final item in data.checklistItems) {
      grouped.putIfAbsent(item.categoria, () => []).add(item);
    }

    final widgets = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        child: pw.Text(
          'CHECKLIST',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];

    int counter = 1;
    for (final category in grouped.keys) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          margin: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          child: pw.Text(
            category.toUpperCase(),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.blue900,
            ),
          ),
        ),
      );

      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FixedColumnWidth(25),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(35),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _cellPdf('N', bold: true),
                _cellPdf('Item', bold: true),
                _cellPdf('Est.', bold: true),
                _cellPdf('Observación', bold: true),
              ],
            ),
            ...grouped[category]!.map((item) {
              final isNC = item.respuesta == 'NC';
              pw.Widget? fotoWidget;
              if (item.fotoPath != null) {
                final f = File(item.fotoPath!);
                if (f.existsSync()) {
                  try {
                    fotoWidget = pw.Container(
                      width: 70,
                      height: 70,
                      margin: const pw.EdgeInsets.only(top: 3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey400,
                          width: 0.5,
                        ),
                      ),
                      child: pw.Image(
                        pw.MemoryImage(f.readAsBytesSync()),
                        fit: pw.BoxFit.cover,
                      ),
                    );
                  } catch (_) {}
                }
              }
              final row = pw.TableRow(
                decoration: isNC
                    ? const pw.BoxDecoration(color: PdfColors.red50)
                    : null,
                children: [
                  _cellPdf('$counter'),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                      item.pregunta,
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                  _cellPdf(item.respuesta, color: isNC ? PdfColors.red : null),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if ((item.observacion ?? '').isNotEmpty)
                          pw.Text(
                            item.observacion!,
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        if (fotoWidget != null) fotoWidget,
                      ],
                    ),
                  ),
                ],
              );
              counter++;
              return row;
            }),
          ],
        ),
      );
    }
    return widgets;
  }

  List<pw.Widget> _buildGalleryChunked(List<String> paths) {
    if (paths.isEmpty) return [];

    final widgets = <pw.Widget>[
      pw.SizedBox(height: 10),
      pw.Text(
        'ANEXO FOTOGRÁFICO',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.Divider(),
      pw.SizedBox(height: 10),
    ];

    final fila = <pw.Widget>[];
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        final bytes = file.readAsBytesSync();
        fila.add(
          pw.Container(
            width: 120,
            height: 120,
            margin: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
            ),
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
        );
      } catch (e) {
        debugPrint('❌ Error cargando imagen Hidroser PDF: $path - $e');
      }
      if (fila.length == 3) {
        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: List.of(fila),
          ),
        );
        fila.clear();
      }
    }
    if (fila.isNotEmpty) {
      widgets.add(
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: fila),
      );
    }
    return widgets;
  }

  // -------------------------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------------------------

  pw.Widget _tableSection(String title, List<pw.TableRow> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (rows.isNotEmpty)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: rows,
          ),
      ],
    );
  }

  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  pw.Widget _cellPdf(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
