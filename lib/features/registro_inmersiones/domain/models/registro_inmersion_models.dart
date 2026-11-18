/// Modelos del módulo Registro de inmersiones.
///
/// Un registro por inspección de buceo (`actividad_id`), una fila por buzo y
/// una o más inmersiones por buzo (lo normal es una). Tablas locales
/// `registros_inmersion_pendientes`, `registro_inmersion_buzos_pendientes`,
/// `registro_inmersion_inmersiones_pendientes` y
/// `registro_inmersion_fotos_pendientes`.
library;

/// Clave del módulo en `ModuleRegistry` / `empresa_modulos` y del contador en
/// `numeradores_informe`.
const String kRegistroInmersionesModuleKey = 'REGISTRO_INMERSIONES';

/// Estados de la cabecera (mismos valores que el check de Supabase).
class RegistroInmersionEstado {
  static const borrador = 'Borrador';
  static const finalizado = 'Finalizado';
  static const eliminada = 'Eliminada';
}

/// Desde dónde se creó el registro (para medir si el aviso sirve).
class RegistroInmersionOrigen {
  static const avisoFinalizar = 'AVISO_FINALIZAR';
  static const tarjetaInicio = 'TARJETA_INICIO';
}

/// Tipos de foto (mismos valores que el check de Supabase).
class RegistroInmersionFotoTipo {
  static const profundimetro = 'PROFUNDIMETRO';
  static const dispositivo = 'DISPOSITIVO';
  static const buzoGeneral = 'BUZO_GENERAL';
  static const general = 'GENERAL';

  static const porBuzo = [profundimetro, dispositivo, buzoGeneral];

  static String etiqueta(String tipo) {
    switch (tipo) {
      case profundimetro:
        return 'Profundímetro';
      case dispositivo:
        return 'Dispositivo';
      case buzoGeneral:
        return 'Foto del buzo';
      default:
        return 'General';
    }
  }
}

/// Cargos del registro: los de la cuadrilla más "Buzo de emergencia".
const List<String> kCargosRegistroInmersion = [
  'Buzo',
  'Buzo de emergencia',
  'Supervisor',
  'Asistente',
  'Personal de Apoyo',
  'Otro',
];

const String kDispositivoSensusUltra = 'SENSUS_ULTRA';

/// Cálculos puros (sin estado) usados por el formulario, el sync y el PDF.
class RegistroInmersionCalculos {
  const RegistroInmersionCalculos._();

  static final RegExp _hhmm = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');

  /// Minutos desde medianoche de una hora `HH:mm`, o null si no es válida.
  static int? minutosDelDia(String? hhmm) {
    final m = _hhmm.firstMatch((hhmm ?? '').trim());
    if (m == null) return null;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  /// Normaliza una hora a `HH:mm` (ej. `9:05` → `09:05`), o null.
  static String? normalizarHora(String? hhmm) {
    final min = minutosDelDia(hhmm);
    if (min == null) return null;
    final h = (min ~/ 60).toString().padLeft(2, '0');
    final mm = (min % 60).toString().padLeft(2, '0');
    return '$h:$mm';
  }

  /// Duración en minutos. Si "hasta" es menor que "desde", se asume que la
  /// inmersión cruzó la medianoche.
  static int? tiempoMin(String? desde, String? hasta) {
    final d = minutosDelDia(desde);
    final h = minutosDelDia(hasta);
    if (d == null || h == null) return null;
    final diff = h - d;
    return diff >= 0 ? diff : diff + 24 * 60;
  }

  /// Una autorizada nula o 0 es "sin dato": nunca cuenta como exceso.
  static bool excede(double? profundidad, double? autorizada) =>
      profundidad != null &&
      autorizada != null &&
      autorizada > 0 &&
      profundidad > autorizada;

  /// Acepta coma decimal (`18,8`). Null si vacío o no numérico.
  static double? parseMetros(String? texto) {
    final t = (texto ?? '').trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v < 0) return null;
    return v;
  }

  /// Serie de equipo normalizada para poder juntarla después
  /// (`u-18659` → `U18659`).
  static String? normalizarSerie(String? serie) {
    final s = (serie ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return s.isEmpty ? null : s;
  }

  /// Metros para mostrar: `21` o `18,8`.
  static String formatoMetros(double? v) {
    if (v == null) return '';
    final txt = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return txt.replaceAll('.', ',');
  }
}

/// Una bajada de un buzo.
class Inmersion {
  final String id;
  final String buzoId;
  final String registroId;
  int orden;
  double? profundidadMaximaM;
  String? horaInicio;
  bool horaInicioEditada;
  String? horaTermino;

  Inmersion({
    required this.id,
    required this.buzoId,
    required this.registroId,
    this.orden = 1,
    this.profundidadMaximaM,
    this.horaInicio,
    this.horaInicioEditada = false,
    this.horaTermino,
  });

  int? get tiempoMin =>
      RegistroInmersionCalculos.tiempoMin(horaInicio, horaTermino);

  bool excede(double? autorizada) =>
      RegistroInmersionCalculos.excede(profundidadMaximaM, autorizada);

  Map<String, dynamic> toRow(double? autorizada) => {
    'id': id,
    'buzo_id': buzoId,
    'registro_id': registroId,
    'orden': orden,
    'profundidad_maxima_m': profundidadMaximaM,
    'excede_autorizada': excede(autorizada) ? 1 : 0,
    'hora_inicio': RegistroInmersionCalculos.normalizarHora(horaInicio),
    'hora_inicio_editada': horaInicioEditada ? 1 : 0,
    'hora_termino': RegistroInmersionCalculos.normalizarHora(horaTermino),
    'tiempo_min': tiempoMin,
  };

  factory Inmersion.fromRow(Map<String, dynamic> r) => Inmersion(
    id: r['id'].toString(),
    buzoId: r['buzo_id'].toString(),
    registroId: r['registro_id'].toString(),
    orden: (r['orden'] as num?)?.toInt() ?? 1,
    profundidadMaximaM: (r['profundidad_maxima_m'] as num?)?.toDouble(),
    horaInicio: r['hora_inicio']?.toString(),
    horaInicioEditada: r['hora_inicio_editada'] == 1,
    horaTermino: r['hora_termino']?.toString(),
  );
}

/// Un buzo de la faena con sus inmersiones y el resumen del día.
class RegistroInmersionBuzo {
  final String id;
  final String registroId;
  String? personalId;
  String nombre;
  String? rut;
  String cargo;
  bool realizoInmersion;
  bool marcadoRojo;
  String? profundimetroMarca;
  String? profundimetroSerie;
  String? dispositivoTipo;
  String? dispositivoSerie;
  String? nota;
  int orden;
  final List<Inmersion> inmersiones;

  RegistroInmersionBuzo({
    required this.id,
    required this.registroId,
    required this.nombre,
    this.personalId,
    this.rut,
    this.cargo = 'Buzo',
    this.realizoInmersion = true,
    this.marcadoRojo = false,
    this.profundimetroMarca,
    this.profundimetroSerie,
    this.dispositivoTipo,
    this.dispositivoSerie,
    this.nota,
    this.orden = 0,
    List<Inmersion>? inmersiones,
  }) : inmersiones = inmersiones ?? [];

  /// Inmersiones que cuentan: solo si buceó y tienen algún dato.
  List<Inmersion> get inmersionesValidas {
    if (!realizoInmersion) return const [];
    return inmersiones
        .where(
          (i) =>
              i.profundidadMaximaM != null ||
              (i.horaInicio ?? '').isNotEmpty ||
              (i.horaTermino ?? '').isNotEmpty,
        )
        .toList();
  }

  /// La mayor profundidad del día.
  double? get profundidadMaximaM {
    double? max;
    for (final i in inmersionesValidas) {
      final p = i.profundidadMaximaM;
      if (p != null && (max == null || p > max)) max = p;
    }
    return max;
  }

  /// Suma de los tiempos que se pudieron calcular (null si ninguno).
  int? get tiempoTotalMin {
    int? total;
    for (final i in inmersionesValidas) {
      final t = i.tiempoMin;
      if (t != null) total = (total ?? 0) + t;
    }
    return total;
  }

  int get cantidadInmersiones => inmersionesValidas.length;

  bool excede(double? autorizada) =>
      inmersionesValidas.any((i) => i.excede(autorizada));

  Map<String, dynamic> toRow(double? autorizada) => {
    'id': id,
    'registro_id': registroId,
    'personal_id': personalId,
    'nombre': nombre,
    'rut': rut,
    'cargo': cargo,
    'realizo_inmersion': realizoInmersion ? 1 : 0,
    'profundidad_maxima_m': profundidadMaximaM,
    'excede_autorizada': excede(autorizada) ? 1 : 0,
    // Solo cuenta el rojo si de verdad hay exceso.
    'marcado_rojo': (marcadoRojo && excede(autorizada)) ? 1 : 0,
    'tiempo_total_min': tiempoTotalMin,
    'cantidad_inmersiones': cantidadInmersiones,
    'profundimetro_marca': _vacioANull(profundimetroMarca),
    'profundimetro_serie': RegistroInmersionCalculos.normalizarSerie(
      profundimetroSerie,
    ),
    'dispositivo_tipo': _vacioANull(dispositivoTipo),
    'dispositivo_serie': RegistroInmersionCalculos.normalizarSerie(
      dispositivoSerie,
    ),
    'nota': _vacioANull(nota),
    'orden': orden,
  };

  factory RegistroInmersionBuzo.fromRow(
    Map<String, dynamic> r, {
    List<Inmersion> inmersiones = const [],
  }) => RegistroInmersionBuzo(
    id: r['id'].toString(),
    registroId: r['registro_id'].toString(),
    personalId: r['personal_id']?.toString(),
    nombre: (r['nombre'] ?? '').toString(),
    rut: r['rut']?.toString(),
    cargo: (r['cargo'] ?? 'Buzo').toString(),
    realizoInmersion: r['realizo_inmersion'] != 0,
    marcadoRojo: r['marcado_rojo'] == 1,
    profundimetroMarca: r['profundimetro_marca']?.toString(),
    profundimetroSerie: r['profundimetro_serie']?.toString(),
    dispositivoTipo: r['dispositivo_tipo']?.toString(),
    dispositivoSerie: r['dispositivo_serie']?.toString(),
    nota: r['nota']?.toString(),
    orden: (r['orden'] as num?)?.toInt() ?? 0,
    inmersiones: List.of(inmersiones),
  );
}

/// Una foto del registro (por buzo o de la galería general).
class RegistroInmersionFoto {
  final String id;
  final String registroId;
  final String? buzoId;
  final String tipo;
  int posicion;
  String? localPath;
  String? storagePath;
  String? fotoUrl;
  String? descripcion;
  bool subido;

  RegistroInmersionFoto({
    required this.id,
    required this.registroId,
    required this.tipo,
    this.buzoId,
    this.posicion = 0,
    this.localPath,
    this.storagePath,
    this.fotoUrl,
    this.descripcion,
    this.subido = false,
  });

  Map<String, dynamic> toRow() => {
    'id': id,
    'registro_id': registroId,
    'buzo_id': buzoId,
    'tipo': tipo,
    'posicion': posicion,
    'local_path': localPath,
    'storage_path': storagePath,
    'foto_url': fotoUrl,
    'descripcion': descripcion,
    'subido': subido ? 1 : 0,
  };

  factory RegistroInmersionFoto.fromRow(Map<String, dynamic> r) =>
      RegistroInmersionFoto(
        id: r['id'].toString(),
        registroId: r['registro_id'].toString(),
        buzoId: r['buzo_id']?.toString(),
        tipo: (r['tipo'] ?? RegistroInmersionFotoTipo.general).toString(),
        posicion: (r['posicion'] as num?)?.toInt() ?? 0,
        localPath: r['local_path']?.toString(),
        storagePath: r['storage_path']?.toString(),
        fotoUrl: r['foto_url']?.toString(),
        descripcion: r['descripcion']?.toString(),
        subido: r['subido'] == 1,
      );
}

/// Cabecera del registro.
class RegistroInmersion {
  final String id;
  final String actividadId;
  String? empresaId;
  String? usuarioId;
  String? centroId;
  String? contratistaId;
  String? centroNombre;
  String? contratistaNombre;
  String? numeroInspeccion;
  DateTime fechaRealizacion;
  double? profundidadAutorizadaM;
  String observacionGeneral;
  String origen;
  String estadoFinal;
  int? numero;
  String? correlativo;
  String? pdfUrl;
  String? pdfVersion;
  String? pdfPathLocal;
  String? createdAt;

  RegistroInmersion({
    required this.id,
    required this.actividadId,
    DateTime? fechaRealizacion,
    this.empresaId,
    this.usuarioId,
    this.centroId,
    this.contratistaId,
    this.centroNombre,
    this.contratistaNombre,
    this.numeroInspeccion,
    this.profundidadAutorizadaM,
    this.observacionGeneral = '',
    this.origen = RegistroInmersionOrigen.tarjetaInicio,
    this.estadoFinal = RegistroInmersionEstado.borrador,
    this.numero,
    this.correlativo,
    this.pdfUrl,
    this.pdfVersion,
    this.pdfPathLocal,
    this.createdAt,
  }) : fechaRealizacion = fechaRealizacion ?? DateTime.now();

  Map<String, dynamic> toRow() {
    final ahora = DateTime.now().toIso8601String();
    return {
      'id': id,
      'actividad_id': actividadId,
      'empresa_id': empresaId,
      'usuario_id': usuarioId,
      'centro_id': centroId,
      'contratista_id': contratistaId,
      'centro_nombre': centroNombre,
      'contratista_nombre': contratistaNombre,
      'numero_inspeccion': numeroInspeccion,
      'fecha_realizacion': fechaRealizacion.toIso8601String(),
      'profundidad_autorizada_m': profundidadAutorizadaM,
      'observacion_general': observacionGeneral,
      'origen': origen,
      'estado_final': estadoFinal,
      'numero': numero,
      'correlativo': correlativo,
      'pdf_url': pdfUrl,
      'pdf_version': pdfVersion,
      'pdf_path_local': pdfPathLocal,
      'created_at': createdAt ?? ahora,
      'updated_at': ahora,
    };
  }

  factory RegistroInmersion.fromRow(
    Map<String, dynamic> r,
  ) => RegistroInmersion(
    id: r['id'].toString(),
    actividadId: r['actividad_id'].toString(),
    empresaId: r['empresa_id']?.toString(),
    usuarioId: r['usuario_id']?.toString(),
    centroId: r['centro_id']?.toString(),
    contratistaId: r['contratista_id']?.toString(),
    centroNombre: r['centro_nombre']?.toString(),
    contratistaNombre: r['contratista_nombre']?.toString(),
    numeroInspeccion: r['numero_inspeccion']?.toString(),
    fechaRealizacion:
        DateTime.tryParse((r['fecha_realizacion'] ?? '').toString()) ??
        DateTime.now(),
    profundidadAutorizadaM: (r['profundidad_autorizada_m'] as num?)?.toDouble(),
    observacionGeneral: (r['observacion_general'] ?? '').toString(),
    origen: (r['origen'] ?? RegistroInmersionOrigen.tarjetaInicio).toString(),
    estadoFinal: (r['estado_final'] ?? RegistroInmersionEstado.borrador)
        .toString(),
    numero: (r['numero'] as num?)?.toInt(),
    correlativo: r['correlativo']?.toString(),
    pdfUrl: r['pdf_url']?.toString(),
    pdfVersion: r['pdf_version']?.toString(),
    pdfPathLocal: r['pdf_path_local']?.toString(),
    createdAt: r['created_at']?.toString(),
  );
}

String? _vacioANull(String? v) {
  final t = (v ?? '').trim();
  return t.isEmpty ? null : t;
}
