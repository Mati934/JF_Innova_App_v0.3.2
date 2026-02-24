import 'dart:io'; // Importante para leer archivos dentro del Isolate
import 'dart:typed_data';
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

class PdfGeneratorService {
  Future<Uint8List> _generatePdfSync(PdfIsolateParams params) async {
    final pdf = pw.Document();
    final data = params.data;

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(params.fontRegular.buffer.asByteData()),
      bold: pw.Font.ttf(params.fontBold.buffer.asByteData()),
      italic: pw.Font.ttf(params.fontItalic.buffer.asByteData()),
    );

    pw.MemoryImage? logoImage;
    if (params.logoBytes != null) {
      logoImage = pw.MemoryImage(params.logoBytes!);
    }

    // C. PREPARAR FOTOS DE SEGURIDAD LEYENDO DEL DISCO
    List<pw.Widget> safetyPhotoWidgets = [];
    final order = ['IV', 'V', 'VI', 'VII', 'VIII'];

    for (var key in order) {
      final imagePath = data.safetyPhotosPaths[key];
      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (file.existsSync()) {
          // LECTURA DE DISCO EN SEGUNDO PLANO
          final imageBytes = file.readAsBytesSync();
          final image = pw.MemoryImage(imageBytes);

          safetyPhotoWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    width: 90,
                    height: 90,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey, width: 0.5),
                    ),
                    child: pw.Image(image, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    key,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        maxPages: 200,
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          buildBackground: (context) => pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
          ),
        ),
        header: (context) => _buildHeaderDense(data, logoImage),
        footer: (context) => _buildFooter(context, data),
        build: (context) => [
          pw.SizedBox(height: 5),
          _buildStatusAndStats(data),
          pw.SizedBox(height: 10),
          _buildTechnicalDetails(data),
          pw.SizedBox(height: 10),
          _buildPersonnelTable(data),
          pw.SizedBox(height: 10),
          _buildSafetyChecklist(data),

          if (safetyPhotoWidgets.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: safetyPhotoWidgets,
            ),
          ],

          pw.SizedBox(height: 15),
          _buildGeneralObservations(data),
          pw.NewPage(),
          pw.Center(
            child: pw.Text(
              "DETALLE DE VERIFICACIONES",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
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
            ..._buildGeneralGallery(
              data.fotosGeneralesPaths,
            ), // Actualizado a String
            pw.SizedBox(height: 15),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // Uint8List _optimizarImagen(Uint8List rawBytes) {
  //   try {
  //     final img.Image? original = img.decodeImage(rawBytes);
  //     if (original == null) return rawBytes;
  //     final resized = img.copyResize(original, width: 600);
  //     return Uint8List.fromList(img.encodeJpg(resized, quality: 60));
  //   } catch (e) {
  //     return rawBytes;
  //   }
  // }

  List<pw.Widget> _buildCategorizedChecklists(InspectionReportData data) {
    Map<String, List<dynamic>> groupedItems = {};
    final categoryOrder = [
      'EQUIPO PERSONAL',
      'EQUIPO DE BUCEO',
      'SEGURIDAD Y APOYO',
    ];

    for (var item in data.items) {
      if (!groupedItems.containsKey(item.categoria))
        groupedItems[item.categoria] = [];
      groupedItems[item.categoria]!.add(item);
    }

    List<pw.Widget> widgets = [];
    int globalCounter = 1;

    final categoriesToRender = categoryOrder
        .where((c) => groupedItems.containsKey(c))
        .toList();
    for (var k in groupedItems.keys) {
      if (!categoriesToRender.contains(k)) categoriesToRender.add(k);
    }

    for (var category in categoriesToRender) {
      final items = groupedItems[category]!;

      // 1. Añadimos el Header SUELTO al flujo del documento
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

      // 2. Añadimos la Tabla SUELTA. Ahora sí puede saltar de página libremente.
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
                _buildHeaderCell("N°"),
                _buildHeaderCell("Ítem / Pregunta"),
                _buildHeaderCell("Est."),
                _buildHeaderCell("Observación / Evidencia"),
              ],
            ),
            ...items.map((item) {
              final row = _buildItemRow(item, globalCounter);
              globalCounter++;
              return row;
            }).toList(),
          ],
        ),
      );
    }
    return widgets;
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

    List<pw.Widget> fotosWidgets = [];
    int maxFotosEnTabla =
        4; // CORTAFUEGOS: Máximo 4 fotos por pregunta en la tabla
    int fotosExtra = 0;

    if (item.fotosPaths.isNotEmpty) {
      final paths = item.fotosPaths as List<String>;
      for (int i = 0; i < paths.length; i++) {
        // Si superamos el límite, solo contamos cuántas sobraron para avisarle al usuario
        if (i >= maxFotosEnTabla) {
          fotosExtra = paths.length - maxFotosEnTabla;
          break;
        }

        final file = File(paths[i]);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          fotosWidgets.add(
            pw.Container(
              width:
                  50, // Ligeramente más pequeñas para optimizar espacio en celda
              height: 50,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
            ),
          );
        }
      }
    }

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
              if (fotosWidgets.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Wrap(spacing: 4, runSpacing: 4, children: fotosWidgets),
              ],
              // AVISO VISUAL SI HAY EXCESO DE FOTOS
              if (fotosExtra > 0) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  "+ $fotosExtra fotos anexas (Ver galería / sistema)",
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.red800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeaderDense(InspectionReportData data, pw.MemoryImage? logo) {
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
                  "JF INNOVA",
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

  pw.Widget _buildStatusAndStats(InspectionReportData data) {
    final estadoUpper = data.estadoGlobal.toUpperCase();
    final bool esCritico = estadoUpper.contains("SUSPENDIDA");
    final PdfColor colorEstado = esCritico
        ? PdfColors.red800
        : PdfColors.green800;
    final PdfColor bgEstado = esCritico ? PdfColors.red100 : PdfColors.green100;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            height: 45,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: bgEstado,
              border: pw.Border.all(color: colorEstado, width: 1),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  "ESTADO FINAL DE FAENA",
                  style: pw.TextStyle(fontSize: 7, color: colorEstado),
                ),
                pw.Text(
                  data.estadoGlobal.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: colorEstado,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 6,
          child: pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: ["CUMPLE", "NO CUMPLE", "INTOLERABLE", "N/A"]
                    .map(
                      (e) => pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          e,
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    )
                    .toList(),
              ),
              pw.TableRow(
                children: [
                  _statCell(data.totalCumple.toString(), PdfColors.black),
                  _statCell(data.totalNoCumple.toString(), PdfColors.red),
                  _statCell(
                    data.totalIntolerables.toString(),
                    PdfColors.red900,
                    isBold: true,
                  ),
                  _statCell(data.totalNoAplica.toString(), PdfColors.grey),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

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
      pw.Text(
        "EVIDENCIA FOTOGRÁFICA GENERAL",
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 10),
    ];

    List<pw.Widget> filaActual = [];

    for (var path in fotosPaths) {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        filaActual.add(
          pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
            ),
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
        );
      }

      // CLEAN CODE: Algoritmo de Chunking.
      // Cada 4 fotos, cerramos el Wrap y lo inyectamos.
      // Esto permite que el PDF salte de página entre filas sin crashear.
      if (filaActual.length == 4) {
        widgets.add(pw.Wrap(spacing: 5, runSpacing: 5, children: filaActual));
        widgets.add(pw.SizedBox(height: 5));
        filaActual = []; // Vaciamos el buffer para la siguiente fila
      }
    }

    // Inyectamos las fotos sobrantes si la última fila no alcanzó a tener 4
    if (filaActual.isNotEmpty) {
      widgets.add(pw.Wrap(spacing: 5, runSpacing: 5, children: filaActual));
    }

    return widgets;
  }

  pw.Widget _buildFooter(pw.Context context, InspectionReportData data) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "Versión App: ${data.appVersion}",
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
          ),
          pw.Text(
            "Generado por JF Innova App - Pág. ${context.pageNumber}/${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
          ),
        ],
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
          }).toList(),
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

  // REEMPLAZA ESTE MÉTODO COMPLETO
  List<pw.Widget> _buildFotosObservacion(
    List<Map<String, String>> fotosExtras,
  ) {
    if (fotosExtras.isEmpty) return [];

    List<pw.Widget> widgets = [
      pw.Text(
        "FOTOGRAFÍAS CON OBSERVACIÓN DETALLADA",
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      pw.SizedBox(height: 10),
    ];

    for (var item in fotosExtras) {
      final String path = item['path'] ?? '';
      final String observacion = item['observacion'] ?? 'Sin observación.';
      final file = File(path);

      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();

        // Cada foto es un contenedor independiente que puede saltar de página sin romper el layout
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 100,
                  height: 100,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Observación:",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
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
}
