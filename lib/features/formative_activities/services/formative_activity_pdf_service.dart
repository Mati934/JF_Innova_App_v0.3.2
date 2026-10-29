import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/empresa_logo_service.dart';

class FormativeActivityPdfService {
  static const pdfVersion = '0.1.4';
  static const footerText =
      'Generado por Servimaf  |  +56 9 8383 3177  |  v$pdfVersion';
  static const _navy = PdfColor.fromInt(0xFF1B3B6F);
  static const _cyan = PdfColor.fromInt(0xFF20A4BD);
  static const _paleBlue = PdfColor.fromInt(0xFFEAF0F7);
  static const _border = PdfColor.fromInt(0xFFD9E0E8);

  Future<Uint8List> generate({
    required Map<String, dynamic> data,
    required Uint8List? signatureBytes,
    List<String> photoPaths = const [],
  }) async {
    final regular = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final logo = await EmpresaLogoService.instance.getLogoForEmpresa(
      empresaId: data['empresa_id']?.toString(),
      fallbackAsset: null,
    );
    final document = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
    final image = logo == null ? null : pw.MemoryImage(logo);
    final signature = signatureBytes == null
        ? null
        : pw.MemoryImage(signatureBytes);
    final photos = <pw.MemoryImage>[];
    for (final path in photoPaths) {
      // Both previews and official reports use the same local evidence, in order.
      photos.add(pw.MemoryImage(await File(path).readAsBytes()));
    }

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 36),
        ),
        maxPages: 20 + photos.length + _value(data, 'descripcion').length,
        header: (_) => pw.Padding(
          // Retain the full-bleed header while allowing body text to paginate.
          padding: const pw.EdgeInsets.symmetric(horizontal: -36),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                color: _navy,
                padding: const pw.EdgeInsets.fromLTRB(36, 24, 36, 22),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _value(data, 'empresa_nombre'),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: _cyan,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Registro de Actividad\nFormativa',
                            style: pw.TextStyle(
                              fontSize: 23,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 172,
                          height: 48,
                          padding: const pw.EdgeInsets.all(7),
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: image == null
                              ? pw.Text(
                                  _value(data, 'empresa_nombre'),
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: _navy,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                )
                              : pw.Image(image, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          width: 172,
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: _cyan, width: 0.8),
                            borderRadius: pw.BorderRadius.circular(12),
                          ),
                          child: pw.Text(
                            'N° Informe: ${_value(data, 'numero_reporte', fallback: 'Pendiente')}',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Container(height: 4, color: _cyan),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 18),
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _border, width: 0.6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                footerText,
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Pág. ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (_) => [
          _inset(
            pw.Row(
              children: [
                pw.Expanded(
                  child: _summaryCard(
                    'FECHA',
                    _date(data['fecha_realizacion']),
                    'Día de la actividad',
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _summaryCard(
                    'HORARIO',
                    '${_value(data, 'hora_inicio')} - ${_value(data, 'hora_termino')}',
                    'Inicio - término',
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _hoursAndAttendeesCard(
                    hh: '${_decimal(data['hh_con_relator'])} HH',
                    attendees: _value(data, 'asistentes'),
                  ),
                ),
              ],
            ),
            top: 16,
            bottom: 16,
          ),
          _inset(_sectionTitle('DETALLE DE LA ACTIVIDAD'), bottom: 9),
          _inset(_detailCard(data), bottom: 10),
          if (_nonEmpty(data['descripcion'])) ...[
            _inset(_sectionTitle('DESCRIPCIÓN'), bottom: 6),
            pw.RichText(
              text: pw.TextSpan(
                text: _value(data, 'descripcion'),
                style: const pw.TextStyle(fontSize: 9, color: _navy),
              ),
              textAlign: pw.TextAlign.left,
              overflow: pw.TextOverflow.span,
            ),
            pw.SizedBox(height: 8),
          ],
          _inset(_sectionTitle('FIRMA DEL RELATOR'), bottom: 9),
          _inset(_signaturePanel(signature, _value(data, 'relator_nombre'))),
          if (photos.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('REGISTRO FOTOGRÁFICO'),
            pw.SizedBox(height: 8),
            for (var start = 0; start < photos.length; start += 3)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (
                      var index = start;
                      index < start + 3 && index < photos.length;
                      index++
                    )
                      pw.Container(
                        width: 155,
                        height: 155,
                        margin: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColors.grey400,
                            width: 0.5,
                          ),
                        ),
                        child: pw.Image(photos[index], fit: pw.BoxFit.cover),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _summaryCard(
    String label,
    String value,
    String caption, {
    bool highlight = false,
  }) => pw.Container(
    height: 70,
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(
      color: highlight ? _cyan : PdfColors.white,
      border: pw.Border.all(color: highlight ? _cyan : _border, width: 0.8),
      borderRadius: pw.BorderRadius.circular(7),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: highlight ? PdfColors.white : _cyan,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: highlight ? PdfColors.white : _navy,
          ),
        ),
        pw.Text(
          caption,
          style: pw.TextStyle(
            fontSize: 6.5,
            color: highlight ? PdfColors.white : PdfColors.grey600,
          ),
        ),
      ],
    ),
  );

  pw.Widget _hoursAndAttendeesCard({
    required String hh,
    required String attendees,
  }) => pw.Container(
    height: 70,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    decoration: pw.BoxDecoration(
      color: _cyan,
      border: pw.Border.all(color: _cyan, width: 0.8),
      borderRadius: pw.BorderRadius.circular(7),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: _summaryMetric(
            label: 'HORAS-HOMBRE',
            value: hh,
            caption: '',
          ),
        ),
        pw.Container(
          width: 0.6,
          height: 48,
          color: PdfColors.white,
          margin: const pw.EdgeInsets.symmetric(horizontal: 6),
        ),
        pw.Expanded(
          child: _summaryMetric(
            label: 'ASISTENTES /\nOYENTES',
            value: attendees,
            caption: 'Sin relator',
          ),
        ),
      ],
    ),
  );

  pw.Widget _summaryMetric({
    required String label,
    required String value,
    required String caption,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
      pw.Text(
        caption,
        style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white),
      ),
    ],
  );

  pw.Widget _sectionTitle(String title) => pw.Row(
    children: [
      pw.Container(width: 4, height: 16, color: _cyan),
      pw.SizedBox(width: 8),
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _navy,
        ),
      ),
    ],
  );

  pw.Widget _detailCard(Map<String, dynamic> data) => pw.Container(
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _border, width: 0.7),
      borderRadius: pw.BorderRadius.circular(7),
    ),
    child: pw.Column(
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.5),
          children: [
            pw.TableRow(
              children: [
                _detailCell(
                  'ÁREA',
                  _value(
                    data,
                    'area_otro',
                    fallback: _value(data, 'area_nombre', fallback: 'Sin área'),
                  ),
                ),
                _detailCell(
                  'CENTRO',
                  _value(data, 'nombre_centro', fallback: 'Sin centro'),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                _detailCell('TIPO', _activityType(data)),
                _detailCell('RELATOR', _value(data, 'relator_nombre')),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  pw.Widget _detailCell(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            color: _navy,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  pw.Widget _signaturePanel(pw.MemoryImage? signature, String relator) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: _paleBlue,
          border: pw.Border.all(color: _border, width: 0.7),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(
              height: 42,
              width: 180,
              alignment: pw.Alignment.center,
              child: signature == null
                  ? pw.Text(
                      'Sin firma',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    )
                  : pw.Image(signature, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              relator,
              style: pw.TextStyle(
                fontSize: 8,
                color: _navy,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Relator',
              style: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      );

  pw.Widget _inset(pw.Widget child, {double top = 0, double bottom = 0}) =>
      pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(0, top, 0, bottom),
        child: child,
      );

  String _activityType(Map<String, dynamic> data) {
    final type = _value(data, 'actividad_formativa_tipo');
    if (type == 'OTRO') return _value(data, 'tipo_otro', fallback: 'Otro');
    return switch (type) {
      'CHARLA' => 'Charla',
      'SERVICIO' => 'Servicio',
      'CAPACITACION' => 'Capacitación',
      _ => type,
    };
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'Sin fecha';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  String _decimal(Object? value) {
    final number = double.tryParse(value?.toString() ?? '');
    return number == null
        ? '0,00'
        : number.toStringAsFixed(2).replaceAll('.', ',');
  }

  bool _nonEmpty(Object? value) => value?.toString().trim().isNotEmpty == true;

  String _value(
    Map<String, dynamic> data,
    String key, {
    String fallback = '—',
  }) {
    final value = data[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }
}
