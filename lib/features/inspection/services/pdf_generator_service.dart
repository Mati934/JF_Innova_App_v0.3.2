import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/models/pdf/inspection_report_data.dart';

class PdfGeneratorService {
  Future<Uint8List> generatePdf(InspectionReportData data) async {
    final pdf = pw.Document();

    // 1. CARGA DE RECURSOS OFFLINE
    final fontRegular = await rootBundle.load(
      "assets/fonts/OpenSans-Regular.ttf",
    );
    final fontBold = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
    final fontItalic = await rootBundle.load(
      "assets/fonts/OpenSans-Italic.ttf",
    );

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(fontRegular),
      bold: pw.Font.ttf(fontBold),
      italic: pw.Font.ttf(fontItalic),
    );

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load(
        'assets/images/aquachileporfin3.png',
      );
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      print("Advertencia: Logo no encontrado");
    }

    // 2. CONSTRUCCIÓN DEL DOCUMENTO
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          buildBackground: (context) => pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
          ),
        ),
        header: (context) => _buildHeaderDense(data, logoImage),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildStatusAndStats(data),

          // --- AQUÍ AGREGAMOS LA TABLA TÉCNICA NUEVA ---
          pw.SizedBox(height: 15),
          _buildTechnicalDetails(data),

          // ---------------------------------------------
          pw.SizedBox(height: 15),
          _buildPersonnelTable(data),

          pw.SizedBox(height: 15),
          _buildSafetyChecklist(data),

          pw.SizedBox(height: 15),
          pw.Text(
            "DETALLE DE VERIFICACIONES",
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 5),
          _buildChecklistTable(data),

          if (data.fotosGenerales.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            _buildGeneralGallery(data.fotosGenerales),
            pw.SizedBox(height: 15),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // --- WIDGETS ---

  pw.Widget _buildHeaderDense(InspectionReportData data, pw.MemoryImage? logo) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
      ),
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "INFORME TÉCNICO",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 4),
                _rowInfo("CLIENTE:", data.cliente),
                _rowInfo("EMPRESA:", data.empresaContratista),
                _rowInfo("FECHA:", data.fecha),
              ],
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _rowInfo("CENTRO:", data.centro),
                _rowInfo("ÁREA:", data.area),
                _rowInfo("EMBARCACION:", data.embarcacion),
                _rowInfo("MATRÍCULA:", data.matricula),
              ],
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  height: 40,
                  alignment: pw.Alignment.centerRight,
                  child: logo != null
                      ? pw.Image(logo, fit: pw.BoxFit.contain)
                      : pw.Text(
                          "[LOGO]",
                          style: const pw.TextStyle(
                            color: PdfColors.grey,
                            fontSize: 8,
                          ),
                        ),
                ),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                  ),
                  child: pw.Text(
                    "N° INFORME: ${data.numeroReporte}",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- NUEVO WIDGET: DETALLES TÉCNICOS ---
  pw.Widget _buildTechnicalDetails(InspectionReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // CABECERA CON HORARIOS
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

          // TABLA DE COMPRESORES
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // Equipo
              1: const pw.FlexColumnWidth(2), // Matricula
              2: const pw.FlexColumnWidth(2), // Vigencia
              3: const pw.FlexColumnWidth(2), // Vigencia PH (NUEVO)
              4: const pw.FlexColumnWidth(1), // Buzos
            },
            children: [
              // HEADER TABLA
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
              // COMPRESOR 1
              pw.TableRow(
                children: [
                  _buildCell("Compresor 1"),
                  _buildCell(data.compresor1Matricula ?? "-"),
                  _buildCell(data.compresor1Vigencia ?? "-"),
                  _buildCell(data.compresor1PH ?? "-"),
                  _buildCell(data.compresor1Buzos ?? "0"),
                ],
              ),
              // COMPRESOR 2 (Solo si tiene matrícula para no ensuciar, o siempre si prefieres)
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
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.toUpperCase(),
              style: const pw.TextStyle(fontSize: 7),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
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
            height: 50,
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              color: bgEstado,
              border: pw.Border.all(color: colorEstado, width: 1),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  "ESTADO FINAL DE FAENA",
                  style: pw.TextStyle(fontSize: 8, color: colorEstado),
                ),
                pw.Text(
                  data.estadoGlobal.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
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
            0: const pw.FlexColumnWidth(2.5), // Nombre (un poco menos ancho)
            1: const pw.FlexColumnWidth(1.5), // RUT
            2: const pw.FlexColumnWidth(1.5), // Matrícula (NUEVA)
            3: const pw.FlexColumnWidth(2.0), // Cargo
            4: const pw.FlexColumnWidth(1.5), // Condición
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
                        padding: const pw.EdgeInsets.all(3),
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
        pw.SizedBox(height: 5),
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

  pw.Widget _buildGeneralGallery(List<Uint8List> fotos) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "EVIDENCIA FOTOGRÁFICA GENERAL",
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Wrap(
            spacing: 5,
            runSpacing: 5,
            children: fotos
                .map(
                  (f) => pw.Container(
                    width: 100,
                    height: 100,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                    ),
                    child: pw.Image(pw.MemoryImage(f), fit: pw.BoxFit.cover),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildChecklistTable(InspectionReportData data) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(0.6),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: ["Ítem / Pregunta", "Est.", "Observación", "Evidencia"]
              .map(
                (e) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    e,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        ...data.items.map((item) {
          final isNC = item.respuesta == "NC";
          final isIntolerable = item.criticidad == "Intolerable" && isNC;

          return pw.TableRow(
            decoration: isIntolerable
                ? const pw.BoxDecoration(color: PdfColors.red100)
                : (isNC
                      ? const pw.BoxDecoration(color: PdfColors.orange50)
                      : null),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.categoria.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 6,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      item.pregunta,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  item.respuesta,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    color: isNC ? PdfColors.red : PdfColors.black,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  item.comentario ?? "",
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(2),
                child: item.fotos.isNotEmpty
                    ? pw.Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        children: item.fotos
                            .map(
                              (f) => pw.Container(
                                width: 80,
                                height: 60,
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                    color: PdfColors.grey400,
                                    width: 0.5,
                                  ),
                                ),
                                child: pw.Image(
                                  pw.MemoryImage(f),
                                  fit: pw.BoxFit.cover,
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : pw.Container(),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        "Generado por JF Innova App - Pág. ${context.pageNumber}/${context.pagesCount}",
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
      ),
    );
  }

  pw.Widget _buildSafetyChecklist(InspectionReportData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
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
            // DETECTAMOS SI EL VALOR ES BOOL O NO PARA PINTARLO BIEN
            bool isBool = entry.value is bool;
            bool isCumple = isBool && (entry.value == true);
            String textoMostrar = isBool
                ? (isCumple ? "CUMPLE" : "NO CUMPLE")
                : entry.value.toString();

            // Solo mostramos colorines si es un booleano (los switches)
            // Si es texto (ej: algun dato extra que se haya colado), lo mostramos en negro
            PdfColor colorTexto = isBool
                ? (isCumple ? PdfColors.green700 : PdfColors.red700)
                : PdfColors.black;

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
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(entry.key, style: const pw.TextStyle(fontSize: 8)),
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
            );
          }).toList(),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "OBSERVACIÓN DEL PREVENCIONISTA:",
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  data.observacionPrevencionista,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Utilidad para construir celdas de tabla
  pw.Widget _buildCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
