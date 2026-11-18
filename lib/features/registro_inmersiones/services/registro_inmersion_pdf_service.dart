import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/empresa_logo_service.dart';
import '../domain/models/registro_inmersion_pdf_data.dart';

/// Versión del generador: todo cambio de contenido o diseño sube su patch.
const String kRegistroInmersionPdfVersion = '0.1.2';

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
/// inspección de buceo, datos generales, franja de resumen, una ficha por
/// persona con sus fotos al lado (como el papel), observación y galería.
/// Sin firmas.
class RegistroInmersionPdfService {
  const RegistroInmersionPdfService();

  static const PdfColor _brand = PdfColor.fromInt(0xFF00507A);
  static const PdfColor _brandLight = PdfColor.fromInt(0xFFE6F0F5);
  static const PdfColor _rojo = PdfColor.fromInt(0xFFC62828);

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
          margin: const pw.EdgeInsets.fromLTRB(42, 34, 42, 40),
        ),
        header: (_) => _header(data, logo),
        footer: _footer,
        build: (_) => [
          _datos(data),
          _resumen(data),
          pw.SizedBox(height: 12),
          _seccion('Inmersiones por persona'),
          ..._fichas(data),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'Datos extraídos desde bitácoras.',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
          if (data.observacionGeneral.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _seccion('Observación general'),
            pw.SizedBox(height: 6),
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
                  d.numeroInspeccion == null
                      ? 'Sin inspección de buceo vinculada'
                      : 'Inspección de buceo N° ${d.numeroInspeccion}',
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
      titulo,
      style: pw.TextStyle(
        fontSize: 9.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );

  /// Texto largo: va directo en la página para que pueda partirse entre
  /// páginas (un Container lo haría inseparable y el PDF fallaría).
  static pw.Widget _caja(String texto) =>
      pw.Text(
        texto,
        style: const pw.TextStyle(fontSize: 9),
        overflow: pw.TextOverflow.span,
      );

  // --- Escala tipográfica: 7.5 (rótulos) · 9 (cuerpo) · 12 (cifras) · 16 ----

  static const _rotulo = pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700);
  static const _cuerpo = pw.TextStyle(fontSize: 9);

  static pw.Widget _datoApilado(String rotulo, String valor) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(rotulo, style: _rotulo),
      pw.SizedBox(height: 1.5),
      pw.Text(
        valor.isEmpty ? '—' : valor,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );

  /// Datos generales en una retícula de 3 columnas, rótulo arriba y valor
  /// abajo (sin tabla con rejilla).
  static pw.Widget _datos(RegistroInmersionPdfData d) {
    final pares = <List<String>>[
      ['Centro', d.centro],
      ['Contratista', d.contratista],
      ['Fecha', d.fecha],
      ['Profundidad autorizada', d.profundidadAutorizada],
      ['Auditor', d.auditor],
      ['N° inspección de buceo', d.numeroInspeccion ?? 'Sin vincular'],
    ];
    pw.Widget fila(int i) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var j = i; j < i + 3; j++)
            pw.Expanded(
              // Centro · Contratista (largo) · Fecha.
              flex: const [3, 4, 2][j - i],
              child: j < pares.length
                  ? _datoApilado(pares[j][0], pares[j][1])
                  : pw.SizedBox(),
            ),
        ],
      ),
    );
    return pw.Column(children: [fila(0), fila(3)]);
  }

  /// Franja de resumen: lo que se tiene que entender en 30 segundos.
  static pw.Widget _resumen(RegistroInmersionPdfData d) {
    final bucearon = d.buzos.where((b) => b.realizoInmersion).toList();
    double? maxima;
    for (final b in bucearon) {
      final v = double.tryParse(
        b.profundidadMaxima.replaceAll(' m', '').replaceAll(',', '.'),
      );
      if (v != null && (maxima == null || v > maxima)) maxima = v;
    }
    final excedidos = d.buzos.where((b) => b.excede).length;
    final hayAutorizada = d.profundidadAutorizada.isNotEmpty;

    pw.Widget cifra(String rotulo, String valor, {PdfColor? color}) =>
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(rotulo, style: _rotulo),
              pw.SizedBox(height: 2),
              pw.Text(
                valor,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: color ?? _brand,
                ),
              ),
            ],
          ),
        );

    final textoMax = maxima == null
        ? '—'
        : '${maxima.toStringAsFixed(maxima % 1 == 0 ? 0 : 1).replaceAll('.', ',')} m';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: _brandLight,
      child: pw.Row(
        children: [
          cifra('Personas', '${d.buzos.length}'),
          cifra('Bucearon', '${bucearon.length}'),
          cifra('Profundidad máxima', textoMax),
          cifra(
            'Superaron la autorizada',
            hayAutorizada ? '$excedidos' : 'Sin dato',
            color: excedidos > 0 ? _rojo : null,
          ),
        ],
      ),
    );
  }

  /// Una ficha por persona: datos a la izquierda y sus fotos al lado, como el
  /// registro en papel. No se corta entre páginas.
  static List<pw.Widget> _fichas(RegistroInmersionPdfData d) => [
    for (final b in d.buzos) _ficha(b, d.profundidadAutorizada),
  ];

  static pw.Widget _ficha(RegistroInmersionPdfBuzo b, String autorizada) {
    final rojo = b.marcadoRojo;
    final fotos = <pw.Widget>[];
    for (final f in b.fotos.take(3)) {
      final img = _imagen(f.path, 84);
      if (img == null) continue;
      fotos.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              img,
              pw.SizedBox(height: 2),
              pw.Text(f.etiqueta, style: _rotulo),
            ],
          ),
        ),
      );
    }

    final encabezado = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Flexible(
          child: pw.Text(
            '${b.numero}. ${b.nombre}',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _brand,
            ),
          ),
        ),
        if (b.rut.isNotEmpty) ...[
          pw.SizedBox(width: 8),
          pw.Text('RUT ${b.rut}', style: _rotulo),
        ],
        pw.Spacer(),
        pw.Text(b.cargo, style: _rotulo),
      ],
    );

    final cuerpo = <pw.Widget>[];
    if (!b.realizoInmersion) {
      cuerpo.add(
        pw.Text(
          'No buceó',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      );
    } else {
      final prof = b.profundidadMaxima.isEmpty ? '—' : b.profundidadMaxima;
      cuerpo.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Prof. máxima', style: _rotulo),
                  pw.Text(
                    prof,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: rojo ? _rojo : PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
            pw.Expanded(
              child: _datoApilado(
                'Tiempo total',
                b.tiempoTotal.isEmpty ? '—' : b.tiempoTotal,
              ),
            ),
            pw.Expanded(
              child: _datoApilado(
                b.inmersiones.length > 1 ? 'Inmersiones' : 'Desde – hasta',
                b.inmersiones.length > 1
                    ? '${b.inmersiones.length}'
                    : (b.inmersiones.isEmpty
                          ? ''
                          : b.inmersiones.first.desdeHasta),
              ),
            ),
          ],
        ),
      );
      if (!rojo && b.excede) {
        cuerpo.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Superó la profundidad autorizada ($autorizada), no marcado en rojo',
              style: _rotulo,
            ),
          ),
        );
      }
      if (rojo) {
        cuerpo.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Superó la profundidad autorizada ($autorizada)',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _rojo,
              ),
            ),
          ),
        );
      }
      if (b.inmersiones.length > 1) {
        cuerpo.add(pw.SizedBox(height: 4));
        for (var i = 0; i < b.inmersiones.length; i++) {
          final inm = b.inmersiones[i];
          cuerpo.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1.5),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 62,
                    child: pw.Text('Inmersión ${i + 1}', style: _rotulo),
                  ),
                  pw.SizedBox(
                    width: 70,
                    child: pw.Text(inm.desdeHasta, style: _cuerpo),
                  ),
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text(
                      inm.profundidad,
                      style: _cuerpo,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.SizedBox(
                    width: 46,
                    child: pw.Text(
                      inm.tiempo,
                      style: _cuerpo,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    final equipo = <List<String>>[
      if (b.profundimetro.isNotEmpty) ['Profundímetro', b.profundimetro],
      if (b.registrador.isNotEmpty) ['Registrador', b.registrador],
    ];
    if (equipo.isNotEmpty || b.nota.isNotEmpty) {
      cuerpo.add(pw.SizedBox(height: 6));
      for (final e in equipo) {
        cuerpo.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 62, child: pw.Text(e[0], style: _rotulo)),
                pw.Expanded(child: pw.Text(e[1], style: _cuerpo)),
              ],
            ),
          ),
        );
      }
      if (b.nota.isNotEmpty) {
        cuerpo.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 62, child: pw.Text('Nota', style: _rotulo)),
                // La ficha no se parte entre páginas: la nota va acotada.
                pw.Expanded(
                  child: pw.Text(b.nota, style: _cuerpo, maxLines: 8),
                ),
              ],
            ),
          ),
        );
      }
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: rojo ? _rojo : _brand, width: 2.5),
          top: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          right: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          encabezado,
          pw.Divider(color: PdfColors.grey300, thickness: 0.5, height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: cuerpo,
                ),
              ),
              ...fotos,
            ],
          ),
        ],
      ),
    );
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
