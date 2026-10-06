import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models/pdf/ast_report_data.dart';

/// Parámetros serializables para generar el PDF en un isolate.
class AstPdfIsolateParams {
  final AstReportData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List? logoBytes;

  AstPdfIsolateParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    this.logoBytes,
  });
}

/// ENTRY POINT para `compute()`.
Future<Uint8List> generateAstPdfEntryPoint(AstPdfIsolateParams params) async {
  final service = AstPdfGeneratorService();
  return service._generateSync(params);
}

/// Generador de PDF del módulo AST (Análisis Seguro de Trabajo).
///
/// Produce un informe limpio y ordenado: encabezado con marca + correlativo,
/// tabla de datos del informe, descripción de la actividad, listado de
/// hallazgos con evidencia, observaciones generales y anexo fotográfico.
class AstPdfGeneratorService {
  static const String _pdfVersion = '1.0.0';
  static const PdfColor _brand = PdfColor.fromInt(0xFF003366);
  static const PdfColor _brandLight = PdfColor.fromInt(0xFFE8EEF5);

  Future<Uint8List> _generateSync(AstPdfIsolateParams params) async {
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
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 36),
        ),
        header: (ctx) => _buildHeader(logoImage, data),
        footer: _buildFooter,
        build: (ctx) => [
          pw.SizedBox(height: 6),
          _buildDatosInforme(data),
          pw.SizedBox(height: 14),
          _buildDescripcion(data),
          pw.SizedBox(height: 14),
          ..._buildHallazgos(data),
          pw.SizedBox(height: 14),
          _buildObservaciones(data),
          ..._buildGalleryChunked(data.fotosPaths),
        ],
      ),
    );

    return pdf.save();
  }

  // -------------------------------------------------------------------------
  // HEADER / FOOTER
  // -------------------------------------------------------------------------

  pw.Widget _buildHeader(pw.MemoryImage? logo, AstReportData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 1.5)),
      ),
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
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                    color: _brand,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  data.titulo,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logo != null) pw.Container(height: 42, child: pw.Image(logo)),
              pw.SizedBox(height: 6),
              if (data.correlativo != null && data.correlativo!.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _brand,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    data.correlativo!,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                data.fecha,
                style: const pw.TextStyle(
                  fontSize: 9,
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
              'Módulo AST  |  Generado por JF Innova  |  v$_pdfVersion',
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

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const pw.BoxDecoration(color: _brand),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  pw.Widget _buildDatosInforme(AstReportData data) {
    // Dos columnas de pares label/valor para aprovechar el ancho.
    final rows = <pw.TableRow>[];
    for (var i = 0; i < data.datos.length; i += 2) {
      final left = data.datos[i];
      final right = (i + 1 < data.datos.length) ? data.datos[i + 1] : null;
      rows.add(
        pw.TableRow(
          children: [
            _dataCell(left.label, left.valor),
            right != null
                ? _dataCell(right.label, right.valor)
                : pw.Container(),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Datos del informe'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
          },
          children: rows,
        ),
      ],
    );
  }

  pw.Widget _dataCell(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.TextSpan(
              text: valor.isEmpty ? '—' : valor,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildDescripcion(AstReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Descripción de la actividad'),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Text(
            data.descripcionActividad.isNotEmpty
                ? data.descripcionActividad
                : 'Sin descripción registrada.',
            style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
          ),
        ),
      ],
    );
  }

  List<pw.Widget> _buildHallazgos(AstReportData data) {
    final widgets = <pw.Widget>[
      _buildSectionTitle('Hallazgos (${data.hallazgos.length})'),
    ];

    if (data.hallazgos.isEmpty) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Text(
            'Sin observaciones / hallazgos registrados.',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ),
      );
      return widgets;
    }

    for (final h in data.hallazgos) {
      pw.Widget? fotoWidget;
      if (h.fotoPath != null) {
        final f = File(h.fotoPath!);
        if (f.existsSync()) {
          try {
            fotoWidget = pw.Container(
              width: 85,
              height: 85,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              ),
              child: pw.Image(
                pw.MemoryImage(f.readAsBytesSync()),
                fit: pw.BoxFit.cover,
              ),
            );
          } catch (_) {}
        }
      }

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabecera del hallazgo
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                color: _brandLight,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 16,
                      height: 16,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(
                        color: _brand,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Text(
                        '${h.numero}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(
                        h.titulo.isNotEmpty ? h.titulo : 'Hallazgo ${h.numero}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cuerpo: detalle + evidencia
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        h.detalle.isNotEmpty
                            ? h.detalle
                            : 'Sin detalle adicional.',
                        style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                      ),
                    ),
                    if (fotoWidget != null) ...[
                      pw.SizedBox(width: 10),
                      fotoWidget,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  pw.Widget _buildObservaciones(AstReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Observaciones generales'),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Text(
            data.observaciones.isNotEmpty
                ? data.observaciones
                : 'Sin observaciones registradas.',
            style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
          ),
        ),
      ],
    );
  }

  List<pw.Widget> _buildGalleryChunked(List<String> paths) {
    final existentes = paths.where((p) => File(p).existsSync()).toList();
    if (existentes.isEmpty) return [];

    final widgets = <pw.Widget>[
      pw.SizedBox(height: 14),
      _buildSectionTitle('Anexo fotográfico'),
      pw.SizedBox(height: 8),
    ];

    final fila = <pw.Widget>[];
    for (final path in existentes) {
      try {
        final bytes = File(path).readAsBytesSync();
        fila.add(
          pw.Container(
            width: 155,
            height: 155,
            margin: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
        );
      } catch (e) {
        debugPrint('❌ Error cargando imagen AST PDF: $path - $e');
      }
      if (fila.length == 3) {
        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: List.of(fila),
          ),
        );
        fila.clear();
      }
    }
    if (fila.isNotEmpty) {
      widgets.add(
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: fila),
      );
    }
    return widgets;
  }
}
