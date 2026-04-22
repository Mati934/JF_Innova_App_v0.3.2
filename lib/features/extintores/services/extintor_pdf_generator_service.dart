import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/models/extintor_report_data.dart';
import '../domain/models/extintor_state.dart' show EstadoExtintor;

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
                data.empresaProveedor,
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

  static const String _pdfVersion = '0.4.0';

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
    String v(String s) => s.isNotEmpty ? s : '—';
    final horario = '${v(data.horaInicio)}  -  ${v(data.horaTermino)}';

    final filas = <List<List<String>>>[
      [
        ['Empresa', v(data.empresa)],
        ['Región', v(data.region)],
      ],
      [
        ['Oficina / Área', v(data.oficina)],
        ['Lugar de Inspección', v(data.lugarInspeccion)],
      ],
      [
        ['Jefatura a Cargo', v(data.jefaturaCargo)],
        ['Origen de la Visita', v(data.origenVisita)],
      ],
      [
        ['Fecha', v(data.fecha)],
        ['Horario', horario],
      ],
      [
        ['Inspector', v(data.profesional)],
        ['Teléfono', v(data.fonoProfesional)],
      ],
      [
        ['Correo Inspector', v(data.correoProfesional)],
        ['Correo Empresa 1', v(data.emailEmpresa1)],
      ],
      // Última fila: solo correo empresa 2 si existe
      if (data.emailEmpresa2.isNotEmpty)
        [
          ['Correo Empresa 2', v(data.emailEmpresa2)],
          ['', ''],
        ],
    ];

    pw.Widget celda(String label, String valor) {
      if (label.isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '$label: ',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.TextSpan(
                text: valor,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _grisClaro,
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 2),
            child: _titulo('INFORMACIÓN GENERAL'),
          ),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: const pw.BorderSide(color: _grisLinea, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
            },
            children: filas
                .map(
                  (par) => pw.TableRow(
                    children: [
                      celda(par[0][0], par[0][1]),
                      celda(par[1][0], par[1][1]),
                    ],
                  ),
                )
                .toList(),
          ),
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
    final extintoresConNC = data.extintores
        .where((e) => e.puntosNC.isNotEmpty)
        .toList();

    // Construir leyenda global de preguntas NC (numero -> texto)
    final preguntasGlobal = <int, String>{};
    final preguntaToNumero = <String, int>{};
    for (final ext in data.extintores) {
      for (final p in ext.puntos) {
        preguntaToNumero.putIfAbsent(p.pregunta, () => p.numero);
      }
      for (final nc in ext.puntosNC) {
        final n = preguntaToNumero[nc.pregunta];
        if (n != null) preguntasGlobal.putIfAbsent(n, () => nc.pregunta);
      }
    }
    final leyendaEntries = preguntasGlobal.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Bloques de extintores en filas de 2 columnas.
    // Cada Row es atómico para MultiPage: si dos bloques son altos, salta a página nueva.
    final filasBloques = <pw.Widget>[];
    for (var i = 0; i < extintoresConNC.length; i += 2) {
      final left = extintoresConNC[i];
      final right = (i + 1 < extintoresConNC.length)
          ? extintoresConNC[i + 1]
          : null;
      filasBloques.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildHallazgoExtintorBloque(left, preguntaToNumero),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: right != null
                    ? _buildHallazgoExtintorBloque(right, preguntaToNumero)
                    : pw.SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _titulo('RESUMEN DE HALLAZGOS (NO CUMPLE)'),
        pw.SizedBox(height: 6),
        if (extintoresConNC.isEmpty)
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
        if (leyendaEntries.isNotEmpty) ...[
          _buildLeyendaPreguntasNC(leyendaEntries),
          pw.SizedBox(height: 6),
        ],
        ...filasBloques,
      ],
    );
  }

  /// Leyenda al inicio: lista numerada de preguntas que tienen al menos un NC.
  pw.Widget _buildLeyendaPreguntasNC(List<MapEntry<int, String>> entries) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFAFA),
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PUNTOS CON HALLAZGOS',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey700,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          pw.SizedBox(height: 4),
          for (var i = 0; i < entries.length; i++)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 1, right: 5),
                    width: 16,
                    height: 10,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: _rojo,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(1.5),
                      ),
                    ),
                    child: pw.Text(
                      '${entries[i].key}',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      entries[i].value,
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Bloque agrupado: un extintor con todos sus hallazgos NC adentro.
  /// Usa Row(barra roja + tarjeta) en vez de Border non-uniform para evitar bugs visuales.
  pw.Widget _buildHallazgoExtintorBloque(
    ExtintorResumenItem ext,
    Map<String, int> preguntaToNumero,
  ) {
    final tituloPartes = <String>['Extintor #${ext.numero}'];
    if (ext.matricula?.isNotEmpty == true) tituloPartes.add(ext.matricula!);
    if (ext.tipoExtintor?.isNotEmpty == true) {
      tituloPartes.add('(${ext.tipoExtintor})');
    }
    final titulo = tituloPartes.join(' — ');

    return pw.Container(
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
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // Header del bloque
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 3,
            ),
            color: const PdfColor.fromInt(0xFFFFEBEE),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    titulo,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _rojo,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(7),
                    ),
                  ),
                  child: pw.Text(
                    '${ext.puntosNC.length} NC',
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista compacta: 2 columnas internas
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 5),
            child: _buildHallazgosCompactos(ext, preguntaToNumero),
          ),
        ],
      ),
    );
  }

  /// Lista de hallazgos del extintor en 2 columnas internas.
  /// Si NINGÚN hallazgo tiene observación → wrap horizontal solo de cuadritos.
  /// Si alguno tiene observación → grid de 2 cols con [cuadrito] obs.
  pw.Widget _buildHallazgosCompactos(
    ExtintorResumenItem ext,
    Map<String, int> preguntaToNumero,
  ) {
    final hayObs = ext.puntosNC.any((nc) => nc.observacion?.isNotEmpty == true);

    if (!hayObs) {
      return pw.Wrap(
        spacing: 4,
        runSpacing: 3,
        children: ext.puntosNC.map((nc) {
          return _chipNumeroNC(preguntaToNumero[nc.pregunta]);
        }).toList(),
      );
    }

    // Distribuir verticalmente en 2 columnas (ej: [a,b,c,d,e] → col1:a,c,e  col2:b,d)
    final items = ext.puntosNC;
    final mid = (items.length / 2).ceil();
    final col1 = items.sublist(0, mid);
    final col2 = items.sublist(mid);

    pw.Widget colWidget(List<PuntoNCResumen> col) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        for (var i = 0; i < col.length; i++)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 2.5),
            child: _filaNCCompacta(col[i], preguntaToNumero),
          ),
      ],
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: colWidget(col1)),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: col2.isNotEmpty ? colWidget(col2) : pw.SizedBox(),
        ),
      ],
    );
  }

  pw.Widget _filaNCCompacta(
    PuntoNCResumen nc,
    Map<String, int> preguntaToNumero,
  ) {
    final tieneObs = nc.observacion?.isNotEmpty == true;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _chipNumeroNC(preguntaToNumero[nc.pregunta]),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(
            tieneObs ? nc.observacion! : '—',
            style: pw.TextStyle(
              fontSize: 8,
              color: tieneObs ? PdfColors.grey800 : PdfColors.grey500,
              fontStyle: tieneObs ? pw.FontStyle.normal : pw.FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _chipNumeroNC(int? numero) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 1),
      width: 16,
      height: 10,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _rojo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
      ),
      child: pw.Text(
        numero != null ? '$numero' : '?',
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 6.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // ── Lista de extintores (tarjetas detalladas) ─────────────────────────────

  List<pw.Widget> _buildExtintores(ExtintorReportData data) {
    final widgets = <pw.Widget>[
      _titulo('DETALLE POR EXTINTOR'),
      pw.SizedBox(height: 8),
    ];

    for (final extintor in data.extintores) {
      widgets.add(_buildExtintorCard(extintor));
      widgets.add(pw.SizedBox(height: 8));
    }

    return widgets;
  }

  PdfColor _colorEstado(EstadoExtintor? e) {
    switch (e) {
      case EstadoExtintor.cumple:
        return _verde;
      case EstadoExtintor.noCumple:
        return _rojo;
      case EstadoExtintor.noAplica:
        return const PdfColor.fromInt(0xFF9E9E9E);
      case null:
        return const PdfColor.fromInt(0xFFBDBDBD);
    }
  }

  pw.Widget _buildExtintorCard(ExtintorResumenItem extintor) {
    final hayNC = extintor.puntosNC.isNotEmpty;
    final colorBorde = hayNC
        ? const PdfColor.fromInt(0xFFFFCDD2)
        : const PdfColor.fromInt(0xFFA5D6A7);
    final colorHeaderFondo = hayNC
        ? const PdfColor.fromInt(0xFFFFEBEE)
        : const PdfColor.fromInt(0xFFE8F5E9);
    final colorEstadoChip = hayNC ? _rojo : _verde;
    final tituloPartes = <String>['Extintor #${extintor.numero}'];
    if (extintor.matricula?.isNotEmpty == true) {
      tituloPartes.add(extintor.matricula!);
    }
    final titulo = tituloPartes.join(' — ');

    final fotoValida = extintor.fotoPaths.isNotEmpty
        ? extintor.fotoPaths.firstWhere(
            (p) => File(p).existsSync(),
            orElse: () => '',
          )
        : '';
    pw.MemoryImage? fotoImg;
    if (fotoValida.isNotEmpty) {
      try {
        fotoImg = pw.MemoryImage(File(fotoValida).readAsBytesSync());
      } catch (_) {}
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: colorBorde),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header compacto
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: colorHeaderFondo,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(3),
                topRight: pw.Radius.circular(3),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  titulo,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
                pw.Spacer(),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: pw.BoxDecoration(
                    color: colorEstadoChip,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Text(
                    hayNC ? '${extintor.puntosNC.length} NC' : 'CONFORME',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cuerpo: grid de info (3 cols x 2 filas) a la izquierda + foto a la derecha
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoGrid(extintor),
                    ],
                  ),
                ),
                pw.SizedBox(width: 7),
                pw.Container(
                  width: 62,
                  height: 62,
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFAFAFA),
                    border: pw.Border.all(color: _grisLinea),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(3),
                    ),
                  ),
                  alignment: pw.Alignment.center,
                  child: fotoImg != null
                      ? pw.Image(
                          fotoImg,
                          width: 62,
                          height: 62,
                          fit: pw.BoxFit.cover,
                        )
                      : pw.Text(
                          'Sin foto',
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: PdfColors.grey500,
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Separador entre cuerpo y footer
          pw.Container(height: 0.5, color: _grisLinea),
          // Footer: cuadritos numerados + leyenda en una sola línea
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF7F7F7),
              borderRadius: pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(3),
                bottomRight: pw.Radius.circular(3),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Wrap(
                    spacing: 2.5,
                    runSpacing: 2.5,
                    children:
                        extintor.puntos.map((p) => _puntoChip(p)).toList(),
                  ),
                ),
                pw.SizedBox(width: 8),
                _leyendaEstados(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Info del extintor en grid alineado de 3 columnas x 2 filas.
  /// Cada celda tiene fondo suave, label arriba (gris pequeño) y valor abajo.
  pw.Widget _buildInfoGrid(ExtintorResumenItem extintor) {
    String v(String? s) => (s != null && s.isNotEmpty) ? s : '—';

    final celdas = <List<String>>[
      ['TIPO', v(extintor.tipoExtintor)],
      ['PESO', v(extintor.pesoExtintor)],
      ['MATRÍCULA / UBIC.', v(extintor.matricula)],
      ['ÚLTIMA MANTENCIÓN', v(extintor.fechaUltimaMantencion)],
      ['PRÓXIMA MANTENCIÓN', v(extintor.fechaProximaMantencion)],
      ['TOTAL PUNTOS', '${extintor.totalPuntos}'],
    ];

    pw.Widget cellWidget(List<String> kv) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFBFC),
        border: pw.Border.all(color: _grisLinea),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            kv[0],
            style: const pw.TextStyle(
              fontSize: 6,
              color: PdfColors.grey600,
              letterSpacing: 0.3,
            ),
          ),
          pw.Text(
            kv[1],
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    pw.Widget row(int from) => pw.Row(
      children: [
        pw.Expanded(child: cellWidget(celdas[from])),
        pw.SizedBox(width: 3),
        pw.Expanded(child: cellWidget(celdas[from + 1])),
        pw.SizedBox(width: 3),
        pw.Expanded(child: cellWidget(celdas[from + 2])),
      ],
    );

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [row(0), pw.SizedBox(height: 3), row(3)],
    );
  }

  pw.Widget _puntoChip(PuntoEstadoResumen p) {
    final color = _colorEstado(p.estado);
    return pw.Container(
      width: 16,
      height: 10,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
      ),
      child: pw.Text(
        '${p.numero}',
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 6.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _leyendaEstados() {
    pw.Widget item(PdfColor c, String label) => pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 6,
          height: 6,
          decoration: pw.BoxDecoration(
            color: c,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1)),
          ),
        ),
        pw.SizedBox(width: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
        ),
      ],
    );

    return pw.Row(
      children: [
        item(_verde, 'Cumple'),
        pw.SizedBox(width: 6),
        item(_rojo, 'No Cumple'),
        pw.SizedBox(width: 6),
        item(const PdfColor.fromInt(0xFF9E9E9E), 'N/A'),
        pw.SizedBox(width: 6),
        item(const PdfColor.fromInt(0xFFBDBDBD), 'Sin responder'),
      ],
    );
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

  // ignore: unused_element
  pw.Widget _celdaHeader(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      texto,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    ),
  );

  // ignore: unused_element
  pw.Widget _celda(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(texto, style: const pw.TextStyle(fontSize: 8)),
  );
}

// ignore: non_constant_identifier_names
pw.Widget _Expanded({required pw.Widget child}) =>
    pw.Expanded(flex: 1, child: child);
