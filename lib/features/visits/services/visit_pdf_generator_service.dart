import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import '../domain/models/pdf/visit_report_data.dart'; // Asegúrate de que esta ruta sea correcta

// 📦 1. PARÁMETROS ESTANDARIZADOS (Mirror de Inspecciones)
class VisitPdfIsolateParams {
  final VisitReportData data;
  final Uint8List fontRegular;
  final Uint8List fontBold;
  final Uint8List? logoBytes;

  VisitPdfIsolateParams({
    required this.data,
    required this.fontRegular,
    required this.fontBold,
    this.logoBytes,
  });
}

// 🧵 2. ENTRY POINT (Optimizado con compute)
Future<Uint8List> generateVisitPdfEntryPoint(
  VisitPdfIsolateParams params,
) async {
  final service = VisitPdfGeneratorService();
  return await service._generateSync(params);
}

class VisitPdfGeneratorService {
  Future<Uint8List> _generateSync(VisitPdfIsolateParams params) async {
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
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
        ),
        header: (context) => _buildHeader(logoImage, data),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildDatosGenerales(data),
          pw.SizedBox(height: 10),
          _buildTiemposYOrigen(data),
          pw.SizedBox(height: 10),
          _buildCorreos(data),
          pw.SizedBox(height: 15),
          _buildActividades(data),
          pw.SizedBox(height: 15),
          if (data.checklistItems.isNotEmpty) ...[
            ..._buildChecklistSection(data),
            pw.SizedBox(height: 15),
          ],
          _buildObservaciones(data),
          pw.SizedBox(height: 20),
          _buildFirma(data),

          // 🖼️ ANEXO FOTOGRÁFICO CON ALGORITMO DE CHUNKING (Clonado de Inspecciones)
          ..._buildGalleryChunked(data.fotosPaths),
        ],
      ),
    );

    return pdf.save();
  }

  // ALGORITMO DE CHUNKING: Evita desbordamientos de página y crasheos por RAM
  List<pw.Widget> _buildGalleryChunked(List<String> paths) {
    if (paths.isEmpty) return [];

    List<pw.Widget> widgets = [
      pw.SizedBox(height: 10),
      pw.Text(
        "ANEXO FOTOGRÁFICO",
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.Divider(),
      pw.SizedBox(height: 10),
    ];

    List<pw.Widget> fila = [];
    for (var path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          // Lectura protegida
          final bytes = file.readAsBytesSync();
          fila.add(
            pw.Container(
              width: 120,
              height: 120,
              margin: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
              ),
              child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
            ),
          );
        } catch (e) {
          print("❌ Error cargando imagen en PDF: $path - $e");
        }
      }

      if (fila.length == 3) {
        // 3 fotos por fila para que se vean bien
        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: fila,
          ),
        );
        fila = [];
      }
    }
    if (fila.isNotEmpty) {
      widgets.add(
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: fila),
      );
    }

    return widgets;
  }

  // --- WIDGETS DEL PDF ---

  pw.Widget _buildHeader(pw.MemoryImage? logo, VisitReportData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "JF Innova",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                "INFORME DE VISITA (R-003)",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logo != null) pw.Container(height: 40, child: pw.Image(logo)),
              pw.SizedBox(height: 5),
              pw.Text(
                "Fecha: ${data.fecha}",
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                "Versión: 0.1",
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDatosGenerales(VisitReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Encabezado fuera de la tabla para evitar problemas de columnas
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Text(
            "Datos generales",
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        // La tabla real
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
          },
          children: [
            _tableRow("Profesional", data.profesional),
            _tableRow("Fono del profesional", data.fonoProfesional),
            _tableRow("Correo del profesional", data.correoProfesional),
            _tableRow("Región", data.region),
            _tableRow("Oficina / Área", data.centro),
            _tableRow(
              "Jefatura a cargo",
              data.jefaturaCargo.isNotEmpty ? data.jefaturaCargo : "N/A",
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTiemposYOrigen(VisitReportData data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cellHeader("Hora inicio"),
            _cellHeader("Hora término"),
            _cellHeader("Origen de la visita"),
          ],
        ),
        pw.TableRow(
          children: [
            _cellData(data.horaInicio),
            _cellData(data.horaTermino),
            _cellData(data.origenVisita.isNotEmpty ? data.origenVisita : "N/A"),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCorreos(VisitReportData data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: [
        _tableRow(
          "Correo empresa 1 (donde enviar informe)",
          data.emailEmpresa1.isNotEmpty ? data.emailEmpresa1 : "N/A",
        ),
        _tableRow(
          "Correo empresa 2 (donde enviar informe)",
          data.emailEmpresa2.isNotEmpty ? data.emailEmpresa2 : "N/A",
        ),
      ],
    );
  }

  pw.Widget _buildActividades(VisitReportData data) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(5),
            color: PdfColors.grey200,
            child: pw.Text(
              "Actividades realizadas",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _checkItem("Reunión", data.checkReunion),
                      _checkItem("Visita SSO", data.checkVisitaSso),
                      _checkItem("Inspección SSO", data.checkInspeccionSso),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _checkItem(
                        "Instalación de señalética",
                        data.checkSenaletica,
                      ),
                      _checkItem("Charla (s)", data.checkCharla),
                      _checkItem(
                        "Observación conductual",
                        data.checkObsConductual,
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _checkItem("Capacitación", data.checkCapacitacion),
                      _checkItem(
                        "Investigación de Incidente",
                        data.checkInvestigacion,
                      ),
                      _checkItem(
                        "Otro: ${data.checkOtro && data.otroActividadTexto != null ? data.otroActividadTexto : ''}",
                        data.checkOtro,
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

  pw.Widget _buildObservaciones(VisitReportData data) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(5),
            color: PdfColors.grey200,
            child: pw.Text(
              "Apuntes / Observaciones",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              data.apuntesObservaciones.isNotEmpty
                  ? data.apuntesObservaciones
                  : "Sin observaciones registradas.",
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFirma(VisitReportData data) {
    return pw.Center(
      // Forzamos la alineación central respecto a la página
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min, // Solo ocupa el espacio necesario
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 10),

          // 1. Zona de la firma (Imagen o espacio vacío)
          if (data.signatureImage != null)
            pw.Image(
              pw.MemoryImage(data.signatureImage!),
              width: 150,
              height: 50,
              fit: pw.BoxFit.contain,
            )
          else
            pw.SizedBox(width: 150, height: 50), // Espacio reservado
          // 2. Línea separadora (Reemplaza al Stack ineficiente)
          pw.Container(
            width: 150,
            height: 1,
            color: PdfColors.black,
            margin: const pw.EdgeInsets.only(top: 5, bottom: 5),
          ),

          // 3. Etiqueta
          pw.Text(
            "Firma",
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        "Página ${context.pageNumber} de ${context.pagesCount}",
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }

  // --- HELPERS PARA TABLAS ---

  // pw.TableRow _tableHeaderRow(String title) {
  //   return pw.TableRow(
  //     decoration: const pw.BoxDecoration(color: PdfColors.grey200),
  //     children: [
  //       pw.Padding(
  //         padding: const pw.EdgeInsets.all(5),
  //         child: pw.Text(
  //           title,
  //           style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
  //         ),
  //       ),
  //       pw.Container(), // Celda vacía para expandir
  //     ],
  //   );
  // }

  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  pw.Widget _cellHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _cellData(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _checkItem(String label, bool isChecked) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 10,
            height: 10,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            alignment: pw.Alignment.center,
            child: isChecked
                ? pw.Text(
                    "X",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  )
                : null,
          ),
          pw.SizedBox(width: 5),
          pw.Expanded(
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  // OPTIMIZADOR DE IMÁGENES (Evita OutOfMemory en el Isolate)
  Uint8List _optimizarImagen(Uint8List rawBytes) {
    try {
      final img.Image? original = img.decodeImage(rawBytes);
      if (original == null) return rawBytes;
      final resized = img.copyResize(original, width: 800);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
    } catch (e) {
      return rawBytes;
    }
  }

  // === CHECKLIST DINÁMICO EN PDF ===
  List<pw.Widget> _buildChecklistSection(VisitReportData data) {
    // Agrupar items por categoría
    final Map<String, List<VisitChecklistItemDto>> grouped = {};
    for (var item in data.checklistItems) {
      grouped.putIfAbsent(item.categoria, () => []);
      grouped[item.categoria]!.add(item);
    }

    final List<pw.Widget> widgets = [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        child: pw.Text(
          'CHECKLIST: ${data.tipoChecklist ?? ""}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];

    int counter = 1;
    for (var category in grouped.keys) {
      // Header de categoría
      widgets.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          margin: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          child: pw.Text(
            category.toUpperCase(),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.blue900,
            ),
          ),
        ),
      );

      // Tabla de items
      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FixedColumnWidth(25),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(35),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _cellPdf('N', bold: true),
                _cellPdf('Item', bold: true),
                _cellPdf('Est.', bold: true),
                _cellPdf('Observación', bold: true),
              ],
            ),
            ...grouped[category]!.map((item) {
              final isNC = item.respuesta == 'NC';
              final row = pw.TableRow(
                decoration: isNC
                    ? const pw.BoxDecoration(color: PdfColors.red50)
                    : null,
                children: [
                  _cellPdf('$counter'),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                      item.pregunta,
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                  _cellPdf(item.respuesta, color: isNC ? PdfColors.red : null),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                      item.observacion ?? '',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                ],
              );
              counter++;
              return row;
            }),
          ],
        ),
      );
    }
    return widgets;
  }

  pw.Widget _cellPdf(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color,
        ),
      ),
    );
  }
}
