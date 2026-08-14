import 'dart:io'; // Importante para leer archivos dentro del Isolate
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// import 'package:image/image.dart' as img;
import '../domain/models/pdf/inspection_report_data.dart';
import 'package:flutter/foundation.dart';

class PdfIsolateParams {
  final InspectionReportData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List fontItalic;
  final Uint8List? logoBytes;

  PdfIsolateParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    required this.fontItalic,
    this.logoBytes,
  });
}

Future<Uint8List> generatePdfEntryPoint(PdfIsolateParams params) async {
  // AQUÍ SÍ estamos enviando el trabajo a un hilo secundario real usando compute.
  // Esto libera el hilo principal (UI) y evita el jank mientras se crea el PDF.
  return await compute(_buildPdfInIsolate, params);
}

Future<Uint8List> _buildPdfInIsolate(PdfIsolateParams params) async {
  final pdfService = PdfGeneratorService();
  return await pdfService._generatePdfSync(params);
}

class _Aq {
  static final PdfColor blue = PdfColor.fromHex('#0059A3');
  static final PdfColor blueMid = PdfColor.fromHex('#0072C6');
  static final PdfColor blueLight = PdfColor.fromHex('#E4F3FC');
  static final PdfColor teal = PdfColor.fromHex('#00AEC7');
  static final PdfColor tealLight = PdfColor.fromHex('#DFF7FA');
  static final PdfColor tealMid = PdfColor.fromHex('#009DB5');
  static final PdfColor green = PdfColor.fromHex('#00975B');
  static final PdfColor greenLight = PdfColor.fromHex('#E1F8ED');
  static final PdfColor greenMid = PdfColor.fromHex('#20C878');
  static final PdfColor greenBorder = PdfColor.fromHex('#A5D6A7');
  static final PdfColor red = PdfColor.fromHex('#E5484D');
  static final PdfColor redLight = PdfColor.fromHex('#FFECED');
  static final PdfColor redBorder = PdfColor.fromHex('#FFCDD2');
  static final PdfColor amber = PdfColor.fromHex('#FF6A3D');
  static final PdfColor amberLight = PdfColor.fromHex('#FFEEE6');
  static final PdfColor grayLight = PdfColor.fromHex('#EFF9FC');
  static final PdfColor grayMid = PdfColor.fromHex('#DFF1F6');
  static final PdfColor ink = PdfColor.fromHex('#0A2A3D');
  static final PdfColor inkMid = PdfColor.fromHex('#1D4A5F');
  static final PdfColor inkDim = PdfColor.fromHex('#4F7E92');
  static final PdfColor inkFaint = PdfColor.fromHex('#8FBACB');
  static final PdfColor rule = PdfColor.fromHex('#CDEAF2');
}

class _StatusStyle {
  final PdfColor bg;
  final PdfColor border;
  final PdfColor text;
  final String label;

  const _StatusStyle(this.bg, this.border, this.text, this.label);
}

class PdfGeneratorService {
  Future<Uint8List> _generatePdfSync(PdfIsolateParams params) async {
    final pdf = pw.Document();
    final data = params.data;
    final bool esBuceo = data.tipoFaena.contains('BUCEO');

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(params.fontRegular.buffer.asByteData()),
      bold: pw.Font.ttf(params.fontBold.buffer.asByteData()),
      italic: pw.Font.ttf(params.fontItalic.buffer.asByteData()),
    );

    pw.MemoryImage? logoImage;
    if (params.logoBytes != null) {
      logoImage = pw.MemoryImage(params.logoBytes!);
    }

    pdf.addPage(
      pw.MultiPage(
        maxPages: 500,
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 24),
          buildBackground: (context) => esBuceo
              ? pw.Container()
              : pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.5),
                  ),
                ),
        ),
        footer: (context) => _buildFooter(context, data),
        build: (context) => esBuceo
            ? _buildBuceoDocument(data, logoImage)
            : _buildDefaultDocument(data, logoImage),
      ),
    );

    return pdf.save();
  }

  List<pw.Widget> _buildDefaultDocument(
    InspectionReportData data,
    pw.MemoryImage? logoImage,
  ) {
    return [
      _buildHeader(data, logoImage),
      pw.SizedBox(height: 15),
      _buildStatusAndStats(data),
      pw.SizedBox(height: 10),
      if (data.tipoFaena.contains('BUCEO')) ...[
        _buildTechnicalDetails(data),
        pw.SizedBox(height: 10),
        _buildPersonnelTable(data),
        pw.SizedBox(height: 10),
        _buildSafetyChecklist(data),
        pw.SizedBox(height: 15),
      ],
      _buildGeneralObservations(data),
      pw.SizedBox(height: 30),
      _buildResumenNoCumple(data),
      pw.NewPage(),
      pw.Center(
        child: pw.Text(
          "DETALLE DE VERIFICACIONES",
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline,
            color: PdfColors.blue900,
          ),
        ),
      ),
      pw.SizedBox(height: 10),
      ..._buildCategorizedChecklists(data),
      if (data.fotosExtraObservaciones.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        ..._buildFotosObservacion(data.fotosExtraObservaciones),
      ],
      if (data.fotosGeneralesPaths.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.SizedBox(height: 10),
        ..._buildGeneralGallery(data.fotosGeneralesPaths),
        pw.SizedBox(height: 15),
      ],
    ];
  }

  List<pw.Widget> _buildBuceoDocument(
    InspectionReportData data,
    pw.MemoryImage? logoImage,
  ) {
    return [
      _buildBuceoHeader(data, logoImage),
      pw.SizedBox(height: 10),
      _buildBuceoStatusBar(data),
      pw.SizedBox(height: 14),
      _buildBuceoSection(
        title: 'Resumen de Cumplimiento',
        subtitle:
            '${data.totalCumple + data.totalNoCumple} items evaluados · ${data.totalNoAplica} no aplican',
        child: _buildBuceoScoreGrid(data),
      ),
      pw.SizedBox(height: 16),
      _buildBuceoSection(
        title: 'Verificaciones Criticas de Seguridad',
        subtitle: '${data.verificacionesBuceo.length} items verificados',
        child: _buildBuceoSafetyCards(data),
      ),
      pw.SizedBox(height: 16),
      _buildBuceoSection(
        title: 'Equipo de Trabajo / Personal',
        subtitle: '${data.equipo.length} integrantes',
        child: _buildBuceoPersonnelCards(data),
      ),
      pw.SizedBox(height: 16),
      _buildBuceoSection(
        title: 'Equipamiento · Compresores de Buceo',
        subtitle: _buildCompresorSubtitle(data),
        child: _buildBuceoCompresorCards(data),
      ),
      if (data.observacionPrevencionista.trim().isNotEmpty) ...[
        pw.SizedBox(height: 16),
        _buildBuceoSection(
          title: 'Observaciones Generales',
          child: _buildBuceoObservations(data),
        ),
      ],
      if (_hasNoCumpleItems(data)) ...[
        pw.SizedBox(height: 16),
        _buildBuceoSectionHeader(
          title: 'Hallazgos — No Cumple',
          subtitle: '${data.totalNoCumple} hallazgo(s)',
        ),
        _buildBuceoHallazgos(data),
      ],
      pw.NewPage(),
      _buildBuceoSectionHeader(
        title: 'Detalle de Verificaciones',
        subtitle:
            '${data.items.length} items · ${data.totalCumple} C · ${data.totalNoCumple} NC · ${data.totalNoAplica} N/A',
      ),
      ..._buildCategorizedChecklists(data),
      if (data.checklistPhotos.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        ..._buildChecklistPhotoAppendix(data.checklistPhotos),
      ],
      if (data.fotosExtraObservaciones.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        ..._buildFotosObservacion(data.fotosExtraObservaciones),
      ],
      if (data.mandatoryPhotos.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        ..._buildMandatoryPhotosSection(data.mandatoryPhotos),
      ],
      if (data.fotosGeneralesPaths.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        ..._buildGeneralGallery(data.fotosGeneralesPaths),
      ],
    ];
  }

  pw.Widget _buildBuceoHeader(
    InspectionReportData data,
    pw.MemoryImage? logoImage,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: _Aq.rule, width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            height: 6,
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_Aq.blue, _Aq.teal, _Aq.amber],
              ),
              borderRadius: const pw.BorderRadius.vertical(
                top: pw.Radius.circular(14),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 7,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 120,
                            height: 42,
                            padding: const pw.EdgeInsets.all(4),
                            decoration: pw.BoxDecoration(
                              color: _Aq.tealLight,
                              borderRadius: pw.BorderRadius.circular(12),
                              border: pw.Border.all(
                                color: _Aq.teal,
                                width: 1.4,
                              ),
                            ),
                            child: logoImage != null
                                ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                                : pw.SizedBox(),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Container(width: 1, height: 40, color: _Aq.rule),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  data.area.toUpperCase(),
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: _Aq.tealMid,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  data.cliente,
                                  style: pw.TextStyle(
                                    fontSize: 23,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _Aq.blueMid,
                                  ),
                                ),
                                pw.Text(
                                  'Informe Tecnico · Inspeccion de Buceo',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _Aq.inkMid,
                                  ),
                                ),
                                pw.Text(
                                  '${data.centro} · ${data.embarcacion}',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: _Aq.inkDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: _Aq.grayLight,
                          borderRadius: pw.BorderRadius.circular(12),
                          border: pw.Border.all(color: _Aq.rule, width: 1),
                        ),
                        child: _buildBuceoMetaRow(data),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'N°',
                            style: pw.TextStyle(fontSize: 13, color: _Aq.blue),
                          ),
                          pw.SizedBox(width: 3),
                          pw.Text(
                            data.numeroReporte,
                            style: pw.TextStyle(
                              fontSize: 32,
                              fontWeight: pw.FontWeight.bold,
                              color: _Aq.blueMid,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Informe',
                        style: pw.TextStyle(fontSize: 8, color: _Aq.inkFaint),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Tipo de inspeccion',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: _Aq.inkFaint,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.ClipRRect(
                        horizontalRadius: 20,
                        verticalRadius: 20,
                        child: pw.Container(
                          padding: pw.EdgeInsets.symmetric(
                            horizontal: data.esConsecutiva ? 12 : 10,
                            vertical: 6,
                          ),
                          color: _Aq.teal,
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Container(
                                width: 6,
                                height: 6,
                                decoration: pw.BoxDecoration(
                                  color: _Aq.amber,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                              pw.SizedBox(width: 6),
                              pw.Text(
                                data.esConsecutiva ? 'CONSECUTIVA' : 'INICIAL',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _Aq.amberLight,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          data.fecha,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: _Aq.amber,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetaItem(String label, String value) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 7,
                color: _Aq.inkFaint,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                color: _Aq.ink,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildMetaDivider(PdfColor color) {
    return pw.Container(width: 1, height: 38, color: color);
  }

  pw.Widget _buildBuceoMetaRow(InspectionReportData data) {
    final entries = <(String, String)>[
      ('Empresa', data.empresaContratista),
      ('Matricula', data.matricula),
      ('Profesional', data.profesional ?? ''),
      ('Supervisor', data.supervisor),
    ].where((entry) => entry.$2.trim().isNotEmpty).toList();

    return pw.Row(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _buildMetaItem(entries[index].$1, entries[index].$2),
          if (index < entries.length - 1) _buildMetaDivider(_Aq.rule),
        ],
      ],
    );
  }

  _StatusStyle _statusStyleFor(String? respuesta) {
    final value = (respuesta ?? '').toUpperCase();
    if (value == 'NC') {
      return _StatusStyle(_Aq.redLight, _Aq.redBorder, _Aq.red, 'NC');
    }
    if (value == 'N/A' || value == 'NA') {
      return _StatusStyle(_Aq.grayMid, _Aq.rule, _Aq.inkFaint, 'N/A');
    }
    return _StatusStyle(_Aq.greenLight, _Aq.greenBorder, _Aq.green, 'C');
  }

  PdfColor _colorForCriticidad(String criticidad) {
    final value = criticidad.toLowerCase();
    if (value.contains('intolerable') || value.contains('alto')) {
      return _Aq.red;
    }
    if (value.contains('moderado') || value.contains('medio')) {
      return PdfColors.orange600;
    }
    if (value.contains('tolerable') || value.contains('bajo')) {
      return _Aq.amber;
    }
    return PdfColors.grey600;
  }

  pw.Widget _commentBox(String text, {double fontSize = 7}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _Aq.rule, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontStyle: pw.FontStyle.italic,
          color: _Aq.inkMid,
        ),
      ),
    );
  }

  pw.Widget _progressBar(double fraction, {double height = 5}) {
    final filled = (fraction.clamp(0, 1) * 100).round();
    final empty = 100 - filled;
    return pw.ClipRRect(
      horizontalRadius: height / 2,
      verticalRadius: height / 2,
      child: pw.SizedBox(
        height: height,
        child: pw.Row(
          children: [
            if (filled > 0)
              pw.Expanded(
                flex: filled,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [_Aq.greenMid, _Aq.teal],
                    ),
                  ),
                ),
              ),
            if (empty > 0)
              pw.Expanded(
                flex: empty,
                child: pw.Container(color: _Aq.greenBorder),
              ),
          ],
        ),
      ),
    );
  }

  List<int> _itemNumbersWhere(
    InspectionReportData data,
    bool Function(String) test,
  ) {
    final numbers = <int>[];
    for (var index = 0; index < data.items.length; index++) {
      if (test(data.items[index].respuesta)) numbers.add(index + 1);
    }
    return numbers;
  }

  pw.Widget _buildBuceoStatusBar(InspectionReportData data) {
    final bool habilitada = data.estadoGlobal.toUpperCase() == 'HABILITADA';
    final PdfColor bg = habilitada ? _Aq.greenLight : _Aq.redLight;
    final PdfColor fg = habilitada ? _Aq.green : _Aq.red;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: pw.BoxDecoration(
        gradient: habilitada
            ? pw.LinearGradient(colors: [_Aq.greenLight, _Aq.tealLight])
            : null,
        color: habilitada ? null : bg,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 10,
                height: 10,
                decoration: pw.BoxDecoration(
                  color: fg,
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: PdfColors.white, width: 2),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Estado Final de Faena: ${data.estadoGlobal.isEmpty ? '-' : '${data.estadoGlobal[0]}${data.estadoGlobal.substring(1).toLowerCase()}'}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: fg,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          if ((data.horaInicio ?? '').trim().isNotEmpty &&
              (data.horaTermino ?? '').trim().isNotEmpty)
            pw.Text(
              'Auditoria: ${data.horaInicio} - ${data.horaTermino} hrs',
              style: pw.TextStyle(
                fontSize: 9,
                color: fg,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildBuceoSectionHeader({
    required String title,
    String? subtitle,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _Aq.teal, width: 2.4)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              color: _Aq.teal,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _Aq.blue,
              letterSpacing: 1.4,
            ),
          ),
          if (subtitle != null) ...[
            pw.Spacer(),
            pw.Text(
              subtitle,
              style: pw.TextStyle(fontSize: 8, color: _Aq.inkFaint),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildBuceoSection({
    required String title,
    required pw.Widget child,
    String? subtitle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildBuceoSectionHeader(title: title, subtitle: subtitle),
        child,
      ],
    );
  }

  pw.Widget _buildBuceoScoreGrid(InspectionReportData data) {
    final double totalPesoAplicable = data.sumPesoCumple + data.sumPesoNoCumple;
    final pctCumpleValue = totalPesoAplicable == 0
        ? 0.0
        : data.sumPesoCumple / totalPesoAplicable;
    final pctCumple = totalPesoAplicable == 0
        ? '0 %'
        : '${(pctCumpleValue * 100).toStringAsFixed(1)} %';
    final ncNums = _itemNumbersWhere(data, (respuesta) => respuesta == 'NC');
    final naNums = _itemNumbersWhere(
      data,
      (respuesta) =>
          respuesta.toUpperCase() == 'N/A' || respuesta.toUpperCase() == 'NA',
    );

    return pw.Row(
      children: [
        _buildScoreCard(
          label: 'Cumple',
          value: '${data.totalCumple}',
          footer: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _progressBar(pctCumpleValue),
              pw.SizedBox(height: 8),
              pw.Text(
                pctCumple,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: _Aq.green,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          background: _Aq.greenLight,
          border: _Aq.greenBorder,
          text: _Aq.green,
        ),
        pw.SizedBox(width: 8),
        _buildScoreCard(
          label: 'No Cumple',
          value: '${data.totalNoCumple}',
          footer: pw.Text(
            ncNums.isEmpty
                ? 'Sin hallazgos'
                : 'Item${ncNums.length > 1 ? 's' : ''} ${ncNums.join(', ')}',
            style: pw.TextStyle(fontSize: 9, color: _Aq.red),
          ),
          background: _Aq.redLight,
          border: _Aq.redBorder,
          text: _Aq.red,
        ),
        pw.SizedBox(width: 8),
        _buildScoreCard(
          label: 'No Aplica',
          value: '${data.totalNoAplica}',
          footer: pw.Text(
            naNums.isEmpty
                ? 'Fuera de calculo'
                : 'Item${naNums.length > 1 ? 's' : ''} ${naNums.join(', ')}',
            style: pw.TextStyle(fontSize: 9, color: _Aq.inkDim),
          ),
          background: _Aq.grayMid,
          border: _Aq.rule,
          text: _Aq.inkDim,
        ),
      ],
    );
  }

  pw.Widget _buildScoreCard({
    required String label,
    required String value,
    required pw.Widget footer,
    required PdfColor background,
    required PdfColor border,
    required PdfColor text,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: border, width: 1.2),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: text,
                letterSpacing: 1.4,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 30,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
            pw.SizedBox(height: 10),
            footer,
          ],
        ),
      ),
    );
  }

  pw.Widget _buildBuceoSafetyCards(InspectionReportData data) {
    final List<MapEntry<String, dynamic>> entries = data
        .verificacionesBuceo
        .entries
        .toList();
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final romanKey = entry.key.split('.').first.trim();
        final bool cumple = entry.value == true;
        final imagePath = data.safetyPhotosPaths[romanKey];
        final observation = data.safetyObservations[romanKey];

        return pw.Container(
          width: 104,
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: _Aq.rule, width: 1),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: pw.BoxDecoration(
                  color: cumple ? _Aq.greenLight : _Aq.redLight,
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(
                    color: cumple ? _Aq.greenMid : _Aq.red,
                    width: 1.6,
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    cumple ? 'OK' : 'X',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: cumple ? _Aq.green : _Aq.red,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                entry.key.replaceFirst('$romanKey.', '').trim(),
                style: pw.TextStyle(fontSize: 7, color: _Aq.inkMid),
                textAlign: pw.TextAlign.center,
              ),
              if (imagePath != null && imagePath.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                _buildPhotoThumb(imagePath, width: 86, height: 64),
              ],
              if (observation != null && observation.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                _commentBox(observation.trim(), fontSize: 6),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildBuceoPersonnelCards(InspectionReportData data) {
    return pw.Wrap(
      alignment: pw.WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: data.equipo.map((person) {
        final isSupervisor = person.cargo.toLowerCase().contains('super');
        return pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: isSupervisor
                ? PdfColor.fromHex('#FFEEE6')
                : PdfColor.fromHex('#F7FBFD'),
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(
              color: isSupervisor
                  ? PdfColor.fromHex('#FF6A3D')
                  : PdfColor.fromHex('#CDEAF2'),
              width: 1,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 30,
                    height: 30,
                    decoration: pw.BoxDecoration(
                      color: isSupervisor
                          ? PdfColor.fromHex('#FFD8C7')
                          : PdfColor.fromHex('#EAF7FC'),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        isSupervisor ? 'S' : 'B',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0059A3'),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      person.nombre,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: isSupervisor
                          ? PdfColor.fromHex('#FFE0CF')
                          : PdfColor.fromHex('#DFF7FA'),
                      borderRadius: pw.BorderRadius.circular(14),
                    ),
                    child: pw.Text(
                      person.cargo,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: isSupervisor
                            ? PdfColor.fromHex('#FF6A3D')
                            : PdfColor.fromHex('#009DB5'),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              if (person.rut.trim().isNotEmpty)
                _buildInfoLine('RUT', person.rut),
              if (person.matricula.trim().isNotEmpty)
                _buildInfoLine('Matricula', person.matricula),
              if (person.rolEnFaena.trim().isNotEmpty)
                _buildInfoLine('Condicion', person.rolEnFaena),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildInfoLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.blueGrey400,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey900),
            ),
          ],
        ),
      ),
    );
  }

  String _buildCompresorSubtitle(InspectionReportData data) {
    int activos = 0;
    if ((data.compresor1Matricula ?? '').trim().isNotEmpty) activos++;
    if ((data.compresor2Matricula ?? '').trim().isNotEmpty) activos++;
    return '$activos equipo(s) activo(s) registrado(s)';
  }

  pw.Widget _buildBuceoCompresorCards(InspectionReportData data) {
    final compresores = <Map<String, String?>>[];
    if ((data.compresor1Matricula ?? '').trim().isNotEmpty) {
      compresores.add({
        'index': 'C1',
        'nombre': 'Compresor 1',
        'matricula': data.compresor1Matricula,
        'vigencia': data.compresor1Vigencia,
        'ph': data.compresor1PH,
        'buzos': data.compresor1Buzos,
      });
    }
    if ((data.compresor2Matricula ?? '').trim().isNotEmpty) {
      compresores.add({
        'index': 'C2',
        'nombre': 'Compresor 2',
        'matricula': data.compresor2Matricula,
        'vigencia': data.compresor2Vigencia,
        'ph': data.compresor2PH,
        'buzos': data.compresor2Buzos,
      });
    }

    return pw.Column(
      children: compresores.map((compresor) {
        final fields = <(String, String, bool)>[
          ('Equipo', compresor['nombre'] ?? '', false),
          ('Matricula', compresor['matricula'] ?? '', false),
          ('Vigencia', compresor['vigencia'] ?? '', false),
          ('Vigencia P.H.', compresor['ph'] ?? '', false),
          ('Buzos', compresor['buzos'] ?? '', true),
        ].where((field) => field.$2.trim().isNotEmpty).toList();

        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F7FBFD'),
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: PdfColor.fromHex('#CDEAF2'), width: 1),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 42,
                height: 56,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0059A3'),
                  borderRadius: const pw.BorderRadius.horizontal(
                    left: pw.Radius.circular(12),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    compresor['index']!,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      for (final field in fields)
                        _buildCompresorField(
                          field.$1,
                          field.$2,
                          center: field.$3,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildCompresorField(
    String label,
    String value, {
    bool center = false,
  }) {
    return pw.Container(
      width: 92,
      child: pw.Column(
        crossAxisAlignment: center
            ? pw.CrossAxisAlignment.center
            : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.blueGrey400,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blueGrey900,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBuceoObservations(InspectionReportData data) {
    return pw.ClipRRect(
      horizontalRadius: 14,
      verticalRadius: 14,
      child: pw.Container(
        width: double.infinity,
        color: _Aq.tealLight,
        child: pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(5),
            1: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(color: _Aq.teal),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: pw.Text(
                    data.observacionPrevencionista,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _Aq.inkMid,
                      lineSpacing: 2.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasNoCumpleItems(InspectionReportData data) {
    return data.items.any((item) => item.respuesta == 'NC');
  }

  pw.Widget _buildBuceoHallazgos(InspectionReportData data) {
    final hallazgos = <Map<String, dynamic>>[];
    int numero = 1;
    for (final item in data.items) {
      if (item.respuesta == 'NC') {
        hallazgos.add({'numero': numero, 'item': item});
      }
      numero++;
    }

    return pw.Column(
      children: hallazgos.map((entry) {
        final InspectionItemDto item = entry['item'];
        final PdfColor criticidadColor = _colorForCriticidad(item.criticidad);
        return pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _Aq.redLight,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: _Aq.redBorder, width: 1),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 4,
                height: 42,
                margin: const pw.EdgeInsets.only(top: 2),
                decoration: pw.BoxDecoration(
                  color: _Aq.red,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Item N° ${entry['numero']} · ${item.categoria}',
                          style: pw.TextStyle(fontSize: 8, color: _Aq.inkDim),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: pw.BoxDecoration(
                            color: _Aq.amberLight,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            item.criticidad.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: criticidadColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      item.pregunta,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _Aq.red,
                      ),
                    ),
                    if ((item.comentario ?? '').trim().isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        item.comentario!.trim(),
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: _Aq.inkMid,
                          lineSpacing: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<pw.Widget> _buildChecklistPhotoAppendix(
    List<ChecklistPhotoDto> checklistPhotos,
  ) {
    final Map<String, List<ChecklistPhotoDto>> byCategory = {};
    for (final item in checklistPhotos) {
      byCategory.putIfAbsent(item.categoria, () => []).add(item);
    }

    final widgets = <pw.Widget>[];
    for (
      var categoryIndex = 0;
      categoryIndex < byCategory.length;
      categoryIndex++
    ) {
      final category = byCategory.keys.elementAt(categoryIndex);
      final categoryHeader = _buildChecklistPhotoCategoryHeader(category);

      final cards = byCategory[category]!.map((item) {
        return pw.Container(
          width: 130,
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: _Aq.rule, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: pw.BoxDecoration(
                  color: item.respuesta == 'NC' ? _Aq.redLight : _Aq.blueLight,
                  borderRadius: const pw.BorderRadius.vertical(
                    top: pw.Radius.circular(11),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Item ${item.numero.toString().padLeft(2, '0')}',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: item.respuesta == 'NC' ? _Aq.red : _Aq.blue,
                      ),
                    ),
                    pw.Text(
                      _statusStyleFor(item.respuesta).label,
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                        color: _statusStyleFor(item.respuesta).text,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.pregunta,
                      style: pw.TextStyle(fontSize: 7, color: _Aq.inkDim),
                    ),
                    pw.SizedBox(height: 7),
                    ...item.fotosPaths.map(
                      (path) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: _buildPhotoThumb(path, width: 106, height: 80),
                      ),
                    ),
                    if ((item.comentario ?? '').trim().isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      _commentBox(item.comentario!.trim(), fontSize: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList();

      if (categoryIndex == 0) {
        widgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildBuceoSectionHeader(
                title: 'Registro Fotografico por Item del Checklist',
                subtitle: 'Foto individual por item con numero de referencia',
              ),
              categoryHeader,
            ],
          ),
        );
      } else {
        widgets.add(categoryHeader);
      }
      widgets.addAll(
        _buildCardRows(
          cards,
          columns: 4,
          mainAxisAlignment: pw.MainAxisAlignment.start,
        ),
      );
      widgets.add(pw.SizedBox(height: 10));
    }

    return widgets;
  }

  pw.Widget _buildChecklistPhotoCategoryHeader(String category) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
      child: pw.Text(
        category,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _Aq.inkDim,
          letterSpacing: 1,
        ),
      ),
    );
  }

  List<pw.Widget> _buildMandatoryPhotosSection(
    List<MandatoryPhotoDto> mandatoryPhotos,
  ) {
    final cards = mandatoryPhotos.map((item) {
      return pw.Container(
        width: 248,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: _Aq.rule, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(colors: [_Aq.blue, _Aq.tealMid]),
                borderRadius: const pw.BorderRadius.vertical(
                  top: pw.Radius.circular(13),
                ),
              ),
              child: pw.Text(
                item.title,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 0.6,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: _buildPhotoThumb(item.path, width: 226, height: 148),
            ),
          ],
        ),
      );
    }).toList();

    return [
      pw.NewPage(),
      _buildBuceoSectionHeader(title: 'Fotografias Obligatorias'),
      ..._buildCardRows(
        cards,
        columns: 2,
        horizontalSpacing: 10,
        verticalSpacing: 10,
        mainAxisAlignment: pw.MainAxisAlignment.center,
      ),
    ];
  }

  List<pw.Widget> _buildCardRows(
    List<pw.Widget> cards, {
    required int columns,
    double horizontalSpacing = 8,
    double verticalSpacing = 8,
    pw.MainAxisAlignment mainAxisAlignment = pw.MainAxisAlignment.start,
  }) {
    final widgets = <pw.Widget>[];
    for (int i = 0; i < cards.length; i += columns) {
      final rowCards = cards.skip(i).take(columns).toList();
      widgets.add(
        pw.Row(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (int c = 0; c < rowCards.length; c++) ...[
              rowCards[c],
              if (c < rowCards.length - 1)
                pw.SizedBox(width: horizontalSpacing),
            ],
          ],
        ),
      );
      if (i + columns < cards.length) {
        widgets.add(pw.SizedBox(height: verticalSpacing));
      }
    }
    return widgets;
  }

  pw.Widget _buildPhotoThumb(
    String path, {
    required double width,
    required double height,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      return pw.SizedBox();
    }
    final bytes = file.readAsBytesSync();
    pw.MemoryImage? image;
    try {
      image = pw.MemoryImage(bytes);
    } catch (_) {
      return pw.SizedBox(width: width, height: height);
    }
    return pw.Center(
      child: pw.Container(
        width: width,
        height: height,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColor.fromHex('#CDEAF2'), width: 1),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 8,
          verticalRadius: 8,
          child: pw.Image(image, fit: pw.BoxFit.cover),
        ),
      ),
    );
  }

  List<pw.Widget> _buildCategorizedChecklists(InspectionReportData data) {
    // Agrupar items por categoría preservando el orden de `orden ASC`
    // (data.items ya viene ordenado por orden, LinkedHashMap preserva insertion order)
    final Map<String, List<dynamic>> groupedItems = {};
    for (var item in data.items) {
      if (!groupedItems.containsKey(item.categoria)) {
        groupedItems[item.categoria] = [];
      }
      groupedItems[item.categoria]!.add(item);
    }

    final bool esBuceo = data.tipoFaena.contains('BUCEO');
    List<pw.Widget> widgets = [];
    int globalCounter = 1;

    final categoriesToRender = groupedItems.keys.toList();

    for (var category in categoriesToRender) {
      final items = groupedItems[category]!;
      final int startNumber = globalCounter;

      if (esBuceo) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: [_Aq.blue, _Aq.tealMid]),
              borderRadius: const pw.BorderRadius.vertical(
                top: pw.Radius.circular(10),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  category.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'items ${startNumber.toString().padLeft(2, '0')}-${(startNumber + items.length - 1).toString().padLeft(2, '0')}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        );
        widgets.add(
          pw.Table(
            border: pw.TableBorder(
              left: pw.BorderSide(color: _Aq.rule, width: 1),
              right: pw.BorderSide(color: _Aq.rule, width: 1),
              bottom: pw.BorderSide(color: _Aq.rule, width: 1),
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(34),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(46),
            },
            children: items.map((item) {
              final row = _buildBuceoChecklistRow(item, globalCounter);
              globalCounter++;
              return row;
            }).toList(),
          ),
        );
        widgets.add(pw.SizedBox(height: 14));
      } else {
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            margin: const pw.EdgeInsets.only(top: 15, bottom: 0),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue50,
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                left: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                right: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              ),
            ),
            child: pw.Text(
              category,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.blue900,
              ),
            ),
          ),
        );

        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FixedColumnWidth(35),
              3: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _buildHeaderCell('N°'),
                  _buildHeaderCell('Ítem / Pregunta'),
                  _buildHeaderCell('Est.'),
                  _buildHeaderCell('Observación / Evidencia'),
                ],
              ),
              ...items.map((item) {
                final row = _buildItemRow(item, globalCounter);
                globalCounter++;
                return row;
              }),
            ],
          ),
        );
      }
    }
    return widgets;
  }

  pw.TableRow _buildBuceoChecklistRow(dynamic item, int index) {
    final style = _statusStyleFor(item.respuesta);
    final bool isNC = style.label == 'NC';
    final bool isNA = style.label == 'N/A';
    final bool hasComment = (item.comentario ?? '')
        .toString()
        .trim()
        .isNotEmpty;

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isNC
            ? PdfColor.fromHex('#FFF5F5')
            : (isNA ? _Aq.grayMid : PdfColors.white),
        border: pw.Border(bottom: pw.BorderSide(color: _Aq.rule, width: 0.75)),
      ),
      children: [
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              right: pw.BorderSide(color: _Aq.rule, width: 0.75),
            ),
          ),
          child: pw.Text(
            index.toString().padLeft(2, '0'),
            style: pw.TextStyle(fontSize: 8, color: _Aq.inkFaint),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                item.pregunta,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  color: isNC ? _Aq.red : _Aq.inkMid,
                  fontWeight: isNC ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
              if (hasComment) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  item.comentario.toString().trim(),
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontStyle: pw.FontStyle.italic,
                    color: isNC ? _Aq.red : _Aq.inkFaint,
                  ),
                ),
              ],
              if (item.fotosPaths.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'Contiene evidencia fotografica en el anexo final.',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontStyle: pw.FontStyle.italic,
                    color: _Aq.blue,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: _Aq.rule, width: 0.75),
            ),
          ),
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 2.5,
            ),
            decoration: pw.BoxDecoration(
              color: style.bg,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              style.label,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: style.text,
              ),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.TableRow _buildItemRow(dynamic item, int index) {
    final isNC = item.respuesta == "NC";
    final isIntolerable = item.criticidad == "Intolerable" && isNC;

    return pw.TableRow(
      decoration: isIntolerable
          ? const pw.BoxDecoration(color: PdfColors.red100)
          : (isNC ? const pw.BoxDecoration(color: PdfColors.orange50) : null),
      children: [
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text("$index", style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(item.pregunta, style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            item.respuesta,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 7,
              color: isNC ? PdfColors.red : PdfColors.black,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (item.comentario != null && item.comentario!.isNotEmpty)
                pw.Text(
                  item.comentario!,
                  style: const pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.grey700,
                  ),
                ),
              if (item.fotosPaths.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  "Contiene evidencia fotografica en el anexo final.",
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // pw.Widget _buildHeaderBuceo(InspectionReportData data, pw.MemoryImage? logo) {
  //   return pw.Container(
  //     decoration: pw.BoxDecoration(
  //       border: pw.Border.all(color: PdfColors.black, width: 0.5),
  //     ),
  //     padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  //     margin: const pw.EdgeInsets.only(bottom: 10),
  //     child: pw.Row(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Expanded(
  //           flex: 4,
  //           child: pw.Column(
  //             crossAxisAlignment: pw.CrossAxisAlignment.start,
  //             children: [
  //               pw.Text(
  //                 "INFORME TÉCNICO",
  //                 style: pw.TextStyle(
  //                   fontWeight: pw.FontWeight.bold,
  //                   fontSize: 14,
  //                 ),
  //               ),
  //               pw.Text(
  //                 data.tipoFaena,
  //                 style: pw.TextStyle(
  //                   fontWeight: pw.FontWeight.bold,
  //                   fontSize: 9,
  //                   color: PdfColors.blue900,
  //                 ),
  //               ),
  //               pw.Text(
  //                 "JF INNOVA",
  //                 style: pw.TextStyle(
  //                   fontWeight: pw.FontWeight.bold,
  //                   fontSize: 8,
  //                   color: PdfColors.grey500,
  //                 ),
  //               ),
  //               pw.SizedBox(height: 5),
  //               _rowInfo("ÁREA:", data.area),
  //               _rowInfo("CENTRO:", data.centro),
  //               _rowInfo("ENCARGADO C.:", data.encargadoCentro ?? "N/A"),
  //               _rowInfo("PROFESIONAL:", data.profesional ?? "N/A"),
  //               _rowInfo("FECHA:", data.fecha),
  //             ],
  //           ),
  //         ),
  //         pw.SizedBox(width: 10),
  //         pw.Expanded(
  //           flex: 4,
  //           child: pw.Column(
  //             crossAxisAlignment: pw.CrossAxisAlignment.start,
  //             children: [
  //               pw.SizedBox(height: 28),
  //               _rowInfo("EMPRESA:", data.empresaContratista),
  //               _rowInfo("EMBARCACIÓN:", data.embarcacion),
  //               _rowInfo("MATRÍCULA:", data.matricula),
  //               _rowInfo("SUPERVISOR:", data.supervisor),
  //             ],
  //           ),
  //         ),
  //         pw.Expanded(
  //           flex: 3,
  //           child: pw.Column(
  //             crossAxisAlignment: pw.CrossAxisAlignment.end,
  //             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //             children: [
  //               pw.Container(
  //                 height: 35,
  //                 alignment: pw.Alignment.topRight,
  //                 child: logo != null
  //                     ? pw.Image(logo, fit: pw.BoxFit.contain)
  //                     : pw.Text(""),
  //               ),
  //               pw.SizedBox(height: 5),
  //               pw.Column(
  //                 crossAxisAlignment: pw.CrossAxisAlignment.end,
  //                 children: [
  //                   pw.Container(
  //                     padding: const pw.EdgeInsets.symmetric(
  //                       horizontal: 6,
  //                       vertical: 2,
  //                     ),
  //                     decoration: pw.BoxDecoration(
  //                       border: pw.Border.all(width: 1),
  //                     ),
  //                     child: pw.Text(
  //                       "N° INFORME: ${data.numeroReporte}",
  //                       style: pw.TextStyle(
  //                         fontWeight: pw.FontWeight.bold,
  //                         fontSize: 9,
  //                       ),
  //                     ),
  //                   ),
  //                   pw.SizedBox(height: 2),
  //                   pw.Text(
  //                     data.esConsecutiva ? "(CONSECUTIVA)" : "(INICIAL)",
  //                     style: pw.TextStyle(
  //                       fontSize: 8,
  //                       fontWeight: pw.FontWeight.bold,
  //                       color: PdfColors.grey700,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  pw.Widget _buildTechnicalDetails(InspectionReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "DETALLES TÉCNICOS Y EQUIPAMIENTO",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
              pw.Text(
                "HORARIO AUDITORIA: ${data.horaInicio ?? '--:--'} - ${data.horaTermino ?? '--:--'}",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildCell("Equipo", isHeader: true),
                  _buildCell("Matrícula", isHeader: true),
                  _buildCell("Vigencia", isHeader: true),
                  _buildCell("Vigencia P.H.", isHeader: true),
                  _buildCell("N° Buzos", isHeader: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildCell("Compresor 1"),
                  _buildCell(data.compresor1Matricula ?? "-"),
                  _buildCell(data.compresor1Vigencia ?? "-"),
                  _buildCell(data.compresor1PH ?? "-"),
                  _buildCell(data.compresor1Buzos ?? "0"),
                ],
              ),
              if (data.compresor2Matricula != null)
                pw.TableRow(
                  children: [
                    _buildCell("Compresor 2"),
                    _buildCell(data.compresor2Matricula ?? "-"),
                    _buildCell(data.compresor2Vigencia ?? "-"),
                    _buildCell(data.compresor2PH ?? "-"),
                    _buildCell(data.compresor2Buzos ?? "0"),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatusAndStats(InspectionReportData data) {
    final estadoUpper = data.estadoGlobal.toUpperCase();
    final bool esCritico = estadoUpper.contains("SUSPENDIDA");
    final PdfColor colorEstado = esCritico
        ? PdfColors.red800
        : PdfColors.green800;
    final PdfColor bgEstado = esCritico ? PdfColors.red100 : PdfColors.green100;

    // 🟢 MATEMÁTICAS ESTRICTAS: Porcentaje usa pesos, display usa conteos
    double totalPesoAplicable = data.sumPesoCumple + data.sumPesoNoCumple;

    String pctCumple() {
      if (totalPesoAplicable == 0) return "0%";
      return "${((data.sumPesoCumple / totalPesoAplicable) * 100).round()}%";
    }

    String pctNoCumple() {
      if (totalPesoAplicable == 0) return "0%";
      return "${((data.sumPesoNoCumple / totalPesoAplicable) * 100).round()}%";
    }

    // Helper ajustado para recibir el texto del porcentaje directamente
    pw.Widget statBox(
      String label,
      int count,
      String pctText,
      PdfColor bg,
      PdfColor borderCol,
      PdfColor textCol,
    ) {
      return pw.Expanded(
        child: pw.Container(
          height: 45,
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: borderCol, width: 0.5),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                  color: textCol,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "$count  ($pctText)",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: textCol,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10),
      child: pw.Row(
        children: [
          if (!data.tipoFaena.contains('EMBARCACIÓN')) ...[
            pw.Expanded(
              flex: 3,
              child: pw.Container(
                height: 45,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  color: bgEstado,
                  border: pw.Border.all(color: colorEstado, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      "ESTADO FINAL DE FAENA",
                      style: pw.TextStyle(
                        fontSize: 6,
                        color: colorEstado,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      estadoUpper,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: colorEstado,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 8),
          ],

          // 🟢 CAJITAS CON EL NUEVO CÁLCULO
          statBox(
            "CUMPLE",
            data.totalCumple,
            pctCumple(),
            PdfColors.green50,
            PdfColors.green200,
            PdfColors.green800,
          ),
          statBox(
            "NO CUMPLE",
            data.totalNoCumple,
            pctNoCumple(),
            PdfColors.orange50,
            PdfColors.orange200,
            PdfColors.orange900,
          ),
          statBox(
            "NO APLICA",
            data.totalNoAplica,
            "-",
            PdfColors.grey100,
            PdfColors.grey300,
            PdfColors.grey700,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  pw.Widget _statCell(String text, PdfColor color, {bool isBold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );

  pw.Widget _buildPersonnelTable(InspectionReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "EQUIPO DE TRABAJO / PERSONAL",
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2.0),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children:
                  [
                        "Nombre Completo",
                        "RUT",
                        "Matricula",
                        "Cargo",
                        "Condición Fisica",
                      ]
                      .map(
                        (e) => pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(
                            e,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      )
                      .toList(),
            ),
            ...data.equipo.map(
              (p) => pw.TableRow(
                children: [p.nombre, p.rut, p.matricula, p.cargo, p.rolEnFaena]
                    .map(
                      (val) => pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          val,
                          style: const pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Text(
              "Supervisor Responsable: ",
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              "${data.supervisor}   |   ",
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ],
    );
  }

  List<pw.Widget> _buildGeneralGallery(List<String> fotosPaths) {
    if (fotosPaths.isEmpty) return [];

    List<pw.Widget> widgets = [
      _buildBuceoSectionHeader(
        title: 'Evidencia Fotografica General',
        subtitle: 'Registro visual de la faena',
      ),
    ];

    List<pw.Widget> cards = [];
    int index = 1;

    for (var path in fotosPaths) {
      final file = File(path);
      if (file.existsSync()) {
        cards.add(
          pw.Container(
            width: 130,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _Aq.grayLight,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _Aq.teal, width: 1.4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  index.toString().padLeft(2, '0'),
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: _Aq.inkFaint,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                _buildPhotoThumb(path, width: 114, height: 84),
              ],
            ),
          ),
        );
      }
      index++;
    }

    widgets.addAll(_buildCardRows(cards, columns: 4));

    return widgets;
  }

  static const String _pdfVersion = '0.2.0';

  pw.Widget _buildFooter(pw.Context context, InspectionReportData data) {
    if (data.tipoFaena.contains('BUCEO')) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_Aq.blue, _Aq.tealMid]),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado por Servimaf  |  +56 9 8383 3177  |  v$_pdfVersion',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Informe N°${data.numeroReporte}  ·  Pag. ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 5),
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
              "Generado por Servimaf  |  +56 9 8383 3177  |  v$_pdfVersion",
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
            ),
            pw.Text(
              "Pág. ${context.pageNumber}/${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildSafetyChecklist(InspectionReportData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(4),
            color: PdfColors.grey200,
            child: pw.Text(
              "VERIFICACIONES CRÍTICAS DE SEGURIDAD (FAENA)",
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          ...data.verificacionesBuceo.entries.map((entry) {
            bool isBool = entry.value is bool;
            bool isCumple = isBool && (entry.value == true);
            String textoMostrar = isBool
                ? (isCumple ? "CUMPLE" : "NO CUMPLE")
                : entry.value.toString();
            PdfColor colorTexto = isBool
                ? (isCumple ? PdfColors.green700 : PdfColors.red700)
                : PdfColors.black;

            String romanKey = entry.key.split('.').first.trim();
            String? observacion = data.safetyObservations[romanKey];
            bool tieneObs = observacion != null && observacion.isNotEmpty;

            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        entry.key,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        textoMostrar,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: colorTexto,
                        ),
                      ),
                    ],
                  ),
                  if (tieneObs) ...[
                    pw.SizedBox(height: 2),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8),
                      child: pw.Text(
                        "Obs: $observacion",
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildGeneralObservations(InspectionReportData data) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.white,
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 10,
                color: PdfColors.blue800,
                margin: const pw.EdgeInsets.only(right: 5),
              ),
              pw.Text(
                "OBSERVACIONES GENERALES",
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Text(
            (data.observacionPrevencionista.isNotEmpty)
                ? data.observacionPrevencionista
                : "Sin observaciones registradas.",
            style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildResumenNoCumple(InspectionReportData data) {
    // Agrupar por categoría preservando orden de `orden ASC`
    Map<String, List<InspectionItemDto>> groupedItems = {};
    for (var item in data.items) {
      if (!groupedItems.containsKey(item.categoria)) {
        groupedItems[item.categoria] = [];
      }
      groupedItems[item.categoria]!.add(item);
    }

    final categoriesToRender = groupedItems.keys.toList();

    int globalCounter = 1;
    List<Map<String, dynamic>> hallazgosNC = [];

    for (var category in categoriesToRender) {
      for (var item in groupedItems[category]!) {
        if (item.respuesta == 'NC') {
          hallazgosNC.add({'numero': globalCounter, 'item': item});
        }
        globalCounter++;
      }
    }

    // 🟢 HELPER: MAPEO DE COLORES SEGÚN CRITICIDAD
    PdfColor getColorCriticidad(String criticidad) {
      final crit = criticidad.toLowerCase();
      if (crit.contains('intolerable') || crit.contains('alto')) {
        return PdfColors.red700;
      }
      if (crit.contains('moderado') || crit.contains('medio')) {
        return PdfColors.orange600;
      }
      if (crit.contains('tolerable') || crit.contains('bajo')) {
        return PdfColors.amber600;
      }
      return PdfColors.grey600; // Fallback
    }

    if (hallazgosNC.isEmpty) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Text(
          "Sin hallazgos 'No Cumple' registrados en esta auditoría.",
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.symmetric(horizontal: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "RESUMEN DE HALLAZGOS (NO CUMPLE)",
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 12),

          ...hallazgosNC.map((map) {
            final int num = map['numero'];
            final InspectionItemDto item = map['item'];
            final String criticidadStr = item.criticidad.toUpperCase();
            final PdfColor colorCrit = getColorCriticidad(item.criticidad);
            final bool tieneFotos =
                item.fotosPaths.isNotEmpty; // 🟢 Verificamos si hay fotos

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.only(left: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: colorCrit, width: 3),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 🟢 1. CATEGORÍA Y ETIQUETA DE CRITICIDAD
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        item.categoria.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: colorCrit, width: 0.5),
                        ),
                        child: pw.Text(
                          criticidadStr,
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: colorCrit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),

                  // 🟢 2. PREGUNTA
                  pw.Text(
                    "N° $num: ${item.pregunta}",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 3),

                  // 🟢 3. OBSERVACIÓN
                  pw.Text(
                    "Obs: ${(item.comentario == null || item.comentario!.isEmpty) ? 'Sin observación registrada.' : item.comentario!}",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey800,
                    ),
                  ),

                  // 🟢 4. INDICADOR DE EVIDENCIA (Solo aparece si sacaste foto)
                  if (tieneFotos)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Row(
                        children: [
                          // Simulamos un icono de cámara con texto/símbolos
                          pw.Text(
                            "[+] ",
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue700,
                            ),
                          ),
                          pw.Text(
                            "Contiene evidencia fotográfica en el anexo.",
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // REEMPLAZA ESTE MÉTODO COMPLETO
  List<pw.Widget> _buildFotosObservacion(
    List<Map<String, String>> fotosExtras,
  ) {
    if (fotosExtras.isEmpty) return [];

    List<pw.Widget> widgets = [
      _buildBuceoSectionHeader(
        title: 'Fotografias con Observacion Detallada',
        subtitle:
            'Imagenes con observaciones especificas no registradas en DPR24',
      ),
    ];

    for (var item in fotosExtras) {
      final String path = item['path'] ?? '';
      final String observacion = item['observacion'] ?? 'Sin observación.';
      final file = File(path);

      if (file.existsSync()) {
        // Cada foto es un contenedor independiente que puede saltar de página sin romper el layout
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F7FBFD'),
              border: pw.Border.all(color: PdfColor.fromHex('#CDEAF2')),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPhotoThumb(path, width: 126, height: 86),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Observacion",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey700,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        observacion.isEmpty
                            ? "Sin observación detallada."
                            : observacion,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return widgets;
  }
  // Header Nuevo - Más limpio, diseño nuevo

  // pw.Widget _buildHeaderEmbarcacion(
  //   InspectionReportData data,
  //   pw.MemoryImage? logo,
  // ) {
  //   // Filtrar roles
  //   String patron = data.equipo
  //       .where((p) => p.cargo.toUpperCase().contains('PATR'))
  //       .map((p) => p.nombre)
  //       .join(', ');
  //   String maquinista = data.equipo
  //       .where((p) => p.cargo.toUpperCase().contains('MAQUINISTA'))
  //       .map((p) => p.nombre)
  //       .join(', ');
  //   List<String> tripulantes = data.equipo
  //       .where(
  //         (p) =>
  //             !p.cargo.toUpperCase().contains('PATR') &&
  //             !p.cargo.toUpperCase().contains('MAQUINISTA'),
  //       )
  //       .map((p) => "${p.nombre} (${p.rut})")
  //       .toList();

  //   // Helper para datos en formato "Label encima, Valor abajo" (Más moderno)
  //   pw.Widget infoDato(String label, String value) {
  //     return pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Text(
  //           label,
  //           style: pw.TextStyle(
  //             fontSize: 7,
  //             fontWeight: pw.FontWeight.bold,
  //             color: PdfColors.grey700,
  //           ),
  //         ),
  //         pw.SizedBox(height: 2),
  //         pw.Text(
  //           value.isEmpty ? "N/A" : value,
  //           style: pw.TextStyle(
  //             fontSize: 9,
  //             fontWeight: pw.FontWeight.bold,
  //             color: PdfColors.black,
  //           ),
  //         ),
  //       ],
  //     );
  //   }

  //   return pw.Column(
  //     crossAxisAlignment: pw.CrossAxisAlignment.start,
  //     children: [
  //       pw.SizedBox(height: 25),
  //       pw.Row(
  //         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //         crossAxisAlignment: pw.CrossAxisAlignment.start,
  //         children: [
  //           // --- LADO IZQUIERDO ---
  //           pw.Padding(
  //             padding: const pw.EdgeInsets.only(left: 10),
  //             child: pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Text(
  //                   "INFORME TÉCNICO",
  //                   style: pw.TextStyle(
  //                     fontSize: 18,
  //                     fontWeight: pw.FontWeight.bold,
  //                     color: PdfColors.blue900,
  //                   ),
  //                 ),
  //                 pw.Text(
  //                   data.tipoFaena,
  //                   style: pw.TextStyle(
  //                     fontSize: 11,
  //                     fontWeight: pw.FontWeight.bold,
  //                     color: PdfColors.grey700,
  //                   ),
  //                 ),
  //                 pw.SizedBox(height: 10),
  //                 // 🟢 EL PROFESIONAL AHORA VIVE AQUÍ
  //                 pw.Text(
  //                   "PROFESIONAL A CARGO:",
  //                   style: pw.TextStyle(
  //                     fontSize: 9,
  //                     fontWeight: pw.FontWeight.bold,
  //                     color: PdfColors.grey500,
  //                   ),
  //                 ),
  //                 pw.Text(
  //                   data.profesional ?? "N/A",
  //                   style: pw.TextStyle(
  //                     fontSize: 12,
  //                     fontWeight: pw.FontWeight.bold,
  //                     color: PdfColors.black,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),

  //           // --- LADO DERECHO ---
  //           pw.Padding(
  //             padding: const pw.EdgeInsets.only(right: 10),
  //             child: pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.end,
  //               children: [
  //                 if (logo != null) ...[
  //                   pw.Container(
  //                     height: 45,
  //                     child: pw.Image(logo, fit: pw.BoxFit.contain),
  //                   ),
  //                   pw.SizedBox(height: 8),
  //                 ],
  //                 // 🟢 FOLIO Y ESTADO ALINEADOS A LA DERECHA
  //                 pw.Container(
  //                   padding: const pw.EdgeInsets.symmetric(
  //                     horizontal: 10,
  //                     vertical: 4,
  //                   ),
  //                   decoration: pw.BoxDecoration(
  //                     color: PdfColors.red50,
  //                     border: pw.Border.all(color: PdfColors.red200),
  //                     borderRadius: const pw.BorderRadius.all(
  //                       pw.Radius.circular(4),
  //                     ),
  //                   ),
  //                   child: pw.Column(
  //                     crossAxisAlignment: pw.CrossAxisAlignment.center,
  //                     children: [
  //                       pw.Text(
  //                         "Informe N° ${data.numeroReporte}",
  //                         style: pw.TextStyle(
  //                           fontSize: 11,
  //                           fontWeight: pw.FontWeight.bold,
  //                           color: PdfColors.red900,
  //                         ),
  //                       ),
  //                       pw.Text(
  //                         data.esConsecutiva ? "(CONSECUTIVA)" : "(INICIAL)",
  //                         style: pw.TextStyle(
  //                           fontSize: 7,
  //                           fontWeight: pw.FontWeight.bold,
  //                           color: PdfColors.red700,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //       pw.SizedBox(height: 15),

  //       // 🟢 2. TARJETA DE DATOS GENERALES (Diseño Dashboard)
  //       pw.Container(
  //         padding: const pw.EdgeInsets.all(12),
  //         decoration: pw.BoxDecoration(
  //           color: PdfColors.grey100,
  //           border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
  //           borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
  //         ),
  //         child: pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //           children: [
  //             pw.Text(
  //               "DATOS GENERALES DE LA AUDITORÍA",
  //               style: pw.TextStyle(
  //                 fontSize: 9,
  //                 fontWeight: pw.FontWeight.bold,
  //                 color: PdfColors.blue800,
  //               ),
  //             ),
  //             pw.Divider(color: PdfColors.grey400, thickness: 0.5),
  //             pw.SizedBox(height: 6),

  //             // Fila 1: Nave
  //             pw.Row(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Expanded(
  //                   flex: 2,
  //                   child: infoDato("EMBARCACIÓN", data.embarcacion),
  //                 ),
  //                 pw.Expanded(
  //                   flex: 2,
  //                   child: infoDato("MATRÍCULA", data.matricula),
  //                 ),
  //                 pw.Expanded(
  //                   flex: 3,
  //                   child: infoDato("EMPRESA CONT.", data.empresaContratista),
  //                 ),
  //               ],
  //             ),
  //             pw.SizedBox(height: 10),

  //             // Fila 2: Ubicación y Correo
  //             pw.Row(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Expanded(flex: 2, child: infoDato("ÁREA", data.area)),
  //                 pw.Expanded(flex: 2, child: infoDato("CENTRO", data.centro)),
  //                 pw.Expanded(
  //                   flex: 3,
  //                   child: infoDato(
  //                     "CORREO",
  //                     data.correoEmpresaServicios ?? "-",
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             pw.SizedBox(height: 10),

  //             // 🟢 Fila 3: Tiempos y el Prevencionista que faltaba
  //             pw.Row(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Expanded(flex: 2, child: infoDato("FECHA", data.fecha)),
  //                 pw.Expanded(
  //                   flex: 2,
  //                   child: infoDato(
  //                     "HORARIO",
  //                     "${data.horaInicio ?? '--:--'} a ${data.horaTermino ?? '--:--'}",
  //                   ),
  //                 ),
  //                 // 🟢 EL TRUCO: Un contenedor vacío que ocupa el espacio del Profesional
  //                 // para obligar a la fecha y al horario a respetar la cuadrícula de arriba.
  //                 pw.Expanded(flex: 3, child: pw.SizedBox()),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //       pw.SizedBox(height: 10),

  //       // 🟢 3. TARJETA DE DOTACIÓN (Sigue el mismo estilo)
  //       pw.Container(
  //         padding: const pw.EdgeInsets.all(12),
  //         decoration: pw.BoxDecoration(
  //           color: PdfColors.white,
  //           border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
  //           borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
  //         ),
  //         child: pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //           children: [
  //             pw.Text(
  //               "DOTACIÓN DE LA EMBARCACIÓN",
  //               style: pw.TextStyle(
  //                 fontSize: 9,
  //                 fontWeight: pw.FontWeight.bold,
  //                 color: PdfColors.blue800,
  //               ),
  //             ),
  //             pw.Divider(color: PdfColors.grey400, thickness: 0.5),
  //             pw.SizedBox(height: 6),
  //             pw.Row(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Expanded(child: infoDato("PATRÓN", patron)),
  //                 pw.Expanded(child: infoDato("MAQUINISTA", maquinista)),
  //               ],
  //             ),
  //             pw.SizedBox(height: 10),
  //             infoDato(
  //               "TRIPULANTES",
  //               tripulantes.isEmpty
  //                   ? "Sin tripulantes extra registrados."
  //                   : tripulantes.join('   |   '),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Header Exactamente como en PDF Embarcación, pero con código limpio y organizado

  // pw.Widget _buildHeaderEmbarcacion(
  //   InspectionReportData data,
  //   pw.MemoryImage? logo,
  // ) {
  //   // Filtrar roles de la cuadrilla
  //   String patron = data.equipo
  //       .where((p) => p.cargo.toUpperCase().contains('PATR'))
  //       .map((p) => p.nombre)
  //       .join(', ');
  //   String maquinista = data.equipo
  //       .where((p) => p.cargo.toUpperCase().contains('MAQUINISTA'))
  //       .map((p) => p.nombre)
  //       .join(', ');
  //   List<String> tripulantes = data.equipo
  //       .where(
  //         (p) =>
  //             !p.cargo.toUpperCase().contains('PATR') &&
  //             !p.cargo.toUpperCase().contains('MAQUINISTA'),
  //       )
  //       .map((p) => "${p.nombre} (${p.rut})")
  //       .toList();

  //   // Helper para celdas
  //   pw.Widget celda(
  //     String txt, {
  //     bool isHeader = false,
  //     PdfColor bg = PdfColors.white,
  //   }) {
  //     return pw.Container(
  //       color: bg,
  //       padding: const pw.EdgeInsets.all(6),
  //       alignment: pw.Alignment.centerLeft,
  //       child: pw.Text(
  //         txt,
  //         style: pw.TextStyle(
  //           fontSize: 8,
  //           fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
  //         ),
  //       ),
  //     );
  //   }

  //   final gris = PdfColors.grey200;

  //   return pw.Padding(
  //     padding: const pw.EdgeInsets.only(
  //       left: 10,
  //     ), // 🟢 1. Separación de la pared izquierda
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.SizedBox(
  //           height: 25,
  //         ), // 🟢 2. Bajar un poquito el encabezado del techo de la hoja
  //         // 🟢 FILA SUPERIOR: TÍTULOS Y LOGO
  //         pw.Row(
  //           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //           children: [
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Text(
  //                   "INFORME TÉCNICO",
  //                   style: pw.TextStyle(
  //                     fontSize: 16,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //                 pw.Text(
  //                   data.tipoFaena,
  //                   style: pw.TextStyle(
  //                     fontSize: 10,
  //                     fontWeight: pw.FontWeight.bold,
  //                     color: PdfColors.blue900,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             if (logo != null)
  //               pw.Container(
  //                 height: 50,
  //                 child: pw.Image(logo, fit: pw.BoxFit.contain),
  //               ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 12),

  //         // 🟢 TABLA 1: CORRELATIVO (Con Inicial/Consecutiva)
  //         pw.Table(
  //           border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
  //           columnWidths: {
  //             0: const pw.FlexColumnWidth(7),
  //             1: const pw.FlexColumnWidth(2),
  //             2: const pw.FlexColumnWidth(1.5),
  //           },
  //           children: [
  //             pw.TableRow(
  //               children: [
  //                 pw.Container(), // Espacio vacío a la izquierda
  //                 celda("CORRELATIVO N°", isHeader: true, bg: gris),
  //                 pw.Container(
  //                   color: PdfColors.white,
  //                   alignment: pw.Alignment.center,
  //                   padding: const pw.EdgeInsets.symmetric(
  //                     vertical: 4,
  //                     horizontal: 2,
  //                   ),
  //                   child: pw.Column(
  //                     mainAxisAlignment: pw.MainAxisAlignment.center,
  //                     children: [
  //                       pw.Text(
  //                         data.numeroReporte,
  //                         style: pw.TextStyle(
  //                           fontSize: 10,
  //                           fontWeight: pw.FontWeight.bold,
  //                           color: PdfColors.red800,
  //                         ),
  //                       ),
  //                       pw.SizedBox(height: 2),
  //                       pw.Text(
  //                         data.esConsecutiva ? "(CONSECUTIVA)" : "(INICIAL)",
  //                         style: pw.TextStyle(
  //                           fontSize: 6,
  //                           fontWeight: pw.FontWeight.bold,
  //                           color: PdfColors.grey700,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),

  //         // 🟢 TABLA 2: DATOS PRINCIPALES (AHORA CON HORARIO)
  //         pw.Table(
  //           border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
  //           columnWidths: {
  //             0: const pw.FlexColumnWidth(2),
  //             1: const pw.FlexColumnWidth(3.5),
  //             2: const pw.FlexColumnWidth(2),
  //             3: const pw.FlexColumnWidth(3.5),
  //           },
  //           children: [
  //             pw.TableRow(
  //               children: [
  //                 celda("EMBARCACIÓN", isHeader: true, bg: gris),
  //                 celda(data.embarcacion),
  //                 celda("FECHA", isHeader: true, bg: gris),
  //                 celda(data.fecha),
  //               ],
  //             ),
  //             pw.TableRow(
  //               children: [
  //                 celda("ÁREA", isHeader: true, bg: gris),
  //                 celda(data.area),
  //                 celda("CENTRO", isHeader: true, bg: gris),
  //                 celda(data.centro),
  //               ],
  //             ),
  //             pw.TableRow(
  //               children: [
  //                 celda("EMPRESA", isHeader: true, bg: gris),
  //                 celda(data.empresaContratista),
  //                 celda("PATRÓN", isHeader: true, bg: gris),
  //                 celda(patron.isEmpty ? "N/A" : patron),
  //               ],
  //             ),
  //             pw.TableRow(
  //               children: [
  //                 celda("MAQUINISTA", isHeader: true, bg: gris),
  //                 celda(maquinista.isEmpty ? "N/A" : maquinista),
  //                 celda("MATRÍCULA", isHeader: true, bg: gris),
  //                 celda(data.matricula),
  //               ],
  //             ),
  //             // 🟢 3. SE AGREGÓ LA FILA DEL HORARIO
  //             pw.TableRow(
  //               children: [
  //                 celda("HORARIO", isHeader: true, bg: gris),
  //                 celda(
  //                   "${data.horaInicio ?? '--:--'} a ${data.horaTermino ?? '--:--'}",
  //                 ),
  //                 celda("", bg: gris),
  //                 celda(""), // Celdas vacías para equilibrar la tabla
  //               ],
  //             ),
  //           ],
  //         ),

  //         // 🟢 TABLA 3: TRIPULANTES
  //         pw.Table(
  //           border: const pw.TableBorder(
  //             left: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
  //             right: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
  //             bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
  //             verticalInside: pw.BorderSide(
  //               width: 0.5,
  //               color: PdfColors.grey600,
  //             ),
  //           ),
  //           columnWidths: {
  //             0: const pw.FlexColumnWidth(2),
  //             1: const pw.FlexColumnWidth(9),
  //           },
  //           children: [
  //             pw.TableRow(
  //               children: [
  //                 celda("TRIPULANTES", isHeader: true, bg: gris),
  //                 pw.Container(
  //                   padding: const pw.EdgeInsets.all(6),
  //                   child: pw.Text(
  //                     tripulantes.isEmpty
  //                         ? "Sin tripulantes extra registrados."
  //                         : tripulantes.join('   |   '),
  //                     style: const pw.TextStyle(fontSize: 8),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),

  //         // 🟢 TABLA 4: FIRMAS/CONTACTO
  //         pw.Table(
  //           border: const pw.TableBorder(
  //             left: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
  //             right: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
  //             bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
  //             verticalInside: pw.BorderSide(
  //               width: 0.5,
  //               color: PdfColors.grey600,
  //             ),
  //           ),
  //           columnWidths: {
  //             0: const pw.FlexColumnWidth(3.5),
  //             1: const pw.FlexColumnWidth(3.5),
  //             2: const pw.FlexColumnWidth(2.5),
  //             3: const pw.FlexColumnWidth(3),
  //           },
  //           children: [
  //             pw.TableRow(
  //               children: [
  //                 celda("PROFESIONAL QUE EMITE", isHeader: true, bg: gris),
  //                 celda(data.profesional ?? "N/A"),
  //                 celda("CORREO SERVICIOS", isHeader: true, bg: gris),
  //                 celda(data.correoEmpresaServicios ?? "N/A"),
  //               ],
  //             ),
  //           ],
  //         ),

  //         pw.SizedBox(height: 10), // Margen inferior antes del bloque de estado
  //       ],
  //     ),
  //   );
  // }
  // 🟢 HELPER ESTÁTICO: Fuera del scope del renderizado para no saturar memoria RAM
  static pw.Widget _infoDato(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value.isEmpty ? "N/A" : value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  // 🟢 1. ENRUTADOR PRINCIPAL
  pw.Widget _buildHeader(InspectionReportData data, pw.MemoryImage? logo) {
    if (data.tipoFaena.contains('EMBARCACIÓN')) {
      // Usa la arquitectura moderna modular (Dashboard)
      return _buildUniversalHeader(
        data: data,
        logo: logo,
        tarjetaDatosGenerales: _buildDatosGeneralesEmbarcacion(data),
        tarjetaResponsables: _buildDotacionEmbarcacion(data),
      );
    } else {
      // Usa la vista Legacy (Clásica) que solicitaste para Buceo
      return _buildHeaderBuceoLegacy(data, logo);
    }
  }

  // 🟢 2. TU DISEÑO CLÁSICO DE BUCEO
  pw.Widget _buildHeaderBuceoLegacy(
    InspectionReportData data,
    pw.MemoryImage? logo,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "INFORME TÉCNICO",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.Text(
                  data.tipoFaena,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  data.empresaProveedor,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.SizedBox(height: 5),
                _rowInfo("ÁREA:", data.area),
                _rowInfo("CENTRO:", data.centro),
                _rowInfo("ENCARGADO C.:", data.encargadoCentro ?? "N/A"),
                _rowInfo("PROFESIONAL:", data.profesional ?? "N/A"),
                _rowInfo("FECHA:", data.fecha),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 28),
                _rowInfo("EMPRESA:", data.empresaContratista),
                _rowInfo("EMBARCACIÓN:", data.embarcacion),
                _rowInfo("MATRÍCULA:", data.matricula),
                _rowInfo("SUPERVISOR:", data.supervisor),
              ],
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  height: 35,
                  alignment: pw.Alignment.topRight,
                  child: logo != null
                      ? pw.Image(logo, fit: pw.BoxFit.contain)
                      : pw.Text(""),
                ),
                pw.SizedBox(height: 5),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 1),
                      ),
                      child: pw.Text(
                        "N° INFORME: ${data.numeroReporte}",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      data.esConsecutiva ? "(CONSECUTIVA)" : "(INICIAL)",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 3. NO OLVIDES MANTENER TU HELPER
  pw.Widget _rowInfo(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.toUpperCase(),
              style: const pw.TextStyle(fontSize: 7),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 2. SKELETON UNIVERSAL (Adiós DRY)
  pw.Widget _buildUniversalHeader({
    required InspectionReportData data,
    required pw.MemoryImage? logo,
    required pw.Widget tarjetaDatosGenerales,
    required pw.Widget tarjetaResponsables,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 25),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // --- LADO IZQUIERDO ---
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "INFORME TÉCNICO",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    data.tipoFaena,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    "PROFESIONAL A CARGO:",
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    data.profesional ?? "N/A",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
            // --- LADO DERECHO ---
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (logo != null) ...[
                    pw.Container(
                      height: 45,
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      border: pw.Border.all(color: PdfColors.red200),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          "Informe N° ${data.numeroReporte}",
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                        pw.Text(
                          data.esConsecutiva ? "(CONSECUTIVA)" : "(INICIAL)",
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 15),
        // INYECCIÓN DE COMPONENTES ESPECÍFICOS
        tarjetaDatosGenerales,
        pw.SizedBox(height: 10),
        tarjetaResponsables,
      ],
    );
  }

  // 🟢 3. IMPLEMENTACIONES ESPECÍFICAS (Copia el contenido interior de tus contenedores originales aquí)

  // -- EMBARCACIÓN --
  pw.Widget _buildDatosGeneralesEmbarcacion(InspectionReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "DATOS GENERALES DE LA AUDITORÍA",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoDato("EMBARCACIÓN", data.embarcacion),
                    pw.SizedBox(height: 8),
                    _infoDato("ÁREA", data.area),
                    pw.SizedBox(height: 8),
                    _infoDato("FECHA", data.fecha),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoDato("MATRÍCULA", data.matricula),
                    pw.SizedBox(height: 8),
                    _infoDato("CENTRO", data.centro),
                    pw.SizedBox(height: 8),
                    _infoDato(
                      "HORARIO",
                      "${data.horaInicio ?? '--:--'} a ${data.horaTermino ?? '--:--'}",
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoDato("EMPRESA CONT.", data.empresaContratista),
                    pw.SizedBox(height: 8),
                    _infoDato("CORREO", data.correoEmpresaServicios ?? "-"),
                    pw.SizedBox(height: 8),
                    _infoDato("N° ZARPE", data.numeroZarpe ?? "S/N"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDotacionEmbarcacion(InspectionReportData data) {
    // Filtros de Roles
    String patron = data.equipo
        .where((p) => p.cargo.toUpperCase().contains('PATR'))
        .map((p) => p.nombre)
        .join(', ');
    String maquinista = data.equipo
        .where((p) => p.cargo.toUpperCase().contains('MAQUINISTA'))
        .map((p) => p.nombre)
        .join(', ');
    List<String> tripulantes = data.equipo
        .where(
          (p) =>
              !p.cargo.toUpperCase().contains('PATR') &&
              !p.cargo.toUpperCase().contains('MAQUINISTA'),
        )
        .map((p) => "${p.nombre} (${p.rut})")
        .toList();

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "DOTACIÓN DE LA EMBARCACIÓN",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(child: _infoDato("PATRÓN", patron)),
              pw.Expanded(child: _infoDato("MAQUINISTA", maquinista)),
            ],
          ),
          pw.SizedBox(height: 10),
          _infoDato(
            "TRIPULANTES",
            tripulantes.isEmpty
                ? "Sin tripulantes extra registrados."
                : tripulantes.join('   |   '),
          ),
        ],
      ),
    );
  }

  // -- BUCEO --
  // ignore: unused_element
  pw.Widget _buildDatosGeneralesBuceo(InspectionReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "DATOS GENERALES DE LA AUDITORÍA",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(flex: 2, child: _infoDato("ÁREA", data.area)),
              pw.Expanded(flex: 2, child: _infoDato("CENTRO", data.centro)),
              pw.Expanded(
                flex: 2,
                child: _infoDato("EMPRESA CONT.", data.empresaContratista),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(flex: 2, child: _infoDato("FECHA", data.fecha)),
              pw.Expanded(
                flex: 2,
                child: _infoDato(
                  "HORARIO",
                  "${data.horaInicio ?? '--:--'} a ${data.horaTermino ?? '--:--'}",
                ),
              ),
              pw.Expanded(flex: 3, child: pw.SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  pw.Widget _buildResponsablesBuceo(InspectionReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "RESPONSABLES DE FAENA",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: _infoDato(
                  "ENCARGADO DE CENTRO",
                  data.encargadoCentro ?? "N/A",
                ),
              ),
              pw.Expanded(
                child: _infoDato("SUPERVISOR CONTRATISTA", data.supervisor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
