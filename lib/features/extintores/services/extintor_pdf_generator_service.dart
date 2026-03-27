import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/models/extintor_report_data.dart';

// ── Parámetros del isolate ────────────────────────────────────────────────────

class ExtintorPdfIsolateParams {
  final ExtintorReportData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List? logoBytes;

  ExtintorPdfIsolateParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    this.logoBytes,
  });
}

// ── Entry point para compute() ────────────────────────────────────────────────

Future<Uint8List> generateExtintorPdfEntryPoint(
  ExtintorPdfIsolateParams params,
) async {
  return await ExtintorPdfGeneratorService()._generateSync(params);
}

// ── Servicio de generación ────────────────────────────────────────────────────

class ExtintorPdfGeneratorService {
  static const _azul = PdfColor.fromInt(0xFF1565C0);
  static const _verde = PdfColor.fromInt(0xFF2E7D32);
  static const _rojo = PdfColor.fromInt(0xFFC62828);
  static const _grisClaro = PdfColor.fromInt(0xFFF5F5F5);
  static const _grisLinea = PdfColor.fromInt(0xFFE0E0E0);

  Future<Uint8List> _generateSync(ExtintorPdfIsolateParams params) async {
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
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          _buildDatosGenerales(data),
          pw.SizedBox(height: 16),
          ..._buildExtintores(data),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  pw.Widget _buildHeader(pw.MemoryImage? logo, ExtintorReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _azul, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (logo != null)
            pw.Image(logo, width: 80, height: 40, fit: pw.BoxFit.contain)
          else
            pw.SizedBox(width: 80),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'INSPECCIÓN DE EXTINTORES',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _azul,
                ),
              ),
              pw.Text(
                'JF Innova Ltda.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Text(
            'Fecha: ${data.fecha}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _grisLinea)),
      ),
      child: pw.Text(
        'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  // ── Datos generales ─────────────────────────────────────────────────────────

  pw.Widget _buildDatosGenerales(ExtintorReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _grisClaro,
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _titulo('INFORMACIÓN GENERAL'),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              Expanded(child: _dato('Lugar', data.centro)),
              Expanded(child: _dato('Jefatura a Cargo', data.jefaturaCargo)),
            ],
          ),
          pw.Row(
            children: [
              Expanded(child: _dato('Fecha', data.fecha)),
              Expanded(child: _dato('Hora Inicio', data.horaInicio)),
              Expanded(child: _dato('Hora Término', data.horaTermino)),
            ],
          ),
          if (data.profesional.isNotEmpty) _dato('Inspector', data.profesional),
        ],
      ),
    );
  }

  // ── Lista de extintores ─────────────────────────────────────────────────────

  List<pw.Widget> _buildExtintores(ExtintorReportData data) {
    final widgets = <pw.Widget>[
      _titulo('RESULTADOS POR EXTINTOR'),
      pw.SizedBox(height: 8),
    ];

    for (final extintor in data.extintores) {
      widgets.add(_buildExtintorItem(extintor));
      widgets.add(pw.SizedBox(height: 6));

      // Galería de fotos del extintor
      if (extintor.fotoPaths.isNotEmpty) {
        widgets.addAll(_buildFotosExtintor(extintor));
        widgets.add(pw.SizedBox(height: 6));
      }
    }

    // Resumen final
    widgets.add(pw.SizedBox(height: 8));
    widgets.add(_buildResumen(data));

    return widgets;
  }

  pw.Widget _buildExtintorItem(ExtintorResumenItem extintor) {
    final titulo = extintor.matricula?.isNotEmpty == true
        ? 'Extintor #${extintor.numero} — ${extintor.matricula}'
        : 'Extintor #${extintor.numero}';

    if (extintor.todosCumplen) {
      // ✅ Todo conforme → fila compacta verde
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFE8F5E9),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFA5D6A7)),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              '✓',
              style: pw.TextStyle(
                color: _verde,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              titulo,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.Spacer(),
            pw.Text(
              'Todos los ${extintor.totalPuntos} puntos conformes',
              style: const pw.TextStyle(color: _verde, fontSize: 9),
            ),
          ],
        ),
      );
    }

    // ⚠️ Hay NC → tabla detallada solo con los NC
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFFFCDD2)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Cabecera del extintor
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFEBEE),
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  '⚠',
                  style: const pw.TextStyle(color: _rojo, fontSize: 12),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  titulo,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  '${extintor.puntosNC.length} No Conformidad(es)',
                  style: const pw.TextStyle(color: _rojo, fontSize: 9),
                ),
              ],
            ),
          ),
          // Tabla de NC
          pw.Table(
            border: pw.TableBorder(
              top: const pw.BorderSide(color: _grisLinea),
              horizontalInside: const pw.BorderSide(color: _grisLinea),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(3),
            },
            children: [
              // Header tabla
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _grisClaro),
                children: [
                  _celdaHeader('Punto de Inspección'),
                  _celdaHeader('Observación'),
                ],
              ),
              // Filas NC
              ...extintor.puntosNC.map(
                (nc) => pw.TableRow(
                  children: [
                    _celda(nc.pregunta),
                    _celda(nc.observacion ?? '—'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildFotosExtintor(ExtintorResumenItem extintor) {
    final fotosValidas = extintor.fotoPaths
        .where((p) => File(p).existsSync())
        .toList();
    if (fotosValidas.isEmpty) return [];

    final titulo = extintor.matricula?.isNotEmpty == true
        ? 'Fotos — Extintor #${extintor.numero} (${extintor.matricula})'
        : 'Fotos — Extintor #${extintor.numero}';

    return [
      pw.Text(
        titulo,
        style: pw.TextStyle(
          fontSize: 9,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.grey700,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: fotosValidas.map((p) {
          try {
            final bytes = File(p).readAsBytesSync();
            return pw.Image(
              pw.MemoryImage(bytes),
              width: 120,
              height: 90,
              fit: pw.BoxFit.cover,
            );
          } catch (_) {
            return pw.SizedBox();
          }
        }).toList(),
      ),
    ];
  }

  pw.Widget _buildResumen(ExtintorReportData data) {
    final total = data.extintores.length;
    final conformes = data.extintores.where((e) => e.todosCumplen).length;
    final conNC = total - conformes;
    final totalNC = data.extintores.fold<int>(
      0,
      (s, e) => s + e.puntosNC.length,
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _grisClaro,
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _titulo('RESUMEN GENERAL'),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              Expanded(child: _dato('Total Extintores', '$total')),
              Expanded(child: _dato('Conformes', '$conformes', color: _verde)),
              Expanded(
                child: _dato(
                  'Con NC',
                  '$conNC',
                  color: conNC > 0 ? _rojo : _verde,
                ),
              ),
              Expanded(
                child: _dato(
                  'Total NC',
                  '$totalNC',
                  color: totalNC > 0 ? _rojo : _verde,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  pw.Widget _titulo(String texto) => pw.Text(
    texto,
    style: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: _azul,
      letterSpacing: 0.5,
    ),
  );

  pw.Widget _dato(String label, String valor, {PdfColor? color}) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
      pw.Text(
        valor,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: color ?? PdfColors.black,
        ),
      ),
    ],
  );

  pw.Widget _celdaHeader(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      texto,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _celda(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(texto, style: const pw.TextStyle(fontSize: 8)),
  );
}

pw.Widget Expanded({required pw.Widget child}) =>
    pw.Expanded(flex: 1, child: child);
