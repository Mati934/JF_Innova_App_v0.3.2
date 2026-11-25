/// Módulo Turno: ingreso y egreso del auditor. Plan:
/// `docs/planificacion/02_en_progreso/PLAN_TURNO.md`.
library;

/// Estados guardados (mismo valor en el check de Supabase y en el glosario).
/// "Vencido" no se guarda: se calcula con [TurnoReglas.vencido].
abstract final class TurnoEstado {
  static const activo = 'ACTIVO';
  static const cerrado = 'CERRADO';
}

/// Un turno del auditor. Las fechas del turno son días (sin hora), en la
/// fecha local del celular.
class Turno {
  final String id;
  final String usuarioId;
  final String? empresaId;
  final String areaId;
  final String? centroId;
  final String estado;
  final DateTime ingresoFecha;
  final DateTime egresoEstimado;
  final DateTime? egresoFecha;
  final bool extraordinario;
  final String? observacionIngreso;
  final String? observacionEgreso;
  final DateTime ingresoRegistradoAt;
  final DateTime? egresoRegistradoAt;
  final String? appVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool subido;

  /// Solo para mostrar (vienen de las tablas locales de áreas y centros).
  final String? areaNombre;
  final String? centroNombre;

  const Turno({
    required this.id,
    required this.usuarioId,
    required this.empresaId,
    required this.areaId,
    required this.centroId,
    required this.estado,
    required this.ingresoFecha,
    required this.egresoEstimado,
    required this.egresoFecha,
    required this.extraordinario,
    required this.observacionIngreso,
    required this.observacionEgreso,
    required this.ingresoRegistradoAt,
    required this.egresoRegistradoAt,
    required this.appVersion,
    required this.createdAt,
    required this.updatedAt,
    this.subido = false,
    this.areaNombre,
    this.centroNombre,
  });

  bool get activo => estado == TurnoEstado.activo;

  /// Fila para SQLite (las mismas columnas que Supabase + `subido`/`eliminado`).
  Map<String, dynamic> toRow() => {
    'id': id,
    'usuario_id': usuarioId,
    'empresa_id': empresaId,
    'area_id': areaId,
    'centro_id': centroId,
    'estado': estado,
    'ingreso_fecha': TurnoFechas.aTexto(ingresoFecha),
    'egreso_estimado': TurnoFechas.aTexto(egresoEstimado),
    'egreso_fecha': egresoFecha == null
        ? null
        : TurnoFechas.aTexto(egresoFecha!),
    'extraordinario': extraordinario ? 1 : 0,
    'observacion_ingreso': observacionIngreso,
    'observacion_egreso': observacionEgreso,
    'ingreso_registrado_at': ingresoRegistradoAt.toUtc().toIso8601String(),
    'egreso_registrado_at': egresoRegistradoAt?.toUtc().toIso8601String(),
    'app_version': appVersion,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory Turno.fromRow(Map<String, dynamic> r) {
    DateTime ts(Object? v) =>
        DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();
    DateTime? tsOpt(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    String? texto(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return Turno(
      id: r['id'].toString(),
      usuarioId: r['usuario_id'].toString(),
      empresaId: texto(r['empresa_id']),
      areaId: r['area_id'].toString(),
      centroId: texto(r['centro_id']),
      estado: r['estado']?.toString() ?? TurnoEstado.activo,
      ingresoFecha: TurnoFechas.deTexto(r['ingreso_fecha'].toString()),
      egresoEstimado: TurnoFechas.deTexto(r['egreso_estimado'].toString()),
      egresoFecha: texto(r['egreso_fecha']) == null
          ? null
          : TurnoFechas.deTexto(r['egreso_fecha'].toString()),
      extraordinario: r['extraordinario'] == 1 || r['extraordinario'] == true,
      observacionIngreso: texto(r['observacion_ingreso']),
      observacionEgreso: texto(r['observacion_egreso']),
      ingresoRegistradoAt: ts(r['ingreso_registrado_at']),
      egresoRegistradoAt: tsOpt(r['egreso_registrado_at']),
      appVersion: texto(r['app_version']),
      createdAt: ts(r['created_at']),
      updatedAt: ts(r['updated_at']),
      subido: r['subido'] == 1,
      areaNombre: texto(r['area_nombre']),
      centroNombre: texto(r['centro_nombre']),
    );
  }
}

/// Fechas del turno como días (sin hora). Se suman días con el constructor
/// (no con `Duration`) para no correrse con el cambio de horario.
abstract final class TurnoFechas {
  static DateTime dia(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime sumar(DateTime d, int dias) =>
      DateTime(d.year, d.month, d.day + dias);

  /// Días de `desde` a `hasta` (0 si es el mismo día; negativo si es antes).
  static int entre(DateTime desde, DateTime hasta) => DateTime.utc(
    hasta.year,
    hasta.month,
    hasta.day,
  ).difference(DateTime.utc(desde.year, desde.month, desde.day)).inDays;

  static String aTexto(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime deTexto(String s) {
    final p = s.substring(0, 10).split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

  /// "24/11"
  static String corta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// "lun 24/11"
  static String conDia(DateTime d) => '${_dias[d.weekday - 1]} ${corta(d)}';

  /// "24/11/2026"
  static String larga(DateTime d) => '${corta(d)}/${d.year}';

  static const _diasLargos = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// "miércoles"
  static String nombreDia(DateTime d) => _diasLargos[d.weekday - 1];

  /// "nov"
  static String mes(DateTime d) => _meses[d.month - 1];

  /// "mié 25 nov"
  static String legible(DateTime d) =>
      '${_dias[d.weekday - 1]} ${d.day} ${mes(d)}';
}

/// Reglas del turno (PLAN_TURNO.md §2). Todas reciben `hoy` para poder
/// probarlas sin depender del reloj.
abstract final class TurnoReglas {
  /// Largo estándar: el día de ingreso + 13.
  static const diasTurno = 14;

  /// Salida propuesta (automática). El auditor puede acortarla, por ejemplo
  /// en un turno extra; nunca más larga que [diasTurno].
  static DateTime egresoEstimado(DateTime ingreso) =>
      TurnoFechas.sumar(ingreso, diasTurno - 1);

  /// Días del turno planificado (ingreso y salida estimada incluidos).
  static int duracion(DateTime ingreso, DateTime egresoEstimado) =>
      TurnoFechas.entre(ingreso, egresoEstimado) + 1;

  /// Null si la salida estimada sirve: entre el ingreso y ingreso + 13.
  static String? validarEgresoEstimado(DateTime ingreso, DateTime egreso) {
    final d = TurnoFechas.entre(ingreso, egreso);
    if (d < 0) return 'La salida no puede ser anterior al ingreso.';
    if (d > diasTurno - 1) {
      return 'El turno no puede durar más de $diasTurno días.';
    }
    return null;
  }

  /// Día del turno (1 = día de ingreso). Puede pasar de 14 si no cerró.
  static int diaDelTurno(DateTime ingreso, DateTime hoy) =>
      TurnoFechas.entre(ingreso, hoy) + 1;

  static bool vencido(Turno t, DateTime hoy) =>
      t.activo && TurnoFechas.entre(t.egresoEstimado, hoy) > 0;

  /// Primer día que se puede elegir como ingreso: 13 días atrás, y siempre
  /// después de la salida del turno anterior.
  static DateTime ingresoMinimo(DateTime hoy, {DateTime? ultimaSalida}) {
    final porLargo = TurnoFechas.sumar(hoy, -(diasTurno - 1));
    if (ultimaSalida == null) return porLargo;
    final trasSalida = TurnoFechas.sumar(ultimaSalida, 1);
    return trasSalida.isAfter(porLargo) ? trasSalida : porLargo;
  }

  /// Null si la fecha de ingreso es válida; si no, el motivo.
  static String? validarIngreso(
    DateTime fecha,
    DateTime hoy, {
    DateTime? ultimaSalida,
  }) {
    final f = TurnoFechas.dia(fecha);
    if (TurnoFechas.entre(hoy, f) > 0) {
      return 'La fecha de ingreso no puede ser futura.';
    }
    if (ultimaSalida != null && TurnoFechas.entre(ultimaSalida, f) <= 0) {
      return 'Tu turno anterior terminó el '
          '${TurnoFechas.corta(ultimaSalida)}: el ingreso debe ser posterior.';
    }
    if (TurnoFechas.entre(f, hoy) > diasTurno - 1) {
      return 'El ingreso no puede ser de hace más de ${diasTurno - 1} días.';
    }
    return null;
  }

  /// Fecha que se propone al confirmar salida: hoy, o la salida estimada si
  /// hoy ya la pasó (lo más probable es que haya olvidado marcarla).
  static DateTime salidaPropuesta(Turno t, DateTime hoy) {
    final h = TurnoFechas.dia(hoy);
    return TurnoFechas.entre(t.egresoEstimado, h) > 0 ? t.egresoEstimado : h;
  }

  /// Null si la fecha de salida es válida (entre el ingreso y hoy).
  static String? validarSalida(DateTime fecha, Turno t, DateTime hoy) {
    if (TurnoFechas.entre(hoy, fecha) > 0) {
      return 'La fecha de salida no puede ser futura.';
    }
    if (TurnoFechas.entre(t.ingresoFecha, fecha) < 0) {
      return 'La salida no puede ser anterior al ingreso '
          '(${TurnoFechas.corta(t.ingresoFecha)}).';
    }
    return null;
  }

  /// Días trabajados contando el de ingreso y el de salida.
  static int diasReales(DateTime ingreso, DateTime egreso) =>
      TurnoFechas.entre(ingreso, egreso) + 1;

  /// "a tiempo", "2 días antes", "1 día después" respecto de la estimada.
  static String diferencia(DateTime egreso, DateTime estimado) {
    final d = TurnoFechas.entre(estimado, egreso);
    if (d == 0) return 'a tiempo';
    final n = d.abs();
    return '$n ${n == 1 ? 'día' : 'días'} ${d < 0 ? 'antes' : 'después'}';
  }
}
