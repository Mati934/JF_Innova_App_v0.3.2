import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models/buceo_equipment_pdf_data.dart';

class BuceoEquipmentPdfIsolateParams {
  final BuceoEquipmentPdfData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List? logoBytes;

  const BuceoEquipmentPdfIsolateParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    this.logoBytes,
  });
}

Future<Uint8List> generateBuceoEquipmentPdfEntryPoint(
  BuceoEquipmentPdfIsolateParams params,
) async {
  final service = BuceoEquipmentPdfService();
  return service.generateSync(params);
}

class BuceoEquipmentPdfService {
  Future<Uint8List> generateSync(BuceoEquipmentPdfIsolateParams params) async {
    final pdf = pw.Document();
    final data = params.data;

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(params.fontRegular.buffer.asByteData()),
      bold: pw.Font.ttf(params.fontBold.buffer.asByteData()),
    );

    pw.MemoryImage? logo;
    if (params.logoBytes != null) {
      logo = pw.MemoryImage(params.logoBytes!);
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
        ),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          _header(data, logo),
          pw.SizedBox(height: 10),
          _resumenCumplimiento(data),
          pw.SizedBox(height: 10),
          _datosGenerales(data),
          pw.SizedBox(height: 10),
          _sectionTitle('MATRIZ DE COMPRESORES'),
          _compresores(data),
          pw.SizedBox(height: 10),
          _sectionTitle('BUZOS'),
          _buzos(data),
          pw.SizedBox(height: 10),
          ..._checklist(data),
          ..._galeria(data.galeriaPaths),
          pw.SizedBox(height: 14),
          _firmas(data.firmas),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _header(BuceoEquipmentPdfData data, pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                data.tituloInforme,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                data.subtituloInforme,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                data.nombreLista,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (logo != null)
              pw.SizedBox(
                width: 90,
                height: 32,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Nro informe: ${data.numeroInforme}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              'Fecha: ${data.fecha}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _resumenCumplimiento(BuceoEquipmentPdfData data) {
    final total = data.totalCumple + data.totalNoCumple + data.totalNoAplica;
    String pct(int value) {
      if (total <= 0) return '0%';
      return '${((value / total) * 100).round()}%';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _kpi(
            'Cumple',
            '${data.totalCumple} (${pct(data.totalCumple)})',
            PdfColors.green700,
          ),
          _kpi(
            'No cumple',
            '${data.totalNoCumple} (${pct(data.totalNoCumple)})',
            PdfColors.red700,
          ),
          _kpi(
            'No aplica',
            '${data.totalNoAplica} (${pct(data.totalNoAplica)})',
            PdfColors.blueGrey700,
          ),
        ],
      ),
    );
  }

  pw.Widget _kpi(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: color,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  pw.Widget _datosGenerales(BuceoEquipmentPdfData data) {
    return _tableSection('DATOS GENERALES', [
      _row(
        'Empresa',
        data.empresa.isEmpty ? data.empresaProveedor : data.empresa,
      ),
      _row('Area', data.area),
      _row('Region', data.region),
      _row('Supervisor/Jefatura', data.supervisorJefatura),
      _row('Embarcacion', data.embarcacion),
      _row('Lugar de faena', data.lugarFaena),
      _row('Profesional', data.profesional),
      _row('Correo profesional', data.profesionalCorreo),
      _row('Fono profesional', data.profesionalFono),
    ]);
  }

  pw.Widget _compresores(BuceoEquipmentPdfData data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Compresor', bold: true),
            _cell('Matricula', bold: true),
            _cell('Vigencia', bold: true),
            _cell('PH', bold: true),
            _cell('N buzos', bold: true),
          ],
        ),
        ...data.compresores.map(
          (c) => pw.TableRow(
            children: [
              _cell(c.nombre),
              _cell(c.matricula.isEmpty ? '-' : c.matricula),
              _cell(c.vigencia.isEmpty ? '-' : c.vigencia),
              _cell(c.ph.isEmpty ? '-' : c.ph),
              _cell(c.buzosCargo.isEmpty ? '-' : c.buzosCargo),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buzos(BuceoEquipmentPdfData data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2.8),
        2: const pw.FlexColumnWidth(1.8),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Buzo', bold: true),
            _cell('Nombre', bold: true),
            _cell('Matricula', bold: true),
            _cell('Prof.', bold: true),
          ],
        ),
        ...data.buzos.map(
          (b) => pw.TableRow(
            children: [
              _cell(b.titulo),
              _cell(b.nombre.isEmpty ? '-' : b.nombre),
              _cell(b.matricula.isEmpty ? '-' : b.matricula),
              _cell(b.profundidad.isEmpty ? '-' : b.profundidad),
            ],
          ),
        ),
      ],
    );
  }

  List<pw.Widget> _checklist(BuceoEquipmentPdfData data) {
    if (data.checklistItems.isEmpty) {
      return [
        _sectionTitle('CHECKLIST'),
        pw.Text(
          'Sin preguntas configuradas.',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ];
    }

    final grouped = <String, List<BuceoPdfChecklistItem>>{};
    for (final i in data.checklistItems) {
      grouped.putIfAbsent(i.categoria, () => []).add(i);
    }

    final widgets = <pw.Widget>[_sectionTitle('CHECKLIST')];
    int contador = 1;

    for (final entry in grouped.entries) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const pw.EdgeInsets.only(top: 6),
          color: PdfColors.blue50,
          child: pw.Text(
            entry.key.toUpperCase(),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(20),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(40),
            3: const pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('N', bold: true),
                _cell('Pregunta', bold: true),
                _cell('Estado', bold: true),
                _cell('Obs/Foto', bold: true),
              ],
            ),
            ...entry.value.map((item) {
              pw.Widget? foto;
              if (item.fotoPath != null) {
                final f = File(item.fotoPath!);
                if (f.existsSync()) {
                  try {
                    foto = pw.Container(
                      width: 70,
                      height: 70,
                      margin: const pw.EdgeInsets.only(top: 3),
                      child: pw.Image(
                        pw.MemoryImage(f.readAsBytesSync()),
                        fit: pw.BoxFit.cover,
                      ),
                    );
                  } catch (_) {}
                }
              }

              final row = pw.TableRow(
                children: [
                  _cell('${contador++}'),
                  _cell(item.pregunta),
                  _cell(item.respuesta),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (item.observacion.isNotEmpty)
                          pw.Text(
                            item.observacion,
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        if (foto != null) foto,
                      ],
                    ),
                  ),
                ],
              );
              return row;
            }),
          ],
        ),
      );
    }

    return widgets;
  }

  List<pw.Widget> _galeria(List<String> paths) {
    if (paths.isEmpty) return [];

    final widgets = <pw.Widget>[
      pw.SizedBox(height: 10),
      _sectionTitle('GALERIA GENERAL'),
    ];

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Foto ${i + 1}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 180,
                  width: double.infinity,
                  child: pw.Image(
                    pw.MemoryImage(file.readAsBytesSync()),
                    fit: pw.BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
        );
      } catch (_) {}
    }

    return widgets;
  }

  pw.Widget _firmas(List<BuceoPdfFirma> firmas) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('FIRMAS'),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: firmas.map(_firma).toList(),
        ),
      ],
    );
  }

  pw.Widget _firma(BuceoPdfFirma firma) {
    return pw.Column(
      children: [
        if (firma.imagen != null)
          pw.Image(
            pw.MemoryImage(firma.imagen!),
            width: 130,
            height: 50,
            fit: pw.BoxFit.contain,
          )
        else
          pw.SizedBox(width: 130, height: 50),
        pw.Container(width: 130, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(
          firma.rol,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        if ((firma.nombre ?? '').isNotEmpty)
          pw.Text(firma.nombre!, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'JF Innova - Inspeccion de equipamiento de buceo',
            style: const pw.TextStyle(fontSize: 7),
          ),
          pw.Text(
            'Pag ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _tableSection(String title, List<pw.Widget> rows) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [_sectionTitle(title), ...rows],
      ),
    );
  }

  pw.Widget _row(String left, String right) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                left,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                right.isEmpty ? '-' : right,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
