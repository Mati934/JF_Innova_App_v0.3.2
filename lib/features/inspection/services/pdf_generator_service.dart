import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/models/pdf/inspection_report_data.dart';

class PdfGeneratorService {
  Future<Uint8List> generatePdf(InspectionReportData data) async {
    final pdf = pw.Document();

    // 1. CARGA DE RECURSOS OFFLINE (Fuentes y Logo)
    // Esto asegura que funcione en medio del mar sin internet.
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
        'assets/images/logo_jfinnova.png',
      );
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      // Si falla, no rompemos la app, solo no mostramos logo
      print(
        "Advertencia: Logo no encontrado en assets/images/logo_jfinnova.png",
      );
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
          pw.SizedBox(height: 15),
          _buildPersonnelTable(data),
          pw.SizedBox(height: 15),

          // --- ANTES ESTABAN AQUÍ LAS FOTOS, LAS QUITAMOS ---
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

          // --- NUEVA UBICACIÓN: AL FINAL DEL TODO ---
          if (data.fotosGenerales.isNotEmpty) ...[
            pw.SizedBox(height: 20), // Un poco de aire antes de las fotos
            pw.Divider(), // Opcional: una línea separadora se ve profesional
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
                          style: pw.TextStyle(
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
                    "FOLIO: ${data.numeroReporte}",
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
    // 1. Normalizamos el texto a mayúsculas para evitar errores (ej: "Suspendida" vs "SUSPENDIDA")
    final estadoUpper = data.estadoGlobal.toUpperCase();

    // 2. Definimos la condición estricta: Rojo solo si contiene "SUSPENDIDA"
    // (Si quieres incluir "RECHAZADA" como rojo, agrégalo aquí: || estadoUpper.contains("RECHAZADA"))
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
                  data.estadoGlobal
                      .toUpperCase(), // Aseguramos que se vea en mayúsculas
                  style: pw.TextStyle(
                    fontSize:
                        14, // Bajé un poco el tamaño por si el texto es largo
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
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ["Nombre Completo", "RUT", "Cargo", "Rol Faena"]
                  .map(
                    (e) => pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        e,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 7,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ...data.equipo.map(
              (p) => pw.TableRow(
                children: [p.nombre, p.rut, p.cargo, p.rolEnFaena]
                    .map(
                      (val) => pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          val,
                          style: const pw.TextStyle(fontSize: 7),
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
            pw.Text(
              "Nivel de Buceo: ",
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              "${data.nivelBuceo}   |   ",
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              "Prof. Máx: ",
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              "${data.profundidad} mts",
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
}
