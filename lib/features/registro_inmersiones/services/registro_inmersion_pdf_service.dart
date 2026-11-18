import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/empresa_logo_service.dart';
import '../domain/models/registro_inmersion_pdf_data.dart';

/// Versión del generador: todo cambio de contenido o diseño sube su patch.
const String kRegistroInmersionPdfVersion = '0.1.0';

class RegistroInmersionPdfParams {
  final RegistroInmersionPdfData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List? logoBytes;

  RegistroInmersionPdfParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    this.logoBytes,
  });
}

/// Entry point para `compute()`.
Future<Uint8List> generateRegistroInmersionPdfEntryPoint(
  RegistroInmersionPdfParams params,
) => RegistroInmersionPdfService._generar(params);

/// PDF del registro de inmersiones: encabezado con N° propio y N° de la
/// inspección de buceo, tabla por buzo (como el papel), evidencia por buzo,
/// galería general y observación. Sin firmas.
class RegistroInmersionPdfService {
  const RegistroInmersionPdfService();

  static const PdfColor _brand = PdfColor.fromInt(0xFF00507A);
  static const PdfColor _brandLight = PdfColor.fromInt(0xFFE6F0F5);
  static const PdfColor _rojo = PdfColor.fromInt(0xFFC62828);
  static const PdfColor _rojoFondo = PdfColor.fromInt(0xFFFDECEA);

  /// Carga fuentes y logo y genera el PDF en un isolate.
  Future<Uint8List> generar(
    RegistroInmersionPdfData data, {
    String? empresaId,
  }) async {
    final fontReg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    Uint8List? logo;
    try {
      logo = await EmpresaLogoService.instance.getLogoForEmpresa(
        empresaId: empresaId,
        fallbackAsset: 'assets/images/aquachileporfin3.png',
      );
    } catch (_) {}
    return compute(
      generateRegistroInmersionPdfEntryPoint,
      RegistroInmersionPdfParams(
        data: data,
        fontRegular: fontReg.buffer.asUint8List(),
        fontBold: fontBold.buffer.asUint8List(),
        logoBytes: logo,
      ),
    );
  }

  static Future<Uint8List> _generar(RegistroInmersionPdfParams p) async {
    final data = p.data;
    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(p.fontRegular.buffer.asByteData()),
      bold: pw.Font.ttf(p.fontBold.buffer.asByteData()),
    );
    final logo = p.logoBytes != null ? pw.MemoryImage(p.logoBytes!) : null;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 36),
        ),
        header: (_) => _header(data, logo),
        footer: _footer,
        build: (_) => [
          _datos(data),
          pw.SizedBox(height: 12),
          _seccion('Inmersiones (${data.buzos.length} personas)'),
          _tablaBuzos(data),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'Datos extraídos desde bitácoras.',
              style: pw.TextStyle(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ),
          ..._evidenciaPorBuzo(data),
          if (data.observacionGeneral.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _seccion('Observación general'),
            _caja(data.observacionGeneral),
          ],
          ..._galeria(data.galeriaPaths),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _header(RegistroInmersionPdfData d, pw.MemoryImage? logo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 1.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Registro de inmersiones',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _brand,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Inspección de buceo N° ${d.numeroInspeccion}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logo != null) pw.SizedBox(height: 38, child: pw.Image(logo)),
              pw.SizedBox(height: 4),
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
                  'N° ${d.correlativo}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado por Servimaf  |  +56 9 8383 3177  |  v$kRegistroInmersionPdfVersion',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
          ),
          pw.Text(
            'Pág. ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static pw.Widget _seccion(String titulo) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    color: _brand,
    child: pw.Text(
      titulo.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );

  static pw.Widget _caja(String texto) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
    ),
    child: pw.Text(texto, style: const pw.TextStyle(fontSize: 9)),
  );

  static pw.Widget _datos(RegistroInmersionPdfData d) {
    final pares = <List<String>>[
      ['Centro', d.centro],
      ['Fecha', d.fecha],
      ['Contratista', d.contratista],
      ['Profundidad autorizada', d.profundidadAutorizada],
      ['Auditor', d.auditor],
      ['N° inspección de buceo', d.numeroInspeccion],
    ];
    final rows = <pw.TableRow>[];
    for (var i = 0; i < pares.length; i += 2) {
      rows.add(
        pw.TableRow(
          children: [
            _par(pares[i]),
            i + 1 < pares.length ? _par(pares[i + 1]) : pw.SizedBox(),
          ],
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: rows,
    );
  }

  static pw.Widget _par(List<String> par) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '${par[0]}: ',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(
            text: par[1].isEmpty ? '—' : par[1],
            style: const pw.TextStyle(fontSize: 8.5),
          ),
        ],
      ),
    ),
  );

  static pw.Widget _tablaBuzos(RegistroInmersionPdfData d) {
    final head = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: _brand,
    );
    const cuerpo = pw.TextStyle(fontSize: 8);
    pw.Widget celda(String t, {pw.TextStyle? style, PdfColor? fondo}) =>
        pw.Container(
          color: fondo,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(t, style: style ?? cuerpo),
        );

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _brandLight),
        children: [
          celda('N°', style: head),
          celda('Nombre / RUT', style: head),
          celda('Cargo', style: head),
          celda('Prof. máx.', style: head),
          celda('Desde – hasta', style: head),
          celda('Tiempo', style: head),
        ],
      ),
    ];

    for (final b in d.buzos) {
      final rojo = b.marcadoRojo;
      final profStyle = rojo
          ? pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _rojo,
            )
          : cuerpo;
      final nombre = b.rut.isEmpty ? b.nombre : '${b.nombre}\n${b.rut}';

      if (!b.realizoInmersion) {
        rows.add(
          pw.TableRow(
            children: [
              celda('${b.numero}'),
              celda(nombre),
              celda(b.cargo),
              celda('No buceó', style: const pw.TextStyle(fontSize: 8)),
              celda(''),
              celda(''),
            ],
          ),
        );
        continue;
      }

      final varias = b.inmersiones.length > 1;
      rows.add(
        pw.TableRow(
          children: [
            celda('${b.numero}'),
            celda(nombre),
            celda(b.cargo),
            celda(
              b.profundidadMaxima.isEmpty ? '—' : b.profundidadMaxima,
              style: profStyle,
              fondo: rojo ? _rojoFondo : null,
            ),
            celda(
              varias
                  ? '${b.inmersiones.length} inmersiones'
                  : (b.inmersiones.isEmpty
                        ? ''
                        : b.inmersiones.first.desdeHasta),
            ),
            celda(b.tiempoTotal),
          ],
        ),
      );
      if (varias) {
        for (var i = 0; i < b.inmersiones.length; i++) {
          final inm = b.inmersiones[i];
          rows.add(
            pw.TableRow(
              children: [
                celda(''),
                celda(
                  '  Inmersión ${i + 1}',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                  ),
                ),
                celda(''),
                celda(
                  inm.profundidad,
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
                celda(inm.desdeHasta, style: const pw.TextStyle(fontSize: 7.5)),
                celda(inm.tiempo, style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
          );
        }
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.7),
        5: pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  static List<pw.Widget> _evidenciaPorBuzo(RegistroInmersionPdfData d) {
    final conDetalle = d.buzos.where(
      (b) => b.fotos.isNotEmpty || b.nota.isNotEmpty || b.equipo.isNotEmpty,
    );
    if (conDetalle.isEmpty) return const [];
    final out = <pw.Widget>[
      pw.SizedBox(height: 12),
      _seccion('Detalle y evidencia por persona'),
    ];
    for (final b in conDetalle) {
      final fotos = <pw.Widget>[];
      for (final f in b.fotos) {
        final img = _imagen(f.path, 120);
        if (img == null) continue;
        fotos.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 6, top: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                img,
                pw.Text(f.etiqueta, style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ),
        );
      }
      out.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${b.numero}. ${b.nombre} · ${b.cargo}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _brand,
                ),
              ),
              if (b.equipo.isNotEmpty)
                pw.Text(b.equipo, style: const pw.TextStyle(fontSize: 8)),
              if (b.nota.isNotEmpty)
                pw.Text(
                  'Nota: ${b.nota}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              if (fotos.isNotEmpty) pw.Wrap(children: fotos),
            ],
          ),
        ),
      );
    }
    return out;
  }

  static List<pw.Widget> _galeria(List<String> paths) {
    final imgs = paths
        .map((p) => _imagen(p, 155))
        .whereType<pw.Widget>()
        .toList();
    if (imgs.isEmpty) return const [];
    return [
      pw.SizedBox(height: 12),
      _seccion('Galería general'),
      pw.SizedBox(height: 4),
      pw.Wrap(spacing: 6, runSpacing: 6, children: imgs),
    ];
  }

  static pw.Widget? _imagen(String path, double lado) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return pw.Container(
        width: lado,
        height: lado,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Image(
          pw.MemoryImage(f.readAsBytesSync()),
          fit: pw.BoxFit.cover,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Foto no incluida en PDF de inmersiones: $path ($e)');
      return null;
    }
  }
}
