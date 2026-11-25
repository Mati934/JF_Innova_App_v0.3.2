import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/turno.dart';
import '../domain/turno_cierre.dart';

/// Versión del generador: todo cambio de contenido o diseño sube su patch.
const String kTurnoCierrePdfVersion = '0.1.0';

class TurnoCierrePdfData {
  final TurnoCierre cierre;
  final String profesional;
  final String area;

  const TurnoCierrePdfData({
    required this.cierre,
    required this.profesional,
    required this.area,
  });
}

class _Params {
  final TurnoCierrePdfData data;
  final Uint8List regular;
  final Uint8List bold;

  _Params(this.data, this.regular, this.bold);
}

Future<Uint8List> _entry(_Params p) => TurnoCierrePdfService._generar(p);

/// PDF del cierre de turno (reemplaza al formulario que se mandaba por
/// correo). Sin logo, con el pie "Generado por Servimaf" de los demás PDF.
class TurnoCierrePdfService {
  const TurnoCierrePdfService();

  static const _tinta = PdfColor.fromInt(0xFF1F2A30);
  static const _suave = PdfColor.fromInt(0xFF66737B);
  static const _linea = PdfColor.fromInt(0xFFDCE3E6);
  static const _cebra = PdfColor.fromInt(0xFFF5F8F8);
  static const _marca = PdfColor.fromInt(0xFF0B4F4A);
  static const _marcaMedia = PdfColor.fromInt(0xFF00796B);
  static const _marcaClara = PdfColor.fromInt(0xFFE3F1EE);
  static const _rojo = PdfColor.fromInt(0xFFC62828);
  static const _verde = PdfColor.fromInt(0xFF2E7D32);

  Future<Uint8List> generar(TurnoCierrePdfData data) async {
    final reg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    return compute(
      _entry,
      _Params(data, reg.buffer.asUint8List(), bold.buffer.asUint8List()),
    );
  }

  static Future<Uint8List> _generar(_Params p) async {
    final d = p.data;
    final c = d.cierre;
    final doc = pw.Document(
      title: 'Cierre de turno ${d.profesional}',
      author: 'Servimaf',
    );
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(p.regular.buffer.asByteData()),
      bold: pw.Font.ttf(p.bold.buffer.asByteData()),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 34),
        ),
        header: (_) => _cabecera(d),
        footer: _pie,
        build: (_) => [
          _datos(d),
          pw.SizedBox(height: 14),
          _titulo('Resumen del turno'),
          _indicadores(c),
          pw.SizedBox(height: 14),
          _titulo('Tickets del turno'),
          _tickets(c),
          for (final s in CierreCampos.secciones) ...[
            pw.SizedBox(height: 14),
            _titulo(s.titulo, cantidad: c.filasDe(s.clave).length),
            _tabla(s, c.filasDe(s.clave)),
          ],
          pw.SizedBox(height: 14),
          _titulo('Bitácora de cierre'),
          _bitacora(c.bitacora),
        ],
      ),
    );
    return doc.save();
  }

  static String _rango(DateTime a, DateTime b) {
    final mismoAnio = a.year == b.year;
    final ini =
        '${a.day} ${TurnoFechas.mes(a)}${mismoAnio ? '' : ' ${a.year}'}';
    return '$ini – ${b.day} ${TurnoFechas.mes(b)} ${b.year}';
  }

  static pw.Widget _cabecera(TurnoCierrePdfData d) {
    final c = d.cierre;
    final dias = TurnoReglas.diasReales(c.desde, c.hasta);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _marca, width: 1.4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Cierre de turno',
                  style: pw.TextStyle(
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                    color: _marca,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${d.profesional}  ·  ${d.area}',
                  style: const pw.TextStyle(fontSize: 9.5, color: _suave),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _marcaClara,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  _rango(c.desde, c.hasta),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _marca,
                  ),
                ),
                pw.Text(
                  '$dias ${dias == 1 ? 'día' : 'días'}',
                  style: const pw.TextStyle(fontSize: 8, color: _marcaMedia),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pie(pw.Context ctx) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.only(top: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey300, width: .5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generado por Servimaf  |  +56 9 8383 3177  |  v$kTurnoCierrePdfVersion',
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
        ),
        pw.Text(
          'Pág. ${ctx.pageNumber}/${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
        ),
      ],
    ),
  );

  static pw.Widget _datos(TurnoCierrePdfData d) {
    String larga(DateTime f) =>
        '${TurnoFechas.nombreDia(f)} ${f.day} ${TurnoFechas.mes(f)} ${f.year}';
    pw.Widget celda(String etiqueta, String valor, {bool borde = true}) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: borde
                ? const pw.BoxDecoration(
                    border: pw.Border(
                      right: pw.BorderSide(color: _linea, width: .7),
                    ),
                  )
                : null,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  etiqueta,
                  style: const pw.TextStyle(fontSize: 7, color: _suave),
                ),
                pw.SizedBox(height: 1.5),
                pw.Text(
                  valor.isEmpty ? '—' : valor,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _tinta,
                  ),
                ),
              ],
            ),
          ),
        );
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _linea, width: .7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          celda('Profesional', d.profesional),
          celda('Área / zona', d.area),
          celda('Desde', larga(d.cierre.desde)),
          celda('Hasta', larga(d.cierre.hasta), borde: false),
        ],
      ),
    );
  }

  static pw.Widget _titulo(String texto, {int? cantidad}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      children: [
        pw.Container(width: 3, height: 12, color: _marcaMedia),
        pw.SizedBox(width: 6),
        pw.Text(
          texto,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _tinta,
          ),
        ),
        if (cantidad != null && cantidad > 0) ...[
          pw.SizedBox(width: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: pw.BoxDecoration(
              color: _marcaClara,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              '$cantidad',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _marca,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  static pw.Widget _indicadores(TurnoCierre c) {
    pw.Widget tile(CampoNumero campo) {
      final v = c.numeros[campo.clave];
      final alerta = campo.clave == 'n_faenas_suspendidas' && (v ?? 0) > 0;
      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.all(2.5),
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: pw.BoxDecoration(
            color: alerta ? const PdfColor.fromInt(0xFFFDECEC) : _cebra,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                v?.toString() ?? '—',
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  color: alerta ? _rojo : _marca,
                ),
              ),
              pw.Text(
                campo.titulo,
                style: const pw.TextStyle(fontSize: 7.5, color: _suave),
              ),
            ],
          ),
        ),
      );
    }

    final campos = CierreCampos.indicadores;
    return pw.Column(
      children: [
        pw.Row(children: [for (final f in campos.take(4)) tile(f)]),
        pw.Row(children: [for (final f in campos.skip(4)) tile(f)]),
      ],
    );
  }

  /// Barra apilada: cada tramo con su color y ancho proporcional.
  static pw.Widget _barra(List<(int, PdfColor)> tramos, {double alto = 9}) {
    final total = tramos.fold(0, (s, t) => s + t.$1);
    if (total == 0) {
      return pw.Container(
        height: alto,
        decoration: pw.BoxDecoration(
          color: _linea,
          borderRadius: pw.BorderRadius.circular(alto / 2),
        ),
      );
    }
    return pw.ClipRRect(
      horizontalRadius: alto / 2,
      verticalRadius: alto / 2,
      child: pw.Row(
        children: [
          for (final t in tramos)
            if (t.$1 > 0)
              pw.Expanded(
                flex: t.$1,
                child: pw.Container(height: alto, color: t.$2),
              ),
        ],
      ),
    );
  }

  static pw.Widget _leyenda(String texto, int n, PdfColor color, {int? de}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Row(
          children: [
            pw.Container(
              width: 7,
              height: 7,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(width: 5),
            pw.Expanded(
              child: pw.Text(
                texto,
                style: const pw.TextStyle(fontSize: 8, color: _tinta),
              ),
            ),
            pw.Text(
              de == null || de == 0
                  ? '$n'
                  : '$n  ·  ${(n * 100 / de).round()} %',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _tinta,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _tickets(TurnoCierre c) {
    int n(String k) => c.numeros[k] ?? 0;
    const soloCreo = PdfColor.fromInt(0xFF8DBBE6);
    const ambos = PdfColor.fromInt(0xFF2F7FBF);
    const soloCerro = _verde;
    final estados = [
      ('Abiertos', n('tk_abiertos'), const PdfColor.fromInt(0xFFE06666)),
      ('Tomados', n('tk_tomados'), const PdfColor.fromInt(0xFFF0A040)),
      ('Parciales', n('tk_parciales'), const PdfColor.fromInt(0xFFF3D060)),
      ('Por revisar', n('tk_por_revisar'), const PdfColor.fromInt(0xFF6FA8DC)),
      ('Cerrados', n('tk_estado_cerrados'), _verde),
    ];
    final total = n('tk_solo_creo') + n('tk_creo_y_cerro') + n('tk_solo_cerro');
    final logrado = total == 0
        ? null
        : ((n('tk_por_revisar') + n('tk_estado_cerrados')) * 100 / total)
              .round();

    pw.Widget caja(pw.Widget hijo) => pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _linea, width: .7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: hijo,
    );

    if (total == 0 && n('tk_a_cargo') == 0) {
      return _vacio('Sin tickets creados ni cerrados en el turno.');
    }
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: caja(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '$total',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _marca,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        'tickets creados o cerrados',
                        style: const pw.TextStyle(fontSize: 8.5, color: _suave),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                _barra([
                  (n('tk_solo_creo'), soloCreo),
                  (n('tk_creo_y_cerro'), ambos),
                  (n('tk_solo_cerro'), soloCerro),
                ]),
                pw.SizedBox(height: 3),
                _leyenda('Solo creó', n('tk_solo_creo'), soloCreo),
                _leyenda('Creó y cerró', n('tk_creo_y_cerro'), ambos),
                _leyenda('Solo cerró', n('tk_solo_cerro'), soloCerro),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          flex: 6,
          child: caja(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Estado actual de esos tickets',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _tinta,
                        ),
                      ),
                    ),
                    if (logrado != null)
                      pw.Text(
                        'Logrado $logrado %',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _verde,
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 8),
                _barra([for (final e in estados) (e.$2, e.$3)]),
                pw.SizedBox(height: 3),
                for (final e in estados) _leyenda(e.$1, e.$2, e.$3, de: total),
                pw.SizedBox(height: 6),
                pw.Text(
                  'A su cargo hoy: ${n('tk_a_cargo')}',
                  style: const pw.TextStyle(fontSize: 8, color: _suave),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _vacio(String texto) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: pw.BoxDecoration(
      color: _cebra,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(texto, style: pw.TextStyle(fontSize: 8.5, color: _suave)),
  );

  static pw.Widget _tabla(SeccionCierre s, List<FilaCierre> filas) {
    if (filas.isEmpty) return _vacio('Sin registros en el turno.');
    pw.Widget celda(ColumnaCierre col, String v, {bool cabecera = false}) {
      final alinear = col.numero
          ? pw.Alignment.center
          : pw.Alignment.centerLeft;
      if (cabecera) {
        return pw.Container(
          alignment: alinear,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: pw.Text(
            col.titulo,
            textAlign: col.numero ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        );
      }
      // Criticidad como etiqueta y pendientes > 0 en rojo.
      if (col.clave == 'criticidad' && v.isNotEmpty) {
        return pw.Container(
          alignment: alinear,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 1.5,
            ),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFFDECEC),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _rojo,
              ),
            ),
          ),
        );
      }
      final pendiente =
          (col.clave == 'pendientes' || col.clave == 'obs_pen') &&
          (int.tryParse(v) ?? 0) > 0;
      final cerrada =
          (col.clave == 'cerradas' || col.clave == 'obs_cerr') &&
          (int.tryParse(v) ?? 0) > 0;
      return pw.Container(
        alignment: alinear,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(
          v.isEmpty ? (col.numero ? '' : '—') : v,
          textAlign: col.numero ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 8,
            color: pendiente
                ? _rojo
                : cerrada
                ? _verde
                : (v.isEmpty ? _suave : _tinta),
            fontWeight: col.numero || col == s.columnas.first
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < s.columnas.length; i++)
          i: pw.FlexColumnWidth(s.columnas[i].flex.toDouble()),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _linea, width: .5),
        bottom: pw.BorderSide(color: _linea, width: .5),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _marca),
          children: [
            for (final col in s.columnas) celda(col, '', cabecera: true),
          ],
        ),
        for (var i = 0; i < filas.length; i++)
          pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: _cebra) : null,
            children: [
              for (final col in s.columnas)
                celda(col, filas[i][col.clave] ?? ''),
            ],
          ),
      ],
    );
  }

  static pw.Widget _bitacora(String? texto) {
    final t = texto?.trim() ?? '';
    if (t.isEmpty) return _vacio('Sin observaciones para el próximo turno.');
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: const pw.BoxDecoration(
        color: _cebra,
        border: pw.Border(left: pw.BorderSide(color: _marcaMedia, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Observaciones relevantes y coordinaciones para el próximo turno',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _marca,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: _tinta)),
        ],
      ),
    );
  }
}
