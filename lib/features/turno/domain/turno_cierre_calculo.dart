/// Cálculo automático del cierre de turno a partir de lo que el auditor
/// registró en la app. Sin Supabase ni reloj: recibe las filas ya leídas
/// (ver `TurnoCierreService`) para poder probarlo.
library;

import 'turno.dart';
import 'turno_cierre.dart';

class ActividadFuente {
  final String id;
  final String tipo;
  final int? numero;
  final DateTime fecha;
  final String? centro;
  final String? empresa;
  final String? estadoFaena;
  final String? supervisor;
  final String? correo;

  const ActividadFuente({
    required this.id,
    required this.tipo,
    required this.numero,
    required this.fecha,
    this.centro,
    this.empresa,
    this.estadoFaena,
    this.supervisor,
    this.correo,
  });
}

class AstFuente {
  final String id;
  final int? numero;
  final DateTime fecha;
  final String? centro;
  final String? empresa;

  const AstFuente({
    required this.id,
    required this.numero,
    required this.fecha,
    this.centro,
    this.empresa,
  });
}

class TicketFuente {
  final String id;
  final String? inspeccionId;
  final String? tipoInspeccion;
  final String estado;
  final String? centro;

  /// Observaciones (ítems) del ticket y cuántas están cerradas.
  final int items;
  final int itemsCerrados;

  const TicketFuente({
    required this.id,
    required this.estado,
    this.inspeccionId,
    this.tipoInspeccion,
    this.centro,
    this.items = 0,
    this.itemsCerrados = 0,
  });
}

class HallazgoFuente {
  final String id;
  final String? centro;
  final String? empresa;
  final String? categoria;
  final String descripcion;
  final String criticidad;
  final String? estado;

  const HallazgoFuente({
    required this.id,
    required this.descripcion,
    required this.criticidad,
    this.centro,
    this.empresa,
    this.categoria,
    this.estado,
  });
}

class ContactoFuente {
  final String empresa;
  final String? actividad;
  final String? supervisor;
  final String? correo;
  final String? fono;

  const ContactoFuente({
    required this.empresa,
    this.actividad,
    this.supervisor,
    this.correo,
    this.fono,
  });
}

class FuentesCierre {
  final List<ActividadFuente> actividades;
  final List<AstFuente> asts;

  /// Tickets nacidos de las inspecciones del turno (observaciones).
  final List<TicketFuente> ticketsInformes;

  /// Tickets que el profesional creó en el período.
  final List<TicketFuente> ticketsCreados;

  /// Tickets que el profesional envió a revisión en el período.
  final List<TicketFuente> ticketsFinalizados;

  /// Tickets que hoy tiene tomados.
  final int aCargo;
  final List<HallazgoFuente> hallazgos;
  final List<ContactoFuente> contactos;

  const FuentesCierre({
    this.actividades = const [],
    this.asts = const [],
    this.ticketsInformes = const [],
    this.ticketsCreados = const [],
    this.ticketsFinalizados = const [],
    this.aCargo = 0,
    this.hallazgos = const [],
    this.contactos = const [],
  });
}

/// Tipos de `actividades.tipo_actividad` (mismos valores que la base).
abstract final class TipoActividad {
  static const buceo = 'INSPECCION_BUCEO';
  static const embarcacion = 'INSPECCION_EMBARCACION';
  static const formativa = 'ACTIVIDAD_FORMATIVA';
}

abstract final class TicketEstado {
  static const abierto = 'ABIERTO';
  static const tomado = 'TOMADO';
  static const parcial = 'PARCIAL';
  static const porRevisar = 'FINALIZADO_PENDIENTE_REVISION';
  static const cerrado = 'CERRADO';
}

abstract final class CierreCalculo {
  static String categoria(String tipo) => switch (tipo) {
    TipoActividad.buceo => 'Buceo',
    TipoActividad.embarcacion => 'Embarcación',
    TipoActividad.formativa => 'Act. formativa',
    'AST' => 'AST',
    _ => _humano(tipo),
  };

  static String _tituloFolio(String tipo) => switch (tipo) {
    TipoActividad.buceo => 'Reportes de buceo',
    TipoActividad.embarcacion => 'Insp. embarcaciones',
    TipoActividad.formativa => 'Act. formativas',
    'AST' => 'Reportes AST',
    _ => _humano(tipo),
  };

  static String _humano(String tipo) {
    final t = tipo.replaceAll('_', ' ').toLowerCase().trim();
    return t.isEmpty ? 'Otro' : t[0].toUpperCase() + t.substring(1);
  }

  static String _clave(String? s) => (s ?? '').trim().toLowerCase();

  static String _fecha(DateTime d) => TurnoFechas.larga(d);

  static String _n(int v) => v.toString();

  static ({Map<String, int?> numeros, Map<String, List<FilaCierre>> filas})
  calcular(FuentesCierre f) {
    final acts = [...f.actividades]..sort((a, b) => a.fecha.compareTo(b.fecha));
    int contar(String tipo) => acts.where((a) => a.tipo == tipo).length;

    // Observaciones = ítems de los tickets de cada inspección (decisión
    // 2026-11-25). Cerrada: el ítem subsanado o el ticket cerrado.
    final porInforme = <String, ({int tot, int cerr})>{};
    for (final t in f.ticketsInformes) {
      final id = t.inspeccionId;
      if (id == null) continue;
      final cerr = t.estado == TicketEstado.cerrado ? t.items : t.itemsCerrados;
      final prev = porInforme[id] ?? (tot: 0, cerr: 0);
      porInforme[id] = (tot: prev.tot + t.items, cerr: prev.cerr + cerr);
    }
    int obsDe(String tipo) => f.ticketsInformes
        .where((t) => t.tipoInspeccion == tipo)
        .fold(0, (s, t) => s + t.items);

    final suspendidas = acts
        .where((a) => (a.estadoFaena ?? '').toUpperCase() == 'SUSPENDIDA')
        .toList();

    final centros = <String>{
      for (final a in acts)
        if (_clave(a.centro).isNotEmpty) a.centro!.trim(),
      for (final a in f.asts)
        if (_clave(a.centro).isNotEmpty) a.centro!.trim(),
    };

    final numeros = <String, int?>{
      'n_centros': centros.length,
      'n_insp_buceo': contar(TipoActividad.buceo),
      'n_ast': f.asts.length,
      'n_insp_emb': contar(TipoActividad.embarcacion),
      'n_reg_act': contar(TipoActividad.formativa),
      'n_obs_buceo': obsDe(TipoActividad.buceo),
      'n_obs_emb': obsDe(TipoActividad.embarcacion),
      'n_faenas_suspendidas': suspendidas.length,
      ..._tickets(f),
    };

    return (
      numeros: numeros,
      filas: {
        'folios': _folios(acts, f.asts),
        'centros': _centros(acts, f.asts, porInforme),
        'suspensiones': [
          for (final a in suspendidas)
            {
              'centro': a.centro ?? '',
              'empresa': a.empresa ?? '',
              'categoria': categoria(a.tipo),
              'motivo': '',
              'fecha': _fecha(a.fecha),
              'estado': 'Suspendida',
            },
        ],
        'informes_pendientes': [
          for (final a in acts)
            if ((porInforme[a.id]?.tot ?? 0) > 0)
              {
                'tipo': [
                  categoria(a.tipo),
                  if (_clave(a.empresa).isNotEmpty) '(${a.empresa!.trim()})',
                ].join(' '),
                'numero': a.numero?.toString() ?? '',
                'cerradas': _n(porInforme[a.id]!.cerr),
                'pendientes': _n(
                  porInforme[a.id]!.tot - porInforme[a.id]!.cerr,
                ),
              },
        ],
        'hallazgos': _hallazgos(f.hallazgos),
        'servicios': _servicios(acts, f.asts, f.contactos),
        'puertos_cerrados': const [],
      },
    );
  }

  static List<FilaCierre> _folios(
    List<ActividadFuente> acts,
    List<AstFuente> asts,
  ) {
    final grupos = <String, List<int>>{};
    for (final a in acts) {
      if (a.numero != null) (grupos[a.tipo] ??= []).add(a.numero!);
    }
    for (final a in asts) {
      if (a.numero != null) (grupos['AST'] ??= []).add(a.numero!);
    }
    const orden = [
      TipoActividad.buceo,
      TipoActividad.embarcacion,
      'AST',
      TipoActividad.formativa,
    ];
    final tipos = [
      ...orden.where(grupos.containsKey),
      ...grupos.keys.where((k) => !orden.contains(k)).toList()..sort(),
    ];
    return [
      for (final t in tipos)
        {
          'tipo': _tituloFolio(t),
          'inicial': _n(grupos[t]!.reduce((a, b) => a < b ? a : b)),
          'final': _n(grupos[t]!.reduce((a, b) => a > b ? a : b)),
          'cantidad': _n(grupos[t]!.length),
          'nota': '',
        },
    ];
  }

  static List<FilaCierre> _centros(
    List<ActividadFuente> acts,
    List<AstFuente> asts,
    Map<String, ({int tot, int cerr})> porInforme,
  ) {
    final filas = <String, Map<String, int>>{};
    final nombres = <String, String>{};
    Map<String, int> fila(String? centro) {
      final k = _clave(centro);
      nombres[k] ??= centro?.trim() ?? '';
      return filas[k] ??= {
        'buceo': 0,
        'reg': 0,
        'emb': 0,
        'ast': 0,
        'obs_tot': 0,
        'obs_cerr': 0,
      };
    }

    for (final a in acts) {
      if (_clave(a.centro).isEmpty) continue;
      final f = fila(a.centro);
      switch (a.tipo) {
        case TipoActividad.buceo:
          f['buceo'] = f['buceo']! + 1;
        case TipoActividad.embarcacion:
          f['emb'] = f['emb']! + 1;
        case TipoActividad.formativa:
          f['reg'] = f['reg']! + 1;
      }
      final o = porInforme[a.id];
      if (o != null) {
        f['obs_tot'] = f['obs_tot']! + o.tot;
        f['obs_cerr'] = f['obs_cerr']! + o.cerr;
      }
    }
    for (final a in asts) {
      if (_clave(a.centro).isEmpty) continue;
      final f = fila(a.centro);
      f['ast'] = f['ast']! + 1;
    }
    final claves = filas.keys.toList()..sort();
    String cifra(int v) => v == 0 ? '' : _n(v);
    return [
      for (final k in claves)
        {
          'centro': nombres[k]!,
          'buceo': cifra(filas[k]!['buceo']!),
          'reg': cifra(filas[k]!['reg']!),
          'emb': cifra(filas[k]!['emb']!),
          'ast': cifra(filas[k]!['ast']!),
          'epp': '',
          'cil': '',
          'obs_tot': _n(filas[k]!['obs_tot']!),
          'obs_cerr': _n(filas[k]!['obs_cerr']!),
          'obs_pen': _n(filas[k]!['obs_tot']! - filas[k]!['obs_cerr']!),
        },
    ];
  }

  static List<FilaCierre> _hallazgos(List<HallazgoFuente> hallazgos) {
    final vistos = <String>{};
    return [
      for (final h in hallazgos)
        if (vistos.add(h.id))
          {
            'centro': h.centro ?? '',
            'empresa': h.empresa ?? '',
            'categoria': h.categoria == null ? '' : categoria(h.categoria!),
            'descripcion': h.descripcion,
            'criticidad': h.criticidad,
            'estado': switch (h.estado) {
              'ABIERTO' => 'Pendiente',
              'EN_SEGUIMIENTO' => 'En seguimiento',
              _ => h.estado ?? '',
            },
          },
    ];
  }

  static List<FilaCierre> _servicios(
    List<ActividadFuente> acts,
    List<AstFuente> asts,
    List<ContactoFuente> contactos,
  ) {
    final empresas = <String, String>{};
    for (final e in [
      ...acts.map((a) => a.empresa),
      ...asts.map((a) => a.empresa),
    ]) {
      final k = _clave(e);
      if (k.isNotEmpty) empresas[k] ??= e!.trim();
    }
    final porClave = {for (final c in contactos) _clave(c.empresa): c};
    String? ultimo(String k, String? Function(ActividadFuente) campo) {
      for (final a in acts.reversed) {
        final v = campo(a)?.trim();
        if (_clave(a.empresa) == k && v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final claves = empresas.keys.toList()..sort();
    return [
      for (final k in claves)
        {
          'empresa': empresas[k]!,
          'actividad': porClave[k]?.actividad ?? '',
          'supervisor':
              porClave[k]?.supervisor ?? ultimo(k, (a) => a.supervisor) ?? '',
          'correo': porClave[k]?.correo ?? ultimo(k, (a) => a.correo) ?? '',
          'fono': porClave[k]?.fono ?? '',
        },
    ];
  }

  /// Igual que "Tickets históricos por profesional" del dashboard, en el
  /// período: creó (generó el ticket) o cerró (lo envió a revisión y hoy está
  /// cerrado), y el estado actual de esos tickets.
  static Map<String, int> _tickets(FuentesCierre f) {
    final porId = <String, TicketFuente>{
      for (final t in [...f.ticketsCreados, ...f.ticketsFinalizados]) t.id: t,
    };
    final creo = {for (final t in f.ticketsCreados) t.id};
    final cerro = {
      for (final t in f.ticketsFinalizados)
        if (t.estado == TicketEstado.cerrado) t.id,
    };
    final suyos = {...creo, ...cerro}.map((id) => porId[id]!).toList();
    int estado(String e) => suyos.where((t) => t.estado == e).length;
    return {
      'tk_creados': creo.length,
      'tk_cerrados': cerro.length,
      'tk_solo_creo': creo.difference(cerro).length,
      'tk_creo_y_cerro': creo.intersection(cerro).length,
      'tk_solo_cerro': cerro.difference(creo).length,
      'tk_abiertos': estado(TicketEstado.abierto),
      'tk_tomados': estado(TicketEstado.tomado),
      'tk_parciales': estado(TicketEstado.parcial),
      'tk_por_revisar': estado(TicketEstado.porRevisar),
      'tk_estado_cerrados': estado(TicketEstado.cerrado),
      'tk_a_cargo': f.aCargo,
    };
  }
}
