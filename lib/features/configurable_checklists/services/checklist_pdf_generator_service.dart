import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models/pdf/checklist_report_data.dart';

/// Parámetros serializables para generar el PDF en un isolate.
class ChecklistPdfIsolateParams {
  final ChecklistReportData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List? logoBytes;

  ChecklistPdfIsolateParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    this.logoBytes,
  });
}

/// Entry point para `compute()`.
Future<Uint8List> generateChecklistPdfEntryPoint(
  ChecklistPdfIsolateParams params,
) async {
  final service = ChecklistPdfGeneratorService();
  return service._generateSync(params);
}

class _ChecklistPdfPalette {
  static final PdfColor rule = PdfColor.fromHex('#CDEAF2');
  static final PdfColor ink = PdfColor.fromHex('#1D4A5F');
  static final PdfColor inkFaint = PdfColor.fromHex('#8FBACB');
  static final PdfColor green = PdfColor.fromHex('#00975B');
  static final PdfColor greenLight = PdfColor.fromHex('#E1F8ED');
  static final PdfColor red = PdfColor.fromHex('#E5484D');
  static final PdfColor redLight = PdfColor.fromHex('#FFECED');
  static final PdfColor naLight = PdfColor.fromHex('#DFF1F6');
}

/// Genera el PDF de los checklists configurables (motor genérico) replicando
/// el formato de referencia "M&S — Lista de chequeo": encabezado con logo +
/// datos generales en tabla, checklist numerado, apuntes/observaciones,
/// fotos generales y firma, con footer "Generado por Servimaf".
class ChecklistPdfGeneratorService {
  static const String _pdfVersion = '0.1.0';

  Future<Uint8List> _generateSync(ChecklistPdfIsolateParams params) async {
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
          margin: const pw.EdgeInsets.all(28),
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? _buildHeader(logoImage, data)
            : pw.SizedBox.shrink(),
        footer: (ctx) => _buildFooter(ctx, data),
        build: (ctx) => [
          if (data.datosGenerales.isNotEmpty) ...[
            _buildDatosGenerales(data),
            pw.SizedBox(height: 12),
          ],
          ..._buildChecklistTables(data),
          pw.SizedBox(height: 16),
          _buildApuntesObservaciones(data),
          ..._buildGalleryChunked(data.fotosGeneralesPaths),
          pw.SizedBox(height: 20),
          _buildFirma(data),
        ],
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------
  // ENCABEZADO / PIE
  // ---------------------------------------------------------------------

  pw.Widget _buildHeader(pw.MemoryImage? logo, ChecklistReportData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                data.empresaNombre,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              if (logo != null) pw.Container(height: 44, child: pw.Image(logo)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                data.tituloChecklist.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
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
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400, thickness: 0.75),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx, ChecklistReportData data) {
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
              'Generado por Servimaf  |  +56 9 8383 3177  |  v$_pdfVersion',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
            ),
            pw.Text(
              'Pág. ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // BLOQUES
  // ---------------------------------------------------------------------

  pw.Widget _buildDatosGenerales(ChecklistReportData data) {
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
            'Datos generales',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(3),
          },
          children: [
            for (final f in data.datosGenerales)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      f.label,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      f.valor.isEmpty ? '—' : f.valor,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  List<pw.Widget> _buildChecklistTables(ChecklistReportData data) {
    if (data.checklistItems.isEmpty) return const [];
    final grouped = <String, List<ChecklistPdfItemDto>>{};
    for (final item in data.checklistItems) {
      grouped.putIfAbsent(item.categoria ?? 'Checklist', () => []).add(item);
    }

    final tables = <pw.Widget>[];
    for (final entry in grouped.entries) {
      final items = entry.value;
      final rows = items.map(_buildChecklistRow).toList();
      final start = items.first.numero;
      final end = items.last.numero;
      final categoryHeader = pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 14),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              entry.key.toUpperCase(),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Spacer(),
            pw.Text(
              'items ${start.toString().padLeft(2, '0')}-${end.toString().padLeft(2, '0')}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      );
      final border = pw.TableBorder(
        left: pw.BorderSide(color: _ChecklistPdfPalette.rule, width: 1),
        right: pw.BorderSide(color: _ChecklistPdfPalette.rule, width: 1),
        bottom: pw.BorderSide(color: _ChecklistPdfPalette.rule, width: 1),
      );
      final columnWidths = <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(34),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(82),
        3: const pw.FixedColumnWidth(46),
      };

      tables.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            categoryHeader,
            pw.Table(
              border: border,
              columnWidths: columnWidths,
              children: [rows.first],
            ),
          ],
        ),
      );
      if (rows.length > 1) {
        tables.add(
          pw.Table(
            border: border,
            columnWidths: columnWidths,
            children: rows.skip(1).toList(),
          ),
        );
      }
      tables.add(pw.SizedBox(height: 14));
    }
    return tables;
  }

  pw.TableRow _buildChecklistRow(ChecklistPdfItemDto item) {
    final status = _statusFor(item.respuesta);
    final isNoCumple = status.$1 == 'NC';
    final isNoAplica = status.$1 == 'N/A';
    final hasObservation = (item.observacion ?? '').trim().isNotEmpty;

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isNoCumple
            ? _ChecklistPdfPalette.redLight
            : (isNoAplica ? _ChecklistPdfPalette.naLight : PdfColors.white),
        border: pw.Border(
          bottom: pw.BorderSide(color: _ChecklistPdfPalette.rule, width: 0.75),
        ),
      ),
      children: [
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              right: pw.BorderSide(
                color: _ChecklistPdfPalette.rule,
                width: 0.75,
              ),
            ),
          ),
          child: pw.Text(
            item.numero.toString().padLeft(2, '0'),
            style: pw.TextStyle(
              fontSize: 8,
              color: _ChecklistPdfPalette.inkFaint,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                item.descripcion,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  color: isNoCumple
                      ? _ChecklistPdfPalette.red
                      : _ChecklistPdfPalette.ink,
                  fontWeight: isNoCumple
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
              if (hasObservation) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  item.observacion!.trim(),
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontStyle: pw.FontStyle.italic,
                    color: isNoCumple
                        ? _ChecklistPdfPalette.red
                        : _ChecklistPdfPalette.inkFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(
                color: _ChecklistPdfPalette.rule,
                width: 0.75,
              ),
              right: pw.BorderSide(
                color: _ChecklistPdfPalette.rule,
                width: 0.75,
              ),
            ),
          ),
          child: item.fotoPath == null
              ? pw.Text('-', style: const pw.TextStyle(fontSize: 8))
              : _fotoCelda(item.fotoPath!),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 2.5,
            ),
            decoration: pw.BoxDecoration(
              color: status.$2,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              status.$1,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: status.$3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  (String, PdfColor, PdfColor) _statusFor(String? respuesta) {
    switch ((respuesta ?? '').toUpperCase()) {
      case 'NC':
        return ('NC', _ChecklistPdfPalette.redLight, _ChecklistPdfPalette.red);
      case 'N/A':
      case 'NA':
        return (
          'N/A',
          _ChecklistPdfPalette.naLight,
          _ChecklistPdfPalette.inkFaint,
        );
      default:
        return (
          'C',
          _ChecklistPdfPalette.greenLight,
          _ChecklistPdfPalette.green,
        );
    }
  }

  pw.Widget _fotoCelda(String path) {
    final f = File(path);
    if (!f.existsSync()) return pw.SizedBox.shrink();
    try {
      return pw.Center(
        child: pw.Container(
          width: 70,
          height: 70,
          margin: const pw.EdgeInsets.only(top: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Image(
            pw.MemoryImage(f.readAsBytesSync()),
            fit: pw.BoxFit.cover,
          ),
        ),
      );
    } catch (_) {
      return pw.SizedBox.shrink();
    }
  }

  pw.Widget _buildApuntesObservaciones(ChecklistReportData data) {
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
              'Apuntes / Observaciones',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              data.apuntesObservaciones.isNotEmpty
                  ? data.apuntesObservaciones
                  : 'Sin observaciones registradas.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildGalleryChunked(List<String> paths) {
    if (paths.isEmpty) return [];
    final widgets = <pw.Widget>[
      pw.SizedBox(height: 14),
      pw.Text(
        'FOTOS GENERALES',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.Divider(),
      pw.SizedBox(height: 8),
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
        debugPrint('❌ Error cargando foto general checklist PDF: $path - $e');
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

  pw.Widget _buildFirma(ChecklistReportData data) {
    return pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (data.firmaImagen != null)
            pw.Image(
              pw.MemoryImage(data.firmaImagen!),
              width: 160,
              height: 55,
              fit: pw.BoxFit.contain,
            )
          else
            pw.SizedBox(width: 160, height: 55),
          pw.Container(
            width: 160,
            height: 1,
            color: PdfColors.black,
            margin: const pw.EdgeInsets.only(top: 4, bottom: 4),
          ),
          pw.Text(
            'Firma',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          if (data.firmaNombre != null && data.firmaNombre!.isNotEmpty)
            pw.Text(
              data.firmaNombre!,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ),
    );
  }
}
