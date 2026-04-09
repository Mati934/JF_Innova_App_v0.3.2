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
        maxPages: 200,
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
          pw.SizedBox(height: 10),
          _buildActividades(data),
          pw.SizedBox(height: 12),
          _buildResumen(data),
          pw.SizedBox(height: 12),
          _buildResumenHallazgos(data),
          pw.SizedBox(height: 16),
          ..._buildExtintores(data),
          if (data.apuntesObservaciones.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _buildObservaciones(data),
          ],
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
                'JF Innova',
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

  static const String _pdfVersion = '0.1.0';

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _grisLinea)),
      ),
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
          if (data.empresa.isNotEmpty)
            pw.Row(
              children: [
                _Expanded(child: _dato('Empresa', data.empresa)),
                _Expanded(child: _dato('Región', data.region)),
              ],
            ),
          if (data.empresa.isEmpty) _dato('Región', data.region),
          pw.Row(
            children: [
              _Expanded(child: _dato('Oficina / Área', data.oficina)),
              _Expanded(
                child: _dato('Lugar de Inspección', data.lugarInspeccion),
              ),
            ],
          ),
          pw.Row(
            children: [
              _Expanded(child: _dato('Jefatura a Cargo', data.jefaturaCargo)),
              if (data.origenVisita.isNotEmpty)
                _Expanded(
                  child: _dato('Origen de la Visita', data.origenVisita),
                ),
            ],
          ),
          pw.Row(
            children: [
              _Expanded(child: _dato('Fecha', data.fecha)),
              _Expanded(child: _dato('Hora Inicio', data.horaInicio)),
              _Expanded(child: _dato('Hora Término', data.horaTermino)),
            ],
          ),
          if (data.emailEmpresa1.isNotEmpty || data.emailEmpresa2.isNotEmpty)
            pw.Row(
              children: [
                _Expanded(
                  child: _dato(
                    'Correo Empresa 1',
                    data.emailEmpresa1.isNotEmpty ? data.emailEmpresa1 : 'N/A',
                  ),
                ),
                _Expanded(
                  child: _dato(
                    'Correo Empresa 2',
                    data.emailEmpresa2.isNotEmpty ? data.emailEmpresa2 : 'N/A',
                  ),
                ),
              ],
            ),
          if (data.profesional.isNotEmpty) _dato('Inspector', data.profesional),
        ],
      ),
    );
  }

  // ── Actividades realizadas ─────────────────────────────────────────────────

  pw.Widget _buildActividades(ExtintorReportData data) {
    final actividades = <String>[];
    if (data.checkReunion) actividades.add('Reunión');
    if (data.checkSenaletica) actividades.add('Inst. Señalética');
    if (data.checkCapacitacion) actividades.add('Capacitación');
    if (data.checkVisitaSso) actividades.add('Visita SSO');
    if (data.checkCharla) actividades.add('Charla(s)');
    if (data.checkInvestigacion) actividades.add('Inv. Incidente');
    if (data.checkInspeccionSso) actividades.add('Inspección SSO');
    if (data.checkObsConductual) actividades.add('Obs. Conductual');
    if (data.checkOtro)
      actividades.add(
        'Otro${data.otroActividadTexto?.isNotEmpty == true ? ": ${data.otroActividadTexto}" : ""}',
      );

    if (actividades.isEmpty) return pw.SizedBox();

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
          _titulo('ACTIVIDADES REALIZADAS'),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 12,
            runSpacing: 4,
            children: actividades
                .map(
                  (a) => pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Container(
                        width: 8,
                        height: 8,
                        decoration: pw.BoxDecoration(
                          color: _azul,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(2),
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(a, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Resumen General (estadísticas) ────────────────────────────────────────

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
              _Expanded(child: _dato('Total Extintores', '$total')),
              _Expanded(child: _dato('Conformes', '$conformes', color: _verde)),
              _Expanded(
                child: _dato(
                  'Con NC',
                  '$conNC',
                  color: conNC > 0 ? _rojo : _verde,
                ),
              ),
              _Expanded(
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

  // ── Resumen de Hallazgos (No Cumple) ──────────────────────────────────────

  pw.Widget _buildResumenHallazgos(ExtintorReportData data) {
    final hallazgos = <_Hallazgo>[];
    for (final ext in data.extintores) {
      for (final nc in ext.puntosNC) {
        hallazgos.add(
          _Hallazgo(
            extintorNumero: ext.numero,
            extintorId: ext.matricula,
            tipoExtintor: ext.tipoExtintor,
            pregunta: nc.pregunta,
            observacion: nc.observacion,
          ),
        );
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _titulo('RESUMEN DE HALLAZGOS (NO CUMPLE)'),
        pw.SizedBox(height: 6),
        if (hallazgos.isEmpty)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFE8F5E9),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFA5D6A7)),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              'Sin hallazgos "No Cumple" registrados en esta inspeccion.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
        ...hallazgos.map(
          (h) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: const pw.BorderSide(color: _rojo, width: 3),
                top: pw.BorderSide(color: _grisLinea),
                right: pw.BorderSide(color: _grisLinea),
                bottom: pw.BorderSide(color: _grisLinea),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      _hallazgoTitulo(h),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _rojo),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(8),
                        ),
                      ),
                      child: pw.Text(
                        'NC',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: _rojo,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Text(h.pregunta, style: const pw.TextStyle(fontSize: 9)),
                if (h.observacion?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    h.observacion!,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _hallazgoTitulo(_Hallazgo h) {
    final parts = <String>['Extintor #${h.extintorNumero}'];
    if (h.extintorId?.isNotEmpty == true) parts.add(h.extintorId!);
    if (h.tipoExtintor?.isNotEmpty == true) parts.add('(${h.tipoExtintor})');
    return parts.join(' — ');
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

      if (extintor.fotoPaths.isNotEmpty) {
        widgets.addAll(_buildFotosExtintor(extintor));
        widgets.add(pw.SizedBox(height: 6));
      }
    }

    return widgets;
  }

  pw.Widget _buildExtintorItem(ExtintorResumenItem extintor) {
    final parts = <String>['Extintor #${extintor.numero}'];
    if (extintor.matricula?.isNotEmpty == true) parts.add(extintor.matricula!);
    if (extintor.tipoExtintor?.isNotEmpty == true)
      parts.add('(${extintor.tipoExtintor})');
    final titulo = parts.join(' — ');

    if (extintor.todosCumplen) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFE8F5E9),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFA5D6A7)),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 14,
              height: 14,
              decoration: pw.BoxDecoration(
                color: _verde,
                borderRadius: pw.BorderRadius.circular(7),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'OK',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                ),
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

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFFFCDD2)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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
                pw.Container(
                  width: 14,
                  height: 14,
                  decoration: pw.BoxDecoration(
                    color: _rojo,
                    borderRadius: pw.BorderRadius.circular(7),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'NC',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
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
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _grisClaro),
                children: [
                  _celdaHeader('Punto de Inspección'),
                  _celdaHeader('Observación'),
                ],
              ),
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

    final parts = <String>['Fotos — Extintor #${extintor.numero}'];
    if (extintor.matricula?.isNotEmpty == true)
      parts.add('(${extintor.matricula})');
    if (extintor.tipoExtintor?.isNotEmpty == true)
      parts.add('[${extintor.tipoExtintor}]');
    final titulo = parts.join(' ');

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

  // ── Observaciones ─────────────────────────────────────────────────────────

  pw.Widget _buildObservaciones(ExtintorReportData data) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _grisClaro,
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _titulo('APUNTES / OBSERVACIONES'),
          pw.SizedBox(height: 6),
          pw.Text(
            data.apuntesObservaciones,
            style: const pw.TextStyle(fontSize: 9),
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

// ignore: non_constant_identifier_names
pw.Widget _Expanded({required pw.Widget child}) =>
    pw.Expanded(flex: 1, child: child);

class _Hallazgo {
  final int extintorNumero;
  final String? extintorId;
  final String? tipoExtintor;
  final String pregunta;
  final String? observacion;

  _Hallazgo({
    required this.extintorNumero,
    this.extintorId,
    this.tipoExtintor,
    required this.pregunta,
    this.observacion,
  });
}
