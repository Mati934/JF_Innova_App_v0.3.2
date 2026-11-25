/// Cierre de turno: lo que el auditor entrega al terminar su turno (antes, un
/// PDF a mano por correo). Casi todo se calcula desde la app y se puede
/// corregir. Plan: `docs/planificacion/02_en_progreso/PLAN_TURNO.md` §11.
library;

import 'dart:convert';

import 'turno.dart';

/// Estados guardados (mismo valor en el check de Supabase y en el glosario).
abstract final class CierreEstado {
  static const borrador = 'BORRADOR';
  static const generado = 'GENERADO';
}

/// Un número del cierre (indicador o tickets) con su etiqueta.
class CampoNumero {
  final String clave;
  final String titulo;

  const CampoNumero(this.clave, this.titulo);
}

/// Columna de una sección con filas.
class ColumnaCierre {
  final String clave;
  final String titulo;
  final bool numero;

  /// Ancho relativo en el PDF y en el editor.
  final int flex;

  const ColumnaCierre(
    this.clave,
    this.titulo, {
    this.numero = false,
    this.flex = 2,
  });
}

/// Sección con filas (folios, centros, suspensiones…). Las filas son mapas
/// de texto (todo editable); se guardan como arreglo JSON.
class SeccionCierre {
  final String clave;
  final String titulo;
  final String ayuda;
  final List<ColumnaCierre> columnas;

  /// Viene calculada (true) o la llena el auditor (false).
  final bool automatica;

  const SeccionCierre({
    required this.clave,
    required this.titulo,
    required this.ayuda,
    required this.columnas,
    this.automatica = true,
  });

  Map<String, String> filaVacia() => {for (final c in columnas) c.clave: ''};
}

abstract final class CierreCampos {
  static const indicadores = [
    CampoNumero('n_centros', 'Centros'),
    CampoNumero('n_insp_buceo', 'Insp. buceo'),
    CampoNumero('n_ast', 'AST'),
    CampoNumero('n_insp_emb', 'Insp. embarcación'),
    CampoNumero('n_reg_act', 'Reg. actividad'),
    CampoNumero('n_obs_buceo', 'Obs. buceo'),
    CampoNumero('n_obs_emb', 'Obs. embarcación'),
    CampoNumero('n_faenas_suspendidas', 'Faenas suspendidas'),
  ];

  /// Tickets del profesional en el turno (como "Tickets históricos por
  /// profesional" del dashboard, acotado al período).
  static const tickets = [
    CampoNumero('tk_creados', 'Creados'),
    CampoNumero('tk_cerrados', 'Cerrados por ti'),
    CampoNumero('tk_solo_creo', 'Solo creó'),
    CampoNumero('tk_creo_y_cerro', 'Creó y cerró'),
    CampoNumero('tk_solo_cerro', 'Solo cerró'),
    CampoNumero('tk_abiertos', 'Abiertos'),
    CampoNumero('tk_tomados', 'Tomados'),
    CampoNumero('tk_parciales', 'Parciales'),
    CampoNumero('tk_por_revisar', 'Por revisar'),
    CampoNumero('tk_estado_cerrados', 'Cerrados'),
    CampoNumero('tk_a_cargo', 'A tu cargo hoy'),
  ];

  static const secciones = [
    SeccionCierre(
      clave: 'folios',
      titulo: 'Control de folios',
      ayuda: 'Primer y último número de informe del turno por tipo.',
      columnas: [
        ColumnaCierre('tipo', 'Ítem', flex: 3),
        ColumnaCierre('inicial', 'Inicial', numero: true, flex: 1),
        ColumnaCierre('final', 'Final', numero: true, flex: 1),
        ColumnaCierre('cantidad', 'Cant.', numero: true, flex: 1),
        ColumnaCierre('nota', 'Notas de continuidad', flex: 6),
      ],
    ),
    SeccionCierre(
      clave: 'centros',
      titulo: 'Actividades por centro',
      ayuda:
          'Inspecciones por centro y sus observaciones (de los tickets). '
          'EPP y Cil. se llenan a mano.',
      columnas: [
        ColumnaCierre('centro', 'Centro', flex: 4),
        ColumnaCierre('buceo', 'Buceo', numero: true, flex: 1),
        ColumnaCierre('reg', 'Reg.', numero: true, flex: 1),
        ColumnaCierre('emb', 'Emb.', numero: true, flex: 1),
        ColumnaCierre('ast', 'AST', numero: true, flex: 1),
        ColumnaCierre('epp', 'EPP', numero: true, flex: 1),
        ColumnaCierre('cil', 'Cil.', numero: true, flex: 1),
        ColumnaCierre('obs_tot', 'Obs. tot.', numero: true, flex: 1),
        ColumnaCierre('obs_cerr', 'Cerr.', numero: true, flex: 1),
        ColumnaCierre('obs_pen', 'Pend.', numero: true, flex: 1),
      ],
    ),
    SeccionCierre(
      clave: 'suspensiones',
      titulo: 'Faenas suspendidas',
      ayuda:
          'Las inspecciones con faena SUSPENDIDA. Agrega las que se '
          'suspendieron y se habilitaron el mismo día.',
      columnas: [
        ColumnaCierre('centro', 'Centro', flex: 2),
        ColumnaCierre('empresa', 'Empresa', flex: 2),
        ColumnaCierre('categoria', 'Categoría', flex: 2),
        ColumnaCierre('motivo', 'Motivo', flex: 4),
        ColumnaCierre('fecha', 'Fecha', flex: 2),
        ColumnaCierre('estado', 'Estado', flex: 2),
      ],
    ),
    SeccionCierre(
      clave: 'informes_pendientes',
      titulo: 'Informes con observaciones',
      ayuda:
          'Cada informe del turno con observaciones de tickets: cuántas '
          'están cerradas y cuántas pendientes.',
      columnas: [
        ColumnaCierre('tipo', 'Categoría / tipo', flex: 5),
        ColumnaCierre('numero', 'N° informe', numero: true, flex: 2),
        ColumnaCierre('cerradas', 'Cerradas', numero: true, flex: 2),
        ColumnaCierre('pendientes', 'Pendientes', numero: true, flex: 2),
      ],
    ),
    SeccionCierre(
      clave: 'hallazgos',
      titulo: 'Hallazgos críticos',
      ayuda: 'Hallazgos Intolerables detectados en las inspecciones del turno.',
      columnas: [
        ColumnaCierre('centro', 'Centro', flex: 2),
        ColumnaCierre('empresa', 'Empresa', flex: 2),
        ColumnaCierre('categoria', 'Categoría', flex: 2),
        ColumnaCierre('descripcion', 'Descripción', flex: 6),
        ColumnaCierre('criticidad', 'Criticidad', flex: 2),
        ColumnaCierre('estado', 'Estado', flex: 2),
      ],
    ),
    SeccionCierre(
      clave: 'servicios',
      titulo: 'Directorio de servicios',
      ayuda:
          'Empresas con las que trabajaste. Lo que corrijas queda guardado '
          'para tus colegas de la empresa.',
      columnas: [
        ColumnaCierre('empresa', 'Empresa', flex: 3),
        ColumnaCierre('actividad', 'Actividad', flex: 3),
        ColumnaCierre('supervisor', 'Supervisor', flex: 3),
        ColumnaCierre('correo', 'Correo', flex: 4),
        ColumnaCierre('fono', 'Fono', flex: 2),
      ],
    ),
    SeccionCierre(
      clave: 'puertos_cerrados',
      titulo: 'Puertos cerrados / sin ingreso a centros',
      ayuda: 'Días en que no pudiste ingresar a un centro y por qué.',
      automatica: false,
      columnas: [
        ColumnaCierre('area', 'Área', flex: 2),
        ColumnaCierre('centro', 'Centro', flex: 2),
        ColumnaCierre('fecha', 'Fecha', flex: 2),
        ColumnaCierre('motivo', 'Motivo de no ingreso', flex: 5),
      ],
    ),
  ];

  static SeccionCierre seccion(String clave) =>
      secciones.firstWhere((s) => s.clave == clave);

  static Iterable<String> get clavesNumeros =>
      [...indicadores, ...tickets].map((c) => c.clave);
}

typedef FilaCierre = Map<String, String>;

class TurnoCierre {
  final String id;
  final String turnoId;
  final String usuarioId;
  final String? empresaId;
  final String? areaId;
  final DateTime desde;
  final DateTime hasta;
  final String estado;

  /// Indicadores y tickets (claves de [CierreCampos]); null = sin dato.
  final Map<String, int?> numeros;

  /// Filas por sección (claves de [CierreCampos.secciones]).
  final Map<String, List<FilaCierre>> filas;
  final String? bitacora;
  final String? pdfUrl;
  final String? pdfVersion;
  final DateTime? pdfGeneradoAt;
  final String? pdfPathLocal;
  final String? appVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool subido;

  const TurnoCierre({
    required this.id,
    required this.turnoId,
    required this.usuarioId,
    required this.empresaId,
    required this.areaId,
    required this.desde,
    required this.hasta,
    required this.estado,
    required this.numeros,
    required this.filas,
    required this.bitacora,
    required this.pdfUrl,
    required this.pdfVersion,
    required this.pdfGeneradoAt,
    required this.pdfPathLocal,
    required this.appVersion,
    required this.createdAt,
    required this.updatedAt,
    this.subido = false,
  });

  bool get generado => estado == CierreEstado.generado;
  bool get tienePdf =>
      (pdfUrl?.isNotEmpty ?? false) || (pdfPathLocal?.isNotEmpty ?? false);

  List<FilaCierre> filasDe(String seccion) => filas[seccion] ?? const [];

  TurnoCierre copyWith({
    DateTime? desde,
    DateTime? hasta,
    String? estado,
    Map<String, int?>? numeros,
    Map<String, List<FilaCierre>>? filas,
    String? bitacora,
    String? pdfUrl,
    String? pdfVersion,
    DateTime? pdfGeneradoAt,
    String? pdfPathLocal,
    String? appVersion,
    DateTime? updatedAt,
    bool? subido,
  }) => TurnoCierre(
    id: id,
    turnoId: turnoId,
    usuarioId: usuarioId,
    empresaId: empresaId,
    areaId: areaId,
    desde: desde ?? this.desde,
    hasta: hasta ?? this.hasta,
    estado: estado ?? this.estado,
    numeros: numeros ?? this.numeros,
    filas: filas ?? this.filas,
    bitacora: bitacora ?? this.bitacora,
    pdfUrl: pdfUrl ?? this.pdfUrl,
    pdfVersion: pdfVersion ?? this.pdfVersion,
    pdfGeneradoAt: pdfGeneradoAt ?? this.pdfGeneradoAt,
    pdfPathLocal: pdfPathLocal ?? this.pdfPathLocal,
    appVersion: appVersion ?? this.appVersion,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    subido: subido ?? this.subido,
  );

  /// Fila para SQLite (secciones como texto JSON).
  Map<String, dynamic> toRow() => {
    'id': id,
    'turno_id': turnoId,
    'usuario_id': usuarioId,
    'empresa_id': empresaId,
    'area_id': areaId,
    'desde': TurnoFechas.aTexto(desde),
    'hasta': TurnoFechas.aTexto(hasta),
    'estado': estado,
    for (final k in CierreCampos.clavesNumeros) k: numeros[k],
    for (final s in CierreCampos.secciones)
      s.clave: jsonEncode(filas[s.clave] ?? const []),
    'bitacora': bitacora,
    'pdf_url': pdfUrl,
    'pdf_version': pdfVersion,
    'pdf_generado_at': pdfGeneradoAt?.toUtc().toIso8601String(),
    'pdf_path_local': pdfPathLocal,
    'app_version': appVersion,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory TurnoCierre.fromRow(Map<String, dynamic> r) {
    DateTime ts(Object? v) =>
        DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();
    String? texto(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return TurnoCierre(
      id: r['id'].toString(),
      turnoId: r['turno_id'].toString(),
      usuarioId: r['usuario_id'].toString(),
      empresaId: texto(r['empresa_id']),
      areaId: texto(r['area_id']),
      desde: TurnoFechas.deTexto(r['desde'].toString()),
      hasta: TurnoFechas.deTexto(r['hasta'].toString()),
      estado: r['estado']?.toString() ?? CierreEstado.borrador,
      numeros: {for (final k in CierreCampos.clavesNumeros) k: _entero(r[k])},
      filas: {
        for (final s in CierreCampos.secciones) s.clave: filasDesde(r[s.clave]),
      },
      bitacora: texto(r['bitacora']),
      pdfUrl: texto(r['pdf_url']),
      pdfVersion: texto(r['pdf_version']),
      pdfGeneradoAt: texto(r['pdf_generado_at']) == null
          ? null
          : ts(r['pdf_generado_at']),
      pdfPathLocal: texto(r['pdf_path_local']),
      appVersion: texto(r['app_version']),
      createdAt: ts(r['created_at']),
      updatedAt: ts(r['updated_at']),
      subido: r['subido'] == 1,
    );
  }

  static int? _entero(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  /// Acepta el texto JSON de SQLite o la lista que devuelve Supabase (JSONB).
  static List<FilaCierre> filasDesde(Object? v) {
    Object? data = v;
    if (v is String) {
      try {
        data = jsonDecode(v);
      } catch (_) {
        return [];
      }
    }
    if (data is! List) return [];
    return [
      for (final f in data)
        if (f is Map)
          {
            for (final e in f.entries)
              e.key.toString(): e.value?.toString() ?? '',
          },
    ];
  }
}
