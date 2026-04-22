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
        // 👇 ELIMINAMOS EL PARAMETRO 'header:' QUE LO REPETÍA EN TODAS LAS PÁGINAS 👇
        footer: (context) => _buildFooter(context, data),
        build: (context) => [
          // 1. EL ENCABEZADO (Buceo o Embarcación)
          _buildHeader(data, logoImage),

          pw.SizedBox(height: 15),

          // 2. ESTADÍSTICAS GENERALES
          _buildStatusAndStats(data),
          pw.SizedBox(height: 10),

          // 3. CONDICIONAL: SI ES BUCEO MOSTRAMOS SUS TABLAS
          if (data.tipoFaena.contains('BUCEO')) ...[
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
          ],

          // 4. OBSERVACIONES GENERALES (Para embarcación sirve para rellenar bien la hoja 1)
          _buildGeneralObservations(data),
          pw.SizedBox(height: 30),

          // 🟢 4.5 NUEVO: RESUMEN EJECUTIVO (Aplica a ambos)
          _buildResumenNoCumple(data),

          // // 5. NUEVO: BLOQUE DE FIRMAS FORMAL (Rellena el final de la primera hoja)
          // pw.Row(
          //   mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          //   children: [
          //     pw.Column(
          //       children: [
          //         pw.Container(width: 150, height: 1, color: PdfColors.black),
          //         pw.SizedBox(height: 5),
          //         pw.Text(
          //           data.profesional ?? "Profesional a Cargo",
          //           style: pw.TextStyle(
          //             fontSize: 9,
          //             fontWeight: pw.FontWeight.bold,
          //           ),
          //         ),
          //         pw.Text(
          //           "Prevencionista de Riesgos",
          //           style: const pw.TextStyle(
          //             fontSize: 8,
          //             color: PdfColors.grey700,
          //           ),
          //         ),
          //       ],
          //     ),
          //     pw.Column(
          //       children: [
          //         pw.Container(width: 150, height: 1, color: PdfColors.black),
          //         pw.SizedBox(height: 5),
          //         pw.Text(
          //           data.tipoFaena.contains('EMBARCACIÓN')
          //               ? "Firma Patrón"
          //               : "Firma Supervisor",
          //           style: pw.TextStyle(
          //             fontSize: 9,
          //             fontWeight: pw.FontWeight.bold,
          //           ),
          //         ),
          //         pw.Text(
          //           "Responsable de Faena",
          //           style: const pw.TextStyle(
          //             fontSize: 8,
          //             color: PdfColors.grey700,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ],
          // ),

          // 6. SALTO DE PÁGINA PARA EL DETALLE
          pw.NewPage(),
          pw.Center(
            child: pw.Text(
              "DETALLE DE VERIFICACIONES",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: PdfColors.blue900, // Un toque de color
              ),
            ),
          ),
          pw.SizedBox(height: 10),

          // 7. LAS TABLAS DE PREGUNTAS Y FOTOS
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
        ],
      ),
    );

    return pdf.save();
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

    List<pw.Widget> widgets = [];
    int globalCounter = 1;

    final categoriesToRender = groupedItems.keys.toList();

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
            }),
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

  static const String _pdfVersion = '0.1.0';

  pw.Widget _buildFooter(pw.Context context, InspectionReportData data) {
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
      pw.Text(
        "     Fotografias con observación detallada o no especificadas en DPR24",
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
