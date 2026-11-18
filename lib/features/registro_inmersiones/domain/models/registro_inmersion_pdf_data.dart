import 'package:intl/intl.dart';

import '../../../../core/utils/rut_utils.dart';
import 'registro_inmersion_models.dart';

/// Datos planos y serializables para generar el PDF en un isolate.
class RegistroInmersionPdfData {
  final String correlativo; // 'RI-0057' o 'Pendiente'
  /// N° de la inspección de buceo vinculada; null si el registro no tiene.
  final String? numeroInspeccion;
  final String fecha;
  final String centro;
  final String contratista;
  final String profundidadAutorizada; // '20 m' o ''
  final String auditor;
  final List<RegistroInmersionPdfBuzo> buzos;
  final String observacionGeneral;
  final List<String> galeriaPaths;

  const RegistroInmersionPdfData({
    required this.correlativo,
    this.numeroInspeccion,
    required this.fecha,
    required this.centro,
    required this.contratista,
    required this.profundidadAutorizada,
    required this.auditor,
    required this.buzos,
    this.observacionGeneral = '',
    this.galeriaPaths = const [],
  });
}

class RegistroInmersionPdfBuzo {
  final int numero;
  final String nombre;
  final String rut;
  final String cargo;
  final bool realizoInmersion;
  final bool marcadoRojo;
  final List<RegistroInmersionPdfInmersion> inmersiones;
  final String profundidadMaxima; // resumen: '21 m'
  final String tiempoTotal; // resumen: '45 min'
  final String profundimetro; // 'Scubapro · S/N 123' o ''
  final String registrador; // 'Sensus Ultra · S/N U18659' o ''
  final bool excede; // superó la autorizada (hecho, aunque no se marcó)
  final String nota;
  final List<RegistroInmersionPdfFoto> fotos;

  const RegistroInmersionPdfBuzo({
    required this.numero,
    required this.nombre,
    required this.rut,
    required this.cargo,
    required this.realizoInmersion,
    required this.marcadoRojo,
    required this.inmersiones,
    required this.profundidadMaxima,
    required this.tiempoTotal,
    this.profundimetro = '',
    this.registrador = '',
    this.excede = false,
    this.nota = '',
    this.fotos = const [],
  });
}

class RegistroInmersionPdfInmersion {
  final String profundidad;
  final String desdeHasta;
  final String tiempo;
  const RegistroInmersionPdfInmersion({
    required this.profundidad,
    required this.desdeHasta,
    required this.tiempo,
  });
}

class RegistroInmersionPdfFoto {
  final String etiqueta;
  final String path;
  const RegistroInmersionPdfFoto({required this.etiqueta, required this.path});
}

/// Arma los datos del PDF desde el registro. Pura (sin archivos ni red):
/// [existe] decide qué fotos se incluyen (por defecto, todas).
RegistroInmersionPdfData buildRegistroInmersionPdfData({
  required RegistroInmersion registro,
  required List<RegistroInmersionBuzo> buzos,
  required List<RegistroInmersionFoto> fotos,
  required String auditor,
  bool Function(String path)? existe,
}) {
  final ok = existe ?? (_) => true;
  String? pathDe(RegistroInmersionFoto f) {
    final p = f.localPath;
    return (p != null && p.isNotEmpty && ok(p)) ? p : null;
  }

  final autorizada = registro.profundidadAutorizadaM;
  final buzosPdf = <RegistroInmersionPdfBuzo>[];
  for (var i = 0; i < buzos.length; i++) {
    final b = buzos[i];
    final inmersiones = b.inmersionesValidas
        .map(
          (inm) => RegistroInmersionPdfInmersion(
            profundidad: _metros(inm.profundidadMaximaM),
            desdeHasta: _desdeHasta(inm.horaInicio, inm.horaTermino),
            tiempo: _minutos(inm.tiempoMin),
          ),
        )
        .toList();

    final fotosBuzo = <RegistroInmersionPdfFoto>[];
    for (final tipo in RegistroInmersionFotoTipo.porBuzo) {
      for (final f in fotos.where((f) => f.buzoId == b.id && f.tipo == tipo)) {
        final p = pathDe(f);
        if (p != null) {
          fotosBuzo.add(
            RegistroInmersionPdfFoto(
              etiqueta: RegistroInmersionFotoTipo.etiqueta(tipo),
              path: p,
            ),
          );
        }
      }
    }

    final marca = (b.profundimetroMarca ?? '').trim();
    final serieProf = (b.profundimetroSerie ?? '').trim();
    final profundimetro = [
      if (marca.isNotEmpty) marca,
      if (serieProf.isNotEmpty) 'S/N $serieProf',
    ].join(' · ');
    final serieReg = (b.dispositivoSerie ?? '').trim();
    final registrador = serieReg.isEmpty
        ? ''
        : '${b.dispositivoTipo == kDispositivoSensusUltra ? 'Sensus Ultra' : 'Registrador'} · S/N $serieReg';
    final rut = (b.rut ?? '').trim();

    buzosPdf.add(
      RegistroInmersionPdfBuzo(
        numero: i + 1,
        nombre: b.nombre,
        rut: rut.isEmpty ? '' : RutUtils.format(rut),
        cargo: b.cargo,
        realizoInmersion: b.realizoInmersion,
        marcadoRojo: b.marcadoRojo && b.excede(autorizada),
        inmersiones: inmersiones,
        profundidadMaxima: _metros(b.profundidadMaximaM),
        tiempoTotal: _minutos(b.tiempoTotalMin),
        profundimetro: profundimetro,
        registrador: registrador,
        excede: b.realizoInmersion && b.excede(autorizada),
        nota: (b.nota ?? '').trim(),
        fotos: fotosBuzo,
      ),
    );
  }

  final galeria = fotos
      .where((f) => f.tipo == RegistroInmersionFotoTipo.general)
      .map(pathDe)
      .whereType<String>()
      .toList();

  return RegistroInmersionPdfData(
    correlativo: (registro.correlativo ?? '').isNotEmpty
        ? registro.correlativo!
        : 'Pendiente',
    numeroInspeccion: registro.vinculado
        ? (registro.numeroInspeccion ?? 'Pendiente')
        : null,
    fecha: DateFormat('dd/MM/yyyy').format(registro.fechaRealizacion),
    centro: registro.centroNombre ?? '',
    contratista: registro.contratistaNombre ?? '',
    profundidadAutorizada: _metros(autorizada),
    auditor: auditor,
    buzos: buzosPdf,
    observacionGeneral: registro.observacionGeneral.trim(),
    galeriaPaths: galeria,
  );
}

String _metros(double? v) =>
    v == null ? '' : '${RegistroInmersionCalculos.formatoMetros(v)} m';

String _minutos(int? v) => v == null ? '' : '$v min';

String _desdeHasta(String? desde, String? hasta) {
  final d = RegistroInmersionCalculos.normalizarHora(desde);
  final h = RegistroInmersionCalculos.normalizarHora(hasta);
  if (d == null && h == null) return '';
  return '${d ?? '--:--'} – ${h ?? '--:--'}';
}
