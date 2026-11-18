import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/models/prosesso_extintor_state.dart' show EstadoPuntoProsesso;
import '../domain/models/prosesso_report_data.dart';

/// Resultado de generar ambos PDFs en una pasada
class ProsessoPdfBundle {
  final Uint8List registroBytes;
  final Uint8List certificadoBytes;
  const ProsessoPdfBundle({
    required this.registroBytes,
    required this.certificadoBytes,
  });
}

class ProsessoPdfIsolateParams {
  final ProsessoReportData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List? logoBytes;
  final Uint8List? firmaBytes;
  // Mapa fotoPath -> bytes (cargado fuera del isolate).
  final Map<String, Uint8List> fotosBytes;

  const ProsessoPdfIsolateParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    this.logoBytes,
    this.firmaBytes,
    this.fotosBytes = const {},
  });
}

/// Punto de entrada para `compute()` - genera ambos PDFs en paralelo.
Future<ProsessoPdfBundle> generateProsessoPdfsEntryPoint(
  ProsessoPdfIsolateParams params,
) async {
  final svc = ProsessoPdfService();
  final results = await Future.wait([
    svc._buildRegistro(params),
    svc._buildCertificado(params),
  ]);
  return ProsessoPdfBundle(
    registroBytes: results[0],
    certificadoBytes: results[1],
  );
}

/// Carga assets de fonts/logo/fotos desde el isolate principal.
class ProsessoPdfAssets {
  static const _fallbackLogos = ['assets/images/prosesso_logo.png'];

  static Future<ProsessoPdfIsolateParams> build(ProsessoReportData data) async {
    final fontReg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');

    Uint8List? logo;
    for (final path in _fallbackLogos) {
      try {
        final b = await rootBundle.load(path);
        logo = b.buffer.asUint8List();
        break;
      } catch (_) {}
    }

    // Pre-cargar fotos desde disco para evitar I/O en el isolate.
    final fotosBytes = <String, Uint8List>{};
    for (final ext in data.extintores) {
      for (final p in ext.fotoPaths) {
        if (fotosBytes.containsKey(p)) continue;
        try {
          final f = File(p);
          if (await f.exists()) {
            fotosBytes[p] = await f.readAsBytes();
          }
        } catch (_) {}
      }
    }

    return ProsessoPdfIsolateParams(
      data: data,
      fontRegular: fontReg.buffer.asUint8List(),
      fontBold: fontBold.buffer.asUint8List(),
      logoBytes: logo,
      firmaBytes: data.signatureBytes,
      fotosBytes: fotosBytes,
    );
  }
}

class ProsessoPdfService {
  // Versión interna del FORMATO del PDF (independiente de la versión de la app).
  // Subir solo cuando se cambian estilos/estructura del documento generado.
  static const String _pdfVersion = '1.0';
  static const String _servimafContacto =
      'Generado por Servimaf  |  +56 9 8383 3177  |  PDF v$_pdfVersion';

  // Paleta institucional Prosesso
  static const _rojo = PdfColor.fromInt(0xFFC8102E);
  static const _rojoSuave = PdfColor.fromInt(0xFFFDECEC);
  static const _grisLinea = PdfColor.fromInt(0xFFE0E0E0);
  static const _grisFondo = PdfColor.fromInt(0xFFF7F7F7);
  static const _grisTexto = PdfColor.fromInt(0xFF555555);
  static const _verde = PdfColor.fromInt(0xFF2E7D32);
  static const _verdeSuave = PdfColor.fromInt(0xFFE8F5E9);
  static const _ambar = PdfColor.fromInt(0xFFEF6C00);
  static const _azul = PdfColor.fromInt(0xFF1565C0);

  pw.ThemeData _theme(ProsessoPdfIsolateParams p) => pw.ThemeData.withFont(
    base: pw.Font.ttf(p.fontRegular.buffer.asByteData()),
    bold: pw.Font.ttf(p.fontBold.buffer.asByteData()),
  );

  pw.MemoryImage? _logo(ProsessoPdfIsolateParams p) =>
      p.logoBytes != null ? pw.MemoryImage(p.logoBytes!) : null;

  pw.MemoryImage? _firma(ProsessoPdfIsolateParams p) =>
      p.firmaBytes != null ? pw.MemoryImage(p.firmaBytes!) : null;

  // ─────────────────────────────────────────────────────────────────────────
  // PDF 1: REGISTRO DE MANTENCIÓN - A4 portrait, portada + tarjetas
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List> _buildRegistro(ProsessoPdfIsolateParams p) async {
    final pdf = pw.Document();
    final data = p.data;
    final logo = _logo(p);
    final stats = _Stats.from(data);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 300,
        pageTheme: pw.PageTheme(
          theme: _theme(p),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        ),
        header: (ctx) =>
            ctx.pageNumber == 1 ? pw.SizedBox() : _miniHeader(logo, data),
        footer: (ctx) => _footerRegistro(ctx),
        build: (_) => [
          // ── Portada ────────────────────────────────────────────────────
          _portadaRegistro(logo, data),
          pw.SizedBox(height: 14),
          _bloqueClienteServicio(data),
          pw.SizedBox(height: 12),
          _resumenChips(stats),
          pw.SizedBox(height: 6),
          if (stats.conNc > 0) ...[
            pw.SizedBox(height: 6),
            _bannerHallazgos(stats),
          ],
          pw.SizedBox(height: 14),
          // ── Detalle por extintor ──────────────────────────────────────
          _seccionTitulo('DETALLE POR EXTINTOR', _rojo),
          pw.SizedBox(height: 8),
          for (var i = 0; i < data.extintores.length; i++) ...[
            _extintorCard(data.extintores[i], p.fotosBytes),
            if (i < data.extintores.length - 1) pw.SizedBox(height: 10),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _portadaRegistro(pw.MemoryImage? logo, ProsessoReportData d) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_rojo, PdfColor.fromInt(0xFF8B0A1F)],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 78,
              height: 64,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 78,
              height: 64,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'PROSESSO',
                style: pw.TextStyle(
                  color: _rojo,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'REGISTRO DE MANTENCIÓN',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Servicio de Extintores',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Nº',
                  style: pw.TextStyle(fontSize: 8, color: _grisTexto),
                ),
                pw.Text(
                  d.certNumero.isNotEmpty ? d.certNumero : '-',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _rojo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _miniHeader(pw.MemoryImage? logo, ProsessoReportData d) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _rojo, width: 1.5)),
      ),
      child: pw.Row(
        children: [
          if (logo != null)
            pw.Image(logo, width: 36, height: 24, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              'Registro de Mantención - ${d.clienteNombre}',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _grisTexto,
              ),
            ),
          ),
          pw.Text(
            'Nº ${d.certNumero}',
            style: const pw.TextStyle(fontSize: 9, color: _grisTexto),
          ),
        ],
      ),
    );
  }

  pw.Widget _bloqueClienteServicio(ProsessoReportData d) {
    pw.Widget item(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 7,
            color: _grisTexto,
            letterSpacing: 0.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value.isNotEmpty ? value : '-',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _grisFondo,
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 3, child: item('Cliente', d.clienteNombre)),
              pw.Expanded(
                flex: 4,
                child: item('Dirección', d.clienteDireccion),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: item('Fecha de Servicio', d.fechaServicio)),
              pw.Expanded(child: item('Realizado por', d.realizadoPor)),
              pw.Expanded(child: item('Tipo de Servicio', d.tipoServicio)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _resumenChips(_Stats s) {
    pw.Widget chip(String label, String value, PdfColor c, PdfColor bg) =>
        pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 3),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: pw.BoxDecoration(
              color: bg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: c, width: 0.6),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: c,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: c,
                    letterSpacing: 0.4,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );

    return pw.Row(
      children: [
        chip(
          'TOTAL',
          s.total.toString(),
          _azul,
          const PdfColor.fromInt(0xFFE3F2FD),
        ),
        chip('CONFORMES', s.conformes.toString(), _verde, _verdeSuave),
        chip(
          'CON HALLAZGOS',
          s.conNc.toString(),
          s.conNc > 0 ? _rojo : _grisTexto,
          s.conNc > 0 ? _rojoSuave : _grisFondo,
        ),
        chip(
          'TOTAL NC',
          s.totalNc.toString(),
          s.totalNc > 0 ? _ambar : _grisTexto,
          s.totalNc > 0 ? const PdfColor.fromInt(0xFFFFF3E0) : _grisFondo,
        ),
      ],
    );
  }

  pw.Widget _bannerHallazgos(_Stats s) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _rojoSuave,
        border: pw.Border(left: pw.BorderSide(color: _rojo, width: 3)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 18,
            height: 18,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
              color: _rojo,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Text(
              '!',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              'Se detectaron ${s.totalNc} hallazgo(s) en ${s.conNc} extintor(es). Revisar el detalle individual.',
              style: pw.TextStyle(
                fontSize: 9.5,
                color: _rojo,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _seccionTitulo(String titulo, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 14,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          titulo,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// Tarjeta visual por extintor - header con resultado, datos clave, checklist y fotos.
  pw.Widget _extintorCard(
    ExtintorProsessoResumen e,
    Map<String, Uint8List> fotosBytes,
  ) {
    final ncPuntos = e.puntos
        .where((p) => p.estado == EstadoPuntoProsesso.noCumple)
        .toList();
    final esConforme = ncPuntos.isEmpty;
    final headerColor = esConforme ? _verde : _rojo;
    final headerBg = esConforme ? _verdeSuave : _rojoSuave;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header de la tarjeta
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 26,
                  height: 26,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: headerColor,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Text(
                    '${e.numero}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Extintor #${e.numero}'
                        '${(e.tipo ?? '').isNotEmpty ? ' • ${e.tipo}' : ''}'
                        '${(e.peso ?? '').isNotEmpty ? ' ${e.peso}' : ''}'
                        '${(e.kg ?? '').isNotEmpty ? ' ${e.kg}' : ''}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: headerColor,
                        ),
                      ),
                      if ((e.planta ?? '').isNotEmpty ||
                          (e.ubicacion ?? '').isNotEmpty)
                        pw.Text(
                          [
                            if ((e.planta ?? '').isNotEmpty) e.planta!,
                            if ((e.ubicacion ?? '').isNotEmpty) e.ubicacion!,
                          ].join(' / '),
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: _grisTexto,
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: pw.BoxDecoration(
                    color: headerColor,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(10),
                    ),
                  ),
                  child: pw.Text(
                    esConforme ? 'CONFORME' : '${ncPuntos.length} NC',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Datos
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _datosExtintor(e),
                pw.SizedBox(height: 10),
                _checklistExtintor(e),
                if ((e.observaciones ?? '').trim().isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _observacionesBox(e.observaciones!.trim()),
                ],
                if (e.fotoPaths.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  _fotosExtintor(e.fotoPaths, fotosBytes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _datosExtintor(ExtintorProsessoResumen e) {
    pw.Widget kv(String k, String? v) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$k: ',
              style: pw.TextStyle(fontSize: 8, color: _grisTexto),
            ),
            pw.TextSpan(
              text: (v ?? '').isNotEmpty ? v! : '-',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    final filas = <List<pw.Widget>>[
      [kv('Sector', e.ubicacionSector), kv('Ubicación 2', e.ubicacion2)],
      [kv('Certificado', e.certificado), kv('Año', e.anio?.toString())],
      [kv('Vencimiento', e.fechaVencimiento), kv('Tipo', e.tipo)],
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _grisFondo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(1),
          1: pw.FlexColumnWidth(1),
        },
        children: filas.map((row) => pw.TableRow(children: row)).toList(),
      ),
    );
  }

  pw.Widget _checklistExtintor(ExtintorProsessoResumen e) {
    final puntos = e.puntos;
    if (puntos.isEmpty) return pw.SizedBox();

    pw.Widget badge(EstadoPuntoProsesso? estado) {
      PdfColor color;
      String txt;
      switch (estado) {
        case EstadoPuntoProsesso.cumple:
          color = _verde;
          txt = 'C';
          break;
        case EstadoPuntoProsesso.noCumple:
          color = _rojo;
          txt = 'NC';
          break;
        case EstadoPuntoProsesso.noAplica:
          color = _grisTexto;
          txt = 'N/A';
          break;
        default:
          color = const PdfColor.fromInt(0xFFBDBDBD);
          txt = '-';
      }
      return pw.Container(
        width: 22,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Text(
          txt,
          style: pw.TextStyle(
            fontSize: 7,
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    pw.Widget item(PuntoEstadoResumenProsesso p) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Row(
        children: [
          badge(p.estado),
          pw.SizedBox(width: 5),
          pw.Expanded(
            child: pw.Text(
              p.pregunta,
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
        ],
      ),
    );

    // Grid 3 columnas para compactar
    final filas = <pw.TableRow>[];
    for (var i = 0; i < puntos.length; i += 3) {
      final a = puntos[i];
      final b = i + 1 < puntos.length ? puntos[i + 1] : null;
      final c = i + 2 < puntos.length ? puntos[i + 2] : null;
      filas.add(
        pw.TableRow(
          children: [
            item(a),
            b != null ? item(b) : pw.SizedBox(),
            c != null ? item(c) : pw.SizedBox(),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CHECKLIST',
          style: pw.TextStyle(
            fontSize: 7.5,
            color: _grisTexto,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
          },
          children: filas,
        ),
      ],
    );
  }

  pw.Widget _observacionesBox(String texto) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFFDE7),
        border: pw.Border(left: pw.BorderSide(color: _ambar, width: 2.5)),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: 'Observaciones: ',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _ambar,
              ),
            ),
            pw.TextSpan(text: texto, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  pw.Widget _fotosExtintor(
    List<String> paths,
    Map<String, Uint8List> fotosBytes,
  ) {
    final disponibles = paths
        .where((p) => fotosBytes.containsKey(p))
        .take(6) // Máximo 6 fotos por extintor para mantener limpio
        .toList();
    if (disponibles.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'EVIDENCIA FOTOGRÁFICA',
          style: pw.TextStyle(
            fontSize: 7.5,
            color: _grisTexto,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Wrap(
          spacing: 5,
          runSpacing: 5,
          children: disponibles.map((p) {
            return pw.Container(
              width: 95,
              height: 70,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _grisLinea),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.ClipRRect(
                horizontalRadius: 3,
                verticalRadius: 3,
                child: pw.Image(
                  pw.MemoryImage(fotosBytes[p]!),
                  fit: pw.BoxFit.cover,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF 2: CERTIFICADO DE SERVICIO - A4 portrait, oficial, firma dinámica
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List> _buildCertificado(ProsessoPdfIsolateParams p) async {
    final pdf = pw.Document();
    final data = p.data;
    final logo = _logo(p);
    final firma = _firma(p);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 60,
        pageTheme: pw.PageTheme(
          theme: _theme(p),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 32),
        ),
        footer: (ctx) => _footer(ctx),
        build: (_) => [
          _certCabecera(logo, data),
          pw.SizedBox(height: 18),
          _certTitulo(data),
          pw.SizedBox(height: 16),
          _certInfoCliente(data),
          pw.SizedBox(height: 14),
          _certInfoServicio(data),
          pw.SizedBox(height: 14),
          _seccionTitulo('EXTINTORES INTERVENIDOS', _rojo),
          pw.SizedBox(height: 8),
          _certTablaExtintores(data),
          pw.SizedBox(height: 16),
          _certNormas(),
          pw.SizedBox(height: 14),
          _certDeclaracion(),
          pw.SizedBox(height: 30),
          _certFirma(firma, data),
          pw.SizedBox(height: 14),
          _certNota(),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _certCabecera(pw.MemoryImage? logo, ProsessoReportData d) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null)
          pw.Container(
            width: 70,
            height: 50,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            width: 70,
            height: 50,
            color: _rojo,
            alignment: pw.Alignment.center,
            child: pw.Text(
              'PROSESSO',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Prosesso',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _rojo,
                ),
              ),
              pw.Text(
                'Servicio Técnico de Extintores',
                style: const pw.TextStyle(fontSize: 9, color: _grisTexto),
              ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _rojo, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'CERTIFICADO Nº',
                style: pw.TextStyle(fontSize: 7, color: _grisTexto),
              ),
              pw.Text(
                d.certNumero.isNotEmpty ? d.certNumero : '-',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _rojo,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _certTitulo(ProsessoReportData d) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'CERTIFICADO DE SERVICIO',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Mantenimiento de Extintores Portátiles',
            style: pw.TextStyle(fontSize: 11, color: _grisTexto),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _grisFondo,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              d.dsOrdinario,
              style: pw.TextStyle(
                fontSize: 9,
                color: _grisTexto,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _certInfoCliente(ProsessoReportData d) {
    return _infoBlock('CLIENTE', [
      ['Nombre', d.clienteNombre],
      ['Dirección', d.clienteDireccion],
    ]);
  }

  pw.Widget _certInfoServicio(ProsessoReportData d) {
    return _infoBlock('DETALLE DEL SERVICIO', [
      ['Tipo de Servicio', d.tipoServicio],
      ['Fecha de Servicio', d.fechaServicio],
      ['Realizado por', d.realizadoPor],
      ['Cantidad de Extintores', d.extintores.length.toString()],
    ]);
  }

  pw.Widget _infoBlock(String titulo, List<List<String>> filas) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: _grisFondo,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              titulo,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _grisTexto,
                letterSpacing: 0.5,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: pw.Column(
              children: filas.map((f) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 110,
                        child: pw.Text(
                          '${f[0]}:',
                          style: pw.TextStyle(fontSize: 9.5, color: _grisTexto),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          f[1].isNotEmpty ? f[1] : '-',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _certTablaExtintores(ProsessoReportData d) {
    final headers = ['#', 'UBICACIÓN', 'TIPO', 'PESO', 'AÑO', 'CERTIFICADO'];
    final rows = <List<String>>[];
    for (var i = 0; i < d.extintores.length; i++) {
      final e = d.extintores[i];
      final ubicParts = <String>[
        if ((e.planta ?? '').isNotEmpty) e.planta!,
        if ((e.ubicacion ?? '').isNotEmpty) e.ubicacion!,
        if ((e.ubicacionSector ?? '').isNotEmpty) e.ubicacionSector!,
      ];
      final ubicacion = ubicParts.isEmpty ? '-' : ubicParts.join(' / ');
      final pesoTxt = [
        if ((e.peso ?? '').isNotEmpty) e.peso!,
        if ((e.kg ?? '').isNotEmpty) e.kg!,
      ].join(' ');
      rows.add([
        (i + 1).toString(),
        ubicacion,
        e.tipo ?? '-',
        pesoTxt.isEmpty ? '-' : pesoTxt,
        e.anio?.toString() ?? '-',
        e.certificado ?? '-',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _rojo),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      border: pw.TableBorder.all(color: _grisLinea, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: _grisFondo),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1.6),
      },
    );
  }

  pw.Widget _certNormas() {
    pw.Widget bullet(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, top: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4, right: 6),
            width: 3,
            height: 3,
            decoration: const pw.BoxDecoration(
              color: _rojo,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              t,
              style: const pw.TextStyle(fontSize: 9, color: _grisTexto),
            ),
          ),
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _seccionTitulo('NORMAS APLICADAS', _rojo),
        pw.SizedBox(height: 4),
        bullet('NFPA 10 - Norma para extintores portátiles de incendio.'),
        bullet(
          'NCh 934/1.Of2003 - Extintores portátiles: terminología y definiciones.',
        ),
        bullet(
          'NCh 934/2.Of2003 - Extintores portátiles: selección y ubicación.',
        ),
        bullet(
          'SOLAS - Convenio Internacional para la Seguridad de la Vida Humana en el Mar.',
        ),
        bullet(
          'NCh 2114.Of2003 - Seguridad contra incendios en buques chilenos.',
        ),
      ],
    );
  }

  pw.Widget _certDeclaracion() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _grisFondo,
        border: pw.Border(left: pw.BorderSide(color: _rojo, width: 2.5)),
      ),
      child: pw.Text(
        'Se certifica que los extintores detallados en el presente documento han '
        'sido sometidos al servicio de mantenimiento conforme a las normas y '
        'regulaciones vigentes, encontrándose en condiciones operativas para su uso.',
        style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  pw.Widget _certFirma(pw.MemoryImage? firma, ProsessoReportData d) {
    final nombre = d.realizadoPor.trim().isNotEmpty
        ? d.realizadoPor.trim()
        : 'Técnico responsable';
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Container(
            width: 220,
            height: 70,
            alignment: pw.Alignment.center,
            child: firma != null
                ? pw.Image(firma, fit: pw.BoxFit.contain)
                : pw.SizedBox(),
          ),
          pw.Container(
            width: 240,
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide()),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            nombre,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Técnico responsable',
            style: const pw.TextStyle(fontSize: 9.5, color: _grisTexto),
          ),
        ],
      ),
    );
  }

  pw.Widget _certNota() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: 'Nota: ',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _rojo,
              ),
            ),
            pw.TextSpan(
              text:
                  'Este certificado tiene una validez de 1 (un) año a partir de la '
                  'fecha de servicio. Se recomienda renovar el mantenimiento antes del '
                  'vencimiento para garantizar la continuidad de la protección contra incendios.',
              style: const pw.TextStyle(fontSize: 9, color: _grisTexto),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx) => pw.Container(
    alignment: pw.Alignment.centerRight,
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _grisLinea)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Prosesso - Servicio Técnico de Extintores',
          style: const pw.TextStyle(fontSize: 7, color: _grisTexto),
        ),
        pw.Text(
          'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: _grisTexto),
        ),
      ],
    ),
  );

  /// Footer extendido para el REGISTRO con datos de contacto y versión.
  pw.Widget _footerRegistro(pw.Context ctx) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _grisLinea)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Prosesso - Servicio Técnico de Extintores',
              style: const pw.TextStyle(fontSize: 7, color: _grisTexto),
            ),
            pw.Text(
              'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _grisTexto),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          _servimafContacto,
          style: const pw.TextStyle(fontSize: 6.5, color: _grisTexto),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ),
  );
}

class _Stats {
  final int total;
  final int conformes;
  final int conNc;
  final int totalNc;
  const _Stats(this.total, this.conformes, this.conNc, this.totalNc);

  static _Stats from(ProsessoReportData d) {
    final total = d.extintores.length;
    var conformes = 0;
    var totalNc = 0;
    for (final e in d.extintores) {
      final nc = e.puntos
          .where((p) => p.estado == EstadoPuntoProsesso.noCumple)
          .length;
      totalNc += nc;
      if (nc == 0) conformes++;
    }
    return _Stats(total, conformes, total - conformes, totalNc);
  }
}
