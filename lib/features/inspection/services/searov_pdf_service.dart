import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/formato_inspeccion.dart';
import '../domain/models/pdf/inspection_report_data.dart';
import 'pdf_generator_service.dart';

/// Informe de inspección con formato Searov (buceo y embarcación).
/// Mismo flujo y datos que el informe estándar; cambia el diseño: tablas
/// tipo planilla como los formatos de origen del cliente.
class SearovPdfService {
  static const String pdfVersion = '0.3.0';

  static final _navy = PdfColor.fromHex('#1F3A5F');
  static final _band = PdfColor.fromHex('#E8EDF3');
  static final _rule = PdfColor.fromHex('#9AA8B8');
  static final _ink = PdfColor.fromHex('#1B2430');
  static final _red = PdfColor.fromHex('#C62828');
  static final _redLight = PdfColor.fromHex('#FDECEC');
  static final _amber = PdfColor.fromHex('#B26A00');
  static final _amberLight = PdfColor.fromHex('#FFF4E0');
  static final _green = PdfColor.fromHex('#2E7D32');
  static final _greenLight = PdfColor.fromHex('#E8F5E9');

  Future<Uint8List> generar(PdfIsolateParams params) async {
    final data = params.data;
    final esBuceo = data.tipoFaena.contains('BUCEO');
    final logo = params.logoBytes != null
        ? pw.MemoryImage(params.logoBytes!)
        : null;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        maxPages: 200,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 24),
          theme: pw.ThemeData.withFont(
            base: pw.Font.ttf(params.fontRegular.buffer.asByteData()),
            bold: pw.Font.ttf(params.fontBold.buffer.asByteData()),
            italic: pw.Font.ttf(params.fontItalic.buffer.asByteData()),
          ),
        ),
        header: (context) => _encabezado(data, logo, esBuceo),
        footer: (context) => _pie(context, data),
        build: (context) =>
            esBuceo ? _cuerpoBuceo(data) : _cuerpoEmbarcacion(data),
      ),
    );
    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // Comunes
  // ---------------------------------------------------------------------------

  pw.Widget _encabezado(
    InspectionReportData data,
    pw.MemoryImage? logo,
    bool esBuceo,
  ) {
    final titulo = esBuceo
        ? 'LISTA DE CHEQUEO PARA FAENAS DE BUCEO'
        : 'INSPECCIÓN DE EMBARCACIÓN';
    final subtitulo = esBuceo
        ? 'Faenas hasta 20 y 36 metros'
        : 'Barcos / barcazas';

    pw.Widget marca = logo != null
        ? pw.Image(logo, height: 34, fit: pw.BoxFit.contain)
        : pw.Text(
            data.empresaProveedor,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          );

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Table(
        border: pw.TableBorder.all(color: _ink, width: 0.8),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.1),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(1.1),
        },
        children: [
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.Container(
                height: 50,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(6),
                child: marca,
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  children: [
                    pw.Text(
                      titulo,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      subtitulo,
                      style: pw.TextStyle(fontSize: 8.5, color: _ink),
                    ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kv('Informe N°', data.numeroReporte),
                    _kv('Fecha', data.fecha),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _kv(String k, String v) => pw.RichText(
    text: pw.TextSpan(
      style: pw.TextStyle(fontSize: 8, color: _ink),
      children: [
        pw.TextSpan(
          text: '$k: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(text: v),
      ],
    ),
  );

  pw.Widget _pie(pw.Context context, InspectionReportData data) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'Generado por Servimaf  |  Formato v$pdfVersion  |  App ${data.appVersion}',
        style: pw.TextStyle(fontSize: 7, color: _rule),
      ),
      pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 7, color: _rule),
      ),
    ],
  );

  pw.Widget _tituloSeccion(String texto) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    color: _navy,
    child: pw.Text(
      texto.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );

  pw.Widget _celda(
    String texto, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    PdfColor? fondo,
    double size = 7.5,
  }) => pw.Container(
    color: fondo,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: pw.Text(
      texto,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? _ink,
      ),
    ),
  );

  /// Tabla de datos en pares etiqueta / valor, dos pares por fila.
  pw.Widget _tablaDatos(List<(String, String)> pares) {
    final filas = <pw.TableRow>[];
    for (var i = 0; i < pares.length; i += 2) {
      final a = pares[i];
      final b = i + 1 < pares.length ? pares[i + 1] : ('', '');
      filas.add(
        pw.TableRow(
          children: [
            _celda(a.$1, bold: true, fondo: _band),
            _celda(a.$2),
            _celda(b.$1, bold: true, fondo: _band),
            _celda(b.$2),
          ],
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: _rule, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(2),
      },
      children: filas,
    );
  }

  pw.Widget _tablaPersonal(List<PersonalDto> equipo, {bool numerar = false}) {
    return pw.Table(
      border: pw.TableBorder.all(color: _rule, width: 0.5),
      columnWidths: {
        if (numerar) 0: const pw.FixedColumnWidth(26),
        (numerar ? 1 : 0): const pw.FlexColumnWidth(3),
        (numerar ? 2 : 1): const pw.FlexColumnWidth(1.5),
        (numerar ? 3 : 2): const pw.FlexColumnWidth(1.5),
        (numerar ? 4 : 3): const pw.FlexColumnWidth(1.3),
      },
      children: [
        pw.TableRow(
          children: [
            if (numerar) _celda('N°', bold: true, fondo: _band),
            _celda('Nombre', bold: true, fondo: _band),
            _celda('RUT', bold: true, fondo: _band),
            _celda('Cargo', bold: true, fondo: _band),
            _celda('Matrícula', bold: true, fondo: _band),
          ],
        ),
        for (var i = 0; i < equipo.length; i++)
          pw.TableRow(
            children: [
              if (numerar) _celda('B${i + 1}', align: pw.TextAlign.center),
              _celda(equipo[i].nombre),
              _celda(equipo[i].rut),
              _celda(equipo[i].cargo),
              _celda(equipo[i].matricula),
            ],
          ),
      ],
    );
  }

  /// Agrupa los items (sin los "por buzo") por categoría, en su orden.
  Map<String, List<InspectionItemDto>> _porCategoria(
    InspectionReportData data,
  ) {
    final grupos = <String, List<InspectionItemDto>>{};
    for (final item in data.items) {
      if (item.aplicaPorBuzo) continue;
      grupos.putIfAbsent(item.categoria, () => []).add(item);
    }
    return grupos;
  }

  pw.Widget _observaciones(InspectionReportData data) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _rule, width: 0.5),
    ),
    child: pw.Text(
      data.observacionPrevencionista.trim().isEmpty
          ? 'Sin observaciones.'
          : data.observacionPrevencionista,
      style: pw.TextStyle(fontSize: 8, color: _ink),
    ),
  );

  /// Quien realiza la inspección: el nombre escrito en el formulario
  /// (usuario general por empresa); si falta, el usuario de la app.
  String _inspector(InspectionReportData data) =>
      data.inspectorNombre ?? data.profesional ?? '-';

  /// Una imagen por ruta: una foto o firma repetida se incrusta una sola vez.
  final _imagenes = <String, pw.MemoryImage?>{};

  pw.MemoryImage? _imagenLocal(String? path) {
    if (path == null || path.isEmpty) return null;
    return _imagenes.putIfAbsent(path, () {
      final file = File(path);
      if (!file.existsSync()) return null;
      try {
        return pw.MemoryImage(file.readAsBytesSync());
      } catch (_) {
        return null;
      }
    });
  }

  /// Firmas una al lado de la otra: la firma sobre una línea y, debajo,
  /// el nombre de quien firma y su rol.
  pw.Widget _firmas(
    String izquierda,
    String derecha,
    InspectionReportData data,
  ) {
    pw.Widget bloque(String rol, String? nombre, String? firmaPath) {
      final firma = _imagenLocal(firmaPath);
      return pw.Expanded(
        child: pw.Column(
          children: [
            pw.Container(
              height: 58,
              alignment: pw.Alignment.bottomCenter,
              child: firma != null
                  ? pw.Image(firma, fit: pw.BoxFit.contain)
                  : pw.SizedBox(),
            ),
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 18),
              height: 0.8,
              color: _ink,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              (nombre ?? '').trim().isEmpty ? ' ' : nombre!,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              rol,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 6.8, color: _rule),
            ),
          ],
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 24),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          bloque(izquierda, _inspector(data), data.firmaInspectorPath),
          pw.SizedBox(width: 30),
          bloque(derecha, data.recibeNombre, data.firmaRecibePath),
        ],
      ),
    );
  }

  /// Compresores de la faena (los que tienen algún dato).
  List<pw.Widget> _tablaCompresores(InspectionReportData data) {
    bool lleno(List<String?> v) => v.any((x) => (x ?? '').trim().isNotEmpty);
    final filas = [
      if (lleno([
        data.compresor1Matricula,
        data.compresor1Vigencia,
        data.compresor1PH,
        data.compresor1Buzos,
      ]))
        (
          'Compresor 1',
          data.compresor1Matricula,
          data.compresor1Vigencia,
          data.compresor1PH,
          data.compresor1Buzos,
        ),
      if (lleno([
        data.compresor2Matricula,
        data.compresor2Vigencia,
        data.compresor2PH,
        data.compresor2Buzos,
      ]))
        (
          'Compresor 2',
          data.compresor2Matricula,
          data.compresor2Vigencia,
          data.compresor2PH,
          data.compresor2Buzos,
        ),
    ];
    if (filas.isEmpty) return [];
    String v(String? x) => (x ?? '').trim().isEmpty ? '-' : x!;
    pw.Widget h(String t) =>
        _celda(t, bold: true, fondo: _band, align: pw.TextAlign.center);
    return [
      _tituloSeccion('Compresores'),
      pw.Table(
        border: pw.TableBorder.all(color: _rule, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.3),
          1: pw.FlexColumnWidth(1.5),
          2: pw.FlexColumnWidth(1.2),
          3: pw.FlexColumnWidth(1.2),
          4: pw.FlexColumnWidth(1.1),
        },
        children: [
          pw.TableRow(
            children: [
              h('Compresor'),
              h('Matrícula'),
              h('Vigencia'),
              h('Vigencia P.H.'),
              h('N° buzos a cargo'),
            ],
          ),
          for (final f in filas)
            pw.TableRow(
              children: [
                _celda(f.$1, bold: true),
                _celda(v(f.$2), align: pw.TextAlign.center),
                _celda(v(f.$3), align: pw.TextAlign.center),
                _celda(v(f.$4), align: pw.TextAlign.center),
                _celda(v(f.$5), align: pw.TextAlign.center),
              ],
            ),
        ],
      ),
    ];
  }

  List<pw.Widget> _anexoFotos(InspectionReportData data) {
    // Las fotos de cada pregunta van en el checklist, no aquí.
    final fotos = <(String, String)>[
      for (final f in data.fotosExtraObservaciones)
        (f['path'] ?? '', f['observacion'] ?? ''),
      for (final path in data.fotosGeneralesPaths) (path, 'Registro general'),
    ].where((f) => File(f.$1).existsSync()).toList();
    if (fotos.isEmpty) return [];

    pw.Widget foto((String, String) f) {
      final img = _imagenLocal(f.$1);
      if (img == null) return pw.SizedBox();
      return pw.Column(
        children: [
          pw.Container(
            height: 150,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _rule, width: 0.5),
            ),
            child: pw.Image(img, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            f.$2,
            maxLines: 2,
            style: pw.TextStyle(fontSize: 7, color: _ink),
          ),
        ],
      );
    }

    pw.Widget fila(int i) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: foto(fotos[i])),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: i + 1 < fotos.length ? foto(fotos[i + 1]) : pw.SizedBox(),
          ),
        ],
      ),
    );

    // El título va unido a la primera fila de fotos para no quedar solo.
    return [
      // Inseparable: el título no queda solo al pie de una página.
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Registro fotográfico'),
            pw.SizedBox(height: 6),
            fila(0),
          ],
        ),
      ),
      for (var i = 2; i < fotos.length; i += 2) fila(i),
    ];
  }

  /// Celda de estado única (Cumple / No cumple / N/A), como el checklist
  /// estándar, en lugar de una columna por opción marcada con X.
  pw.Widget _celdaEstado(String? respuesta, {bool corto = false}) {
    final (texto, color, fondo) = switch (respuesta) {
      'C' => (corto ? 'C' : 'Cumple', _green, _greenLight),
      'NC' => (corto ? 'NC' : 'No cumple', _red, _redLight),
      'N/A' => ('N/A', _ink, null),
      _ => ('', _ink, null),
    };
    return _celda(
      texto,
      align: pw.TextAlign.center,
      bold: true,
      color: color,
      fondo: fondo,
    );
  }

  // ---------------------------------------------------------------------------
  // Buceo
  // ---------------------------------------------------------------------------

  List<pw.Widget> _cuerpoBuceo(InspectionReportData data) {
    final secciones = <pw.Widget>[];
    var numero = 0;
    for (final entry in _porCategoria(data).entries) {
      secciones.addAll(_checklistCategoria(entry.key, entry.value, numero));
      numero += entry.value.length;
    }

    return [
      _tablaDatos([
        ('Centro', data.centro),
        ('Área', data.area),
        ('Empresa contratista', data.empresaContratista),
        ('Hora inicio', data.horaInicio ?? '--:--'),
        ('Hora término', data.horaTermino ?? '--:--'),
        ('Supervisor', data.supervisor),
        ('Inspector', _inspector(data)),
        (
          'Encargado de centro',
          (data.encargadoCentro ?? '').trim().isEmpty
              ? '-'
              : data.encargadoCentro!,
        ),
      ]),
      ..._tablaCompresores(data),
      _tituloSeccion('Cuadrilla'),
      if (data.equipo.isEmpty)
        _celda('Sin personal registrado.')
      else
        _tablaPersonal(data.equipo, numerar: true),
      if (data.preguntasPorBuzo.isNotEmpty && data.equipo.isNotEmpty) ...[
        _tituloSeccion('Personal (por buzo)'),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Text(
            'C = presente y en buen estado  ·  NC = falta o no está en buen estado',
            style: pw.TextStyle(fontSize: 7, color: _ink),
          ),
        ),
        _matrizPorBuzo(data),
      ],
      ...secciones,
      _tituloSeccion('Observaciones'),
      _observaciones(data),
      _firmas(
        'NOMBRE / CARGO DE QUIEN REALIZA LA INSPECCIÓN',
        'JEFE DE CENTRO, SUPERVISOR DE BUCEO O REP. EMPRESA CONTRATISTA',
        data,
      ),
      ..._anexoFotos(data),
    ];
  }

  pw.Widget _matrizPorBuzo(InspectionReportData data) {
    final buzos = data.equipo;
    return pw.Table(
      border: pw.TableBorder.all(color: _rule, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        for (var i = 0; i < buzos.length; i++)
          i + 1: const pw.FlexColumnWidth(0.7),
      },
      children: [
        pw.TableRow(
          children: [
            _celda('Elemento', bold: true, fondo: _band),
            for (var i = 0; i < buzos.length; i++)
              _celda(
                'B${i + 1}',
                bold: true,
                fondo: _band,
                align: pw.TextAlign.center,
              ),
          ],
        ),
        for (final pregunta in data.preguntasPorBuzo.entries)
          pw.TableRow(
            children: [
              _celda(pregunta.value),
              for (final b in buzos)
                _celdaEstado(b.respuestasPorItem[pregunta.key], corto: true),
            ],
          ),
      ],
    );
  }

  /// Checklist de una categoría con la misma estructura del informe
  /// estándar de buceo (N°, pregunta con su observación debajo, fotos a la
  /// derecha y estado), pero con bordes y colores de planilla Searov.
  /// El título va unido a la primera fila para que no quede huérfano.
  List<pw.Widget> _checklistCategoria(
    String categoria,
    List<InspectionItemDto> items,
    int desde, {
    bool conPotencialidad = false,
  }) {
    if (items.isEmpty) return [];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(26),
      1: const pw.FlexColumnWidth(),
      if (conPotencialidad) 2: const pw.FixedColumnWidth(66),
      (conPotencialidad ? 3 : 2): const pw.FixedColumnWidth(124),
      (conPotencialidad ? 4 : 3): const pw.FixedColumnWidth(72),
    };
    final borde = pw.TableBorder.all(color: _rule, width: 0.5);
    final encabezado = pw.TableRow(
      children: [
        _celda('N°', bold: true, fondo: _band, align: pw.TextAlign.center),
        _celda('Ítem', bold: true, fondo: _band),
        if (conPotencialidad)
          _celda(
            'Potencialidad',
            bold: true,
            fondo: _band,
            align: pw.TextAlign.center,
          ),
        _celda('Fotos', bold: true, fondo: _band, align: pw.TextAlign.center),
        _celda('Estado', bold: true, fondo: _band, align: pw.TextAlign.center),
      ],
    );
    final filas = [
      for (var i = 0; i < items.length; i++)
        _filaChecklist(items[i], desde + i + 1, conPotencialidad),
    ];

    String n(int v) => v.toString().padLeft(2, '0');
    final titulo = pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: _navy,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              categoria.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Text(
            'Ítems ${n(desde + 1)}-${n(desde + items.length)}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.white),
          ),
        ],
      ),
    );

    return [
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            titulo,
            pw.Table(
              border: borde,
              columnWidths: widths,
              children: [encabezado, filas.first],
            ),
          ],
        ),
      ),
      if (filas.length > 1)
        pw.Table(
          border: borde,
          columnWidths: widths,
          children: filas.skip(1).toList(),
        ),
    ];
  }

  pw.TableRow _filaChecklist(
    InspectionItemDto item,
    int numero,
    bool conPotencialidad,
  ) {
    final esNC = item.respuesta == 'NC';
    final comentario = (item.comentario ?? '').trim();
    final fotos = item.fotosPaths
        .map(_imagenLocal)
        .whereType<pw.MemoryImage>()
        .toList();

    return pw.TableRow(
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      decoration: pw.BoxDecoration(
        color: esNC ? PdfColor.fromHex('#FFF8F8') : PdfColors.white,
      ),
      children: [
        _celda(
          numero.toString().padLeft(2, '0'),
          align: pw.TextAlign.center,
          color: _rule,
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                item.pregunta,
                style: pw.TextStyle(
                  fontSize: 7.8,
                  color: esNC ? _red : _ink,
                  fontWeight: esNC ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
              if (comentario.isNotEmpty)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(top: 3),
                  padding: const pw.EdgeInsets.fromLTRB(5, 3, 4, 3),
                  decoration: pw.BoxDecoration(
                    color: esNC ? _redLight : _band,
                    border: pw.Border(
                      left: pw.BorderSide(color: esNC ? _red : _navy, width: 2),
                    ),
                  ),
                  child: pw.Text(
                    'Obs.: $comentario',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontStyle: pw.FontStyle.italic,
                      color: esNC ? _red : _ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (conPotencialidad)
          _celda(
            item.potencialidad ?? '-',
            align: pw.TextAlign.center,
            bold: true,
            color: item.potencialidad == 'ALTA' ? _red : _amber,
          ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: fotos.isEmpty
              ? pw.Center(
                  child: pw.Text(
                    '-',
                    style: pw.TextStyle(fontSize: 8, color: _rule),
                  ),
                )
              : pw.Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: pw.WrapAlignment.center,
                  children: [
                    // Una foto ocupa la celda; dos o más, de a dos por fila.
                    for (final img in fotos)
                      pw.Container(
                        width: fotos.length == 1 ? 116 : 56,
                        height: fotos.length == 1 ? 84 : 46,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _rule, width: 0.6),
                        ),
                        child: pw.Image(img, fit: pw.BoxFit.cover),
                      ),
                  ],
                ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: _etiquetaEstado(item.respuesta),
        ),
      ],
    );
  }

  /// Estado como píldora redondeada con un punto de color (Cumple /
  /// No cumple / N/A), sin recuadro.
  pw.Widget _etiquetaEstado(String? respuesta) {
    final (texto, color, fondo) = switch (respuesta) {
      'C' => ('Cumple', _green, _greenLight),
      'NC' => ('No cumple', _red, _redLight),
      _ => ('N/A', PdfColor.fromHex('#5F6B7A'), PdfColor.fromHex('#EEF1F4')),
    };
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: pw.BoxDecoration(
          color: fondo,
          borderRadius: pw.BorderRadius.circular(9),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: 5,
              height: 5,
              decoration: pw.BoxDecoration(
                color: color,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text(
              texto,
              style: pw.TextStyle(
                fontSize: 7.2,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Embarcación
  // ---------------------------------------------------------------------------

  List<pw.Widget> _cuerpoEmbarcacion(InspectionReportData data) {
    final resultado = FormatoInspeccion.resultadoPorPotencialidad(
      data.items.map(
        (i) => (potencialidad: i.potencialidad, respuesta: i.respuesta),
      ),
    );
    final (color, fondo) = switch (resultado.resultado) {
      ResultadoEmbarcacion.autorizada => (_green, _greenLight),
      ResultadoEmbarcacion.condicional => (_amber, _amberLight),
      ResultadoEmbarcacion.rechazada => (_red, _redLight),
    };
    final noCumple = data.items.where((i) => i.respuesta == 'NC').toList();

    final secciones = <pw.Widget>[];
    var numero = 0;
    for (final entry in _porCategoria(data).entries) {
      secciones.addAll(
        _checklistCategoria(
          entry.key,
          entry.value,
          numero,
          conPotencialidad: true,
        ),
      );
      numero += entry.value.length;
    }

    return [
      _tituloSeccion('Información general de la inspección'),
      _tablaDatos([
        ('Área / centro', '${data.area} / ${data.centro}'),
        ('Fecha inspección', data.fecha),
        ('Nombre servicio', data.empresaContratista),
        ('Persona que recibe', data.recibeNombre ?? ''),
        ('Nombre barco o barcaza', data.embarcacion),
        ('Matrícula', data.matricula),
        (
          'N° de trabajadores',
          data.equipo.isEmpty ? '-' : '${data.equipo.length}',
        ),
        ('N° de zarpe', data.numeroZarpe ?? 'S/N'),
        (
          'Hora inicio / término',
          '${data.horaInicio ?? '--:--'} / ${data.horaTermino ?? '--:--'}',
        ),
        ('Inspector', _inspector(data)),
      ]),
      _tituloSeccion('Criterio para aprobar una embarcación'),
      pw.Table(
        border: pw.TableBorder.all(color: _rule, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.3),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(1.6),
          3: pw.FlexColumnWidth(4),
        },
        children: [
          pw.TableRow(
            children: [
              _celda('Potencialidad', bold: true, fondo: _band),
              _celda('Plazo de corrección', bold: true, fondo: _band),
              _celda('Estado', bold: true, fondo: _band),
              _celda('Comentario', bold: true, fondo: _band),
            ],
          ),
          pw.TableRow(
            children: [
              _celda('ALTA', bold: true, color: _red),
              _celda('Inmediata'),
              _celda('Rechazada'),
              _celda(
                'Un (1) incumplimiento inhabilita a la embarcación para efectuar faenas.',
              ),
            ],
          ),
          pw.TableRow(
            children: [
              _celda('MEDIA', bold: true, color: _amber),
              _celda('Se autoriza por 7 días con hasta 5 incumplimientos'),
              _celda('Autorizada condicional'),
              _celda(
                'Con hasta cinco (5) incumplimientos se autoriza condicional; desde el sexto (6) se rechaza.',
              ),
            ],
          ),
          pw.TableRow(
            children: [
              _celda('Sin observaciones', bold: true, color: _green),
              _celda('-'),
              _celda('Faena autorizada'),
              _celda('Cumple con los requisitos.'),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        color: fondo,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Resultado: ${resultado.resultado.etiqueta}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.Text(
              'Incumplimientos ALTA: ${resultado.incumplimientosAlta}  ·  MEDIA: ${resultado.incumplimientosMedia}',
              style: pw.TextStyle(fontSize: 8, color: _ink),
            ),
          ],
        ),
      ),
      ...secciones,
      if (data.equipo.isNotEmpty) ...[
        _tituloSeccion('Dotación'),
        _tablaPersonal(data.equipo),
      ],
      _tituloSeccion('Resumen de acciones correctivas'),
      pw.Table(
        border: pw.TableBorder.all(color: _rule, width: 0.5),
        columnWidths: const {
          0: pw.FixedColumnWidth(22),
          1: pw.FlexColumnWidth(5),
          2: pw.FlexColumnWidth(1.6),
          3: pw.FlexColumnWidth(1.4),
          4: pw.FlexColumnWidth(1.4),
          5: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            children: [
              _celda(
                'N°',
                bold: true,
                fondo: _band,
                align: pw.TextAlign.center,
              ),
              _celda('Hallazgo', bold: true, fondo: _band),
              _celda('Responsable', bold: true, fondo: _band),
              _celda('Fecha cumplimiento', bold: true, fondo: _band),
              _celda('Fecha control', bold: true, fondo: _band),
              _celda('¿Cumple?', bold: true, fondo: _band),
            ],
          ),
          if (noCumple.isEmpty)
            pw.TableRow(
              children: [
                _celda('-', align: pw.TextAlign.center),
                _celda('Sin hallazgos.'),
                _celda(''),
                _celda(''),
                _celda(''),
                _celda(''),
              ],
            ),
          for (var i = 0; i < noCumple.length; i++)
            pw.TableRow(
              children: [
                _celda('${i + 1}', align: pw.TextAlign.center),
                _celda(
                  [
                    noCumple[i].pregunta,
                    if ((noCumple[i].comentario ?? '').trim().isNotEmpty)
                      noCumple[i].comentario!.trim(),
                  ].join(' — '),
                ),
                _celda(''),
                _celda(''),
                _celda(''),
                _celda(''),
              ],
            ),
        ],
      ),
      _tituloSeccion('Observaciones'),
      _observaciones(data),
      _firmas(
        'NOMBRE DE QUIEN REALIZA LA INSPECCIÓN',
        'NOMBRE DE QUIEN RECIBE LA INSPECCIÓN',
        data,
      ),
      ..._anexoFotos(data),
    ];
  }
}
