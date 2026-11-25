import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/user_session.dart';
import '../data/local_turno_cierre_repository.dart';
import '../domain/turno.dart';
import '../domain/turno_cierre.dart';
import '../domain/turno_cierre_calculo.dart';
import 'turno_cierre_pdf_service.dart';

/// Payload de Supabase: sin columnas solo locales y con las secciones como
/// listas (JSONB).
Map<String, dynamic> cierrePayloadSupabase(Map<String, dynamic> row) {
  final p = Map<String, dynamic>.from(row)
    ..remove('subido')
    ..remove('eliminado')
    ..remove('pdf_path_local');
  for (final s in CierreCampos.secciones) {
    p[s.clave] = TurnoCierre.filasDesde(row[s.clave]);
  }
  return p;
}

/// Fila local a partir de una de Supabase (ya subida).
Map<String, dynamic> cierreRowDesdeSupabase(Map<String, dynamic> r) {
  final c = TurnoCierre.fromRow(r);
  return {...c.toRow(), 'subido': 1, 'eliminado': 0};
}

/// Lee de Supabase lo que el auditor hizo en el turno, arma el cierre, lo
/// guarda y genera el PDF. Necesita conexión (los tickets son solo online).
class TurnoCierreService {
  final SupabaseClient _sb;
  final LocalTurnoCierreRepository _repo;

  TurnoCierreService({
    SupabaseClient? supabase,
    LocalTurnoCierreRepository? repo,
  }) : _sb = supabase ?? Supabase.instance.client,
       _repo = repo ?? LocalTurnoCierreRepository();

  static const _bucket = 'pdfs_visitas';

  /// Período por defecto: del ingreso a la salida confirmada (o hasta hoy si
  /// el turno sigue activo).
  static ({DateTime desde, DateTime hasta}) periodo(Turno t, DateTime hoy) {
    final hasta = t.egresoFecha ?? hoy;
    return (
      desde: t.ingresoFecha,
      hasta: hasta.isBefore(t.ingresoFecha) ? t.ingresoFecha : hasta,
    );
  }

  /// Cierre nuevo con los datos automáticos (sin guardar).
  Future<TurnoCierre> nuevo(
    Turno t, {
    required DateTime hoy,
    String? appVersion,
  }) async {
    final p = periodo(t, hoy);
    final calc = CierreCalculo.calcular(
      await leerFuentes(
        usuarioId: t.usuarioId,
        empresaId: t.empresaId,
        desde: p.desde,
        hasta: p.hasta,
      ),
    );
    final ahora = DateTime.now();
    return TurnoCierre(
      id: const Uuid().v4(),
      turnoId: t.id,
      usuarioId: t.usuarioId,
      empresaId: t.empresaId,
      areaId: t.areaId,
      desde: p.desde,
      hasta: p.hasta,
      estado: CierreEstado.borrador,
      numeros: calc.numeros,
      filas: calc.filas,
      bitacora: null,
      pdfUrl: null,
      pdfVersion: null,
      pdfGeneradoAt: null,
      pdfPathLocal: null,
      appVersion: appVersion,
      createdAt: ahora,
      updatedAt: ahora,
    );
  }

  /// Vuelve a calcular lo automático con el período del cierre. Conserva lo
  /// que solo llena el auditor: puertos cerrados, bitácora, notas de folios
  /// y EPP/Cil. por centro.
  Future<TurnoCierre> recalcular(TurnoCierre c) async {
    final calc = CierreCalculo.calcular(
      await leerFuentes(
        usuarioId: c.usuarioId,
        empresaId: c.empresaId,
        desde: c.desde,
        hasta: c.hasta,
      ),
    );
    final filas = Map<String, List<FilaCierre>>.from(calc.filas);
    filas['puertos_cerrados'] = c.filasDe('puertos_cerrados');
    filas['folios'] = _conservar(
      filas['folios']!,
      c.filasDe('folios'),
      'tipo',
      ['nota'],
    );
    filas['centros'] = _conservar(
      filas['centros']!,
      c.filasDe('centros'),
      'centro',
      ['epp', 'cil'],
    );
    return c.copyWith(
      numeros: calc.numeros,
      filas: filas,
      updatedAt: DateTime.now(),
    );
  }

  static List<FilaCierre> _conservar(
    List<FilaCierre> nuevas,
    List<FilaCierre> antes,
    String clave,
    List<String> campos,
  ) {
    final previas = {for (final f in antes) (f[clave] ?? '').toLowerCase(): f};
    return [
      for (final f in nuevas)
        {
          ...f,
          for (final c in campos)
            if ((previas[(f[clave] ?? '').toLowerCase()]?[c] ?? '').isNotEmpty)
              c: previas[(f[clave] ?? '').toLowerCase()]![c]!,
        },
    ];
  }

  // ── Lectura de Supabase ──────────────────────────────────────────────────

  static int? _numeroFinal(Object? v) {
    final m = RegExp(r'(\d+)\D*$').firstMatch(v?.toString() ?? '');
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  Future<Map<String, String>> _nombres(String tabla, Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _sb
        .from(tabla)
        .select('id, nombre')
        .inFilter('id', ids.toList());
    return {for (final r in rows) r['id'].toString(): '${r['nombre'] ?? ''}'};
  }

  Future<FuentesCierre> leerFuentes({
    required String usuarioId,
    required String? empresaId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    // actividades.fecha_realizacion es timestamp sin zona con la hora local
    // del celular: se filtra con la fecha tal cual. AST y tickets son
    // timestamptz: se filtra con la medianoche local pasada a UTC (si no, en
    // Chile se pierden los de la noche del último día).
    final d = TurnoFechas.aTexto(desde);
    final h = TurnoFechas.aTexto(TurnoFechas.sumar(hasta, 1));
    final dz = TurnoFechas.dia(desde).toUtc().toIso8601String();
    final hz = TurnoFechas.sumar(hasta, 1).toUtc().toIso8601String();

    final acts = List<Map<String, dynamic>>.from(
      await _sb
          .from('actividades')
          .select(
            'id, tipo_actividad, numero_informe, fecha_realizacion, '
            'estado_faena, centro_id, contratista_id',
          )
          .eq('usuario_id', usuarioId)
          .gte('fecha_realizacion', d)
          .lt('fecha_realizacion', h)
          .not('numero_informe', 'is', null),
    );
    final astRows = List<Map<String, dynamic>>.from(
      await _sb
          .from('ast_informes')
          .select(
            'id, correlativo, fecha_realizacion, centro_nombre, '
            'contratista_nombre',
          )
          .eq('usuario_id', usuarioId)
          .gte('fecha_realizacion', dz)
          .lt('fecha_realizacion', hz)
          .not('correlativo', 'is', null),
    );
    final actIds = [for (final a in acts) a['id'].toString()];

    final r = await (
      _nombres('centros', {
        for (final a in acts)
          if (a['centro_id'] != null) a['centro_id'].toString(),
      }),
      _nombres('contratistas', {
        for (final a in acts)
          if (a['contratista_id'] != null) a['contratista_id'].toString(),
      }),
      _porActividad('verificaciones_buceo', 'supervisor_nombre', actIds),
      _porActividad('verificaciones_embarcacion', 'correo_empresa', actIds),
      _ticketsDeInformes(actIds),
      _ticketsProfesional(usuarioId, dz, hz),
      _hallazgos(actIds),
      _contactos(empresaId),
    ).wait;
    final centros = r.$1, contratistas = r.$2;
    final actividades = [
      for (final a in acts)
        ActividadFuente(
          id: a['id'].toString(),
          tipo: a['tipo_actividad']?.toString() ?? '',
          numero: _numeroFinal(a['numero_informe']),
          fecha: DateTime.parse(a['fecha_realizacion'].toString()).toLocal(),
          centro: centros[a['centro_id']?.toString()],
          empresa: contratistas[a['contratista_id']?.toString()],
          estadoFaena: a['estado_faena']?.toString(),
          supervisor: r.$3[a['id'].toString()],
          correo: r.$4[a['id'].toString()],
        ),
    ];
    final asts = [
      for (final a in astRows)
        AstFuente(
          id: a['id'].toString(),
          numero: _numeroFinal(a['correlativo']),
          fecha: DateTime.parse(a['fecha_realizacion'].toString()).toLocal(),
          centro: a['centro_nombre']?.toString(),
          empresa: a['contratista_nombre']?.toString(),
        ),
    ];
    final ticketsInformes = [
      for (final t in r.$5)
        TicketFuente(
          id: t.id,
          estado: t.estado,
          inspeccionId: t.inspeccionId,
          tipoInspeccion: t.tipoInspeccion,
          items: t.items,
          itemsCerrados: t.itemsCerrados,
        ),
    ];
    return FuentesCierre(
      actividades: actividades,
      asts: asts,
      ticketsInformes: ticketsInformes,
      ticketsCreados: r.$6.creados,
      ticketsFinalizados: r.$6.finalizados,
      aCargo: r.$6.aCargo,
      hallazgos: r.$7,
      contactos: r.$8,
    );
  }

  Future<Map<String, String>> _porActividad(
    String tabla,
    String columna,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await _sb
          .from(tabla)
          .select('actividad_id, $columna')
          .inFilter('actividad_id', ids);
      return {
        for (final r in rows)
          if ((r[columna]?.toString().trim() ?? '').isNotEmpty)
            r['actividad_id'].toString(): r[columna].toString().trim(),
      };
    } catch (e) {
      debugPrint('⚠️ Cierre: no se pudo leer $tabla: $e');
      return {};
    }
  }

  Future<List<TicketFuente>> _ticketsDeInformes(List<String> actIds) async {
    if (actIds.isEmpty) return [];
    final tickets = List<Map<String, dynamic>>.from(
      await _sb
          .from('tickets')
          .select('id, inspeccion_id, tipo_inspeccion, estado')
          .inFilter('inspeccion_id', actIds)
          .or('eliminado.is.null,eliminado.eq.false'),
    );
    final ids = [for (final t in tickets) t['id'].toString()];
    final items = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _sb
                .from('ticket_items')
                .select('ticket_id, subsanado')
                .inFilter('ticket_id', ids),
          );
    return [
      for (final t in tickets)
        TicketFuente(
          id: t['id'].toString(),
          inspeccionId: t['inspeccion_id']?.toString(),
          tipoInspeccion: t['tipo_inspeccion']?.toString(),
          estado: t['estado']?.toString() ?? '',
          items: items.where((i) => i['ticket_id'] == t['id']).length,
          itemsCerrados: items
              .where((i) => i['ticket_id'] == t['id'] && i['subsanado'] == true)
              .length,
        ),
    ];
  }

  Future<
    ({List<TicketFuente> creados, List<TicketFuente> finalizados, int aCargo})
  >
  _ticketsProfesional(String uid, String d, String h) async {
    TicketFuente fuente(Map<String, dynamic> t) =>
        TicketFuente(id: t['id'].toString(), estado: '${t['estado'] ?? ''}');
    final creados = await _sb
        .from('tickets')
        .select('id, estado')
        .eq('generado_por_id', uid)
        .gte('created_at', d)
        .lt('created_at', h)
        .or('eliminado.is.null,eliminado.eq.false');
    final acciones = await _sb
        .from('ticket_historial_tomas')
        .select('ticket_id')
        .eq('usuario_id', uid)
        .eq('accion', 'FINALIZADO')
        .gte('created_at', d)
        .lt('created_at', h);
    final idsFin = {for (final a in acciones) a['ticket_id'].toString()};
    final finalizados = idsFin.isEmpty
        ? const []
        : await _sb
              .from('tickets')
              .select('id, estado')
              .inFilter('id', idsFin.toList());
    final aCargo = await _sb
        .from('tickets')
        .select('id')
        .eq('tomado_por_id', uid)
        .eq('estado', TicketEstado.tomado)
        .or('eliminado.is.null,eliminado.eq.false');
    return (
      creados: [for (final t in creados) fuente(t)],
      finalizados: [for (final t in finalizados) fuente(t)],
      aCargo: aCargo.length,
    );
  }

  Future<List<HallazgoFuente>> _hallazgos(List<String> actIds) async {
    if (actIds.isEmpty) return [];
    try {
      final ocurr = List<Map<String, dynamic>>.from(
        await _sb
            .from('nc_hallazgo_ocurrencias')
            .select('hallazgo_id, centro_id, contratista_id, observacion')
            .inFilter('informe_id', actIds),
      );
      final idsH = {for (final o in ocurr) o['hallazgo_id'].toString()};
      if (idsH.isEmpty) return [];
      final hallazgos = List<Map<String, dynamic>>.from(
        await _sb
            .from('nc_hallazgos')
            .select(
              'id, criticidad_actual, estado_hallazgo, tipo_actividad, item_id',
            )
            .inFilter('id', idsH.toList())
            .eq('criticidad_actual', 'Intolerable'),
      );
      if (hallazgos.isEmpty) return [];
      final r = await (
        _sb.from('formulario_items').select('id, pregunta').inFilter('id', [
          for (final h in hallazgos)
            if (h['item_id'] != null) h['item_id'].toString(),
        ]),
        _nombres('centros', {
          for (final o in ocurr)
            if (o['centro_id'] != null) o['centro_id'].toString(),
        }),
        _nombres('contratistas', {
          for (final o in ocurr)
            if (o['contratista_id'] != null) o['contratista_id'].toString(),
        }),
      ).wait;
      final preguntas = {
        for (final i in r.$1) i['id'].toString(): '${i['pregunta'] ?? ''}',
      };
      return [
        for (final h in hallazgos)
          for (final o
              in ocurr.where((o) => o['hallazgo_id'] == h['id']).take(1))
            HallazgoFuente(
              id: h['id'].toString(),
              centro: r.$2[o['centro_id']?.toString()],
              empresa: r.$3[o['contratista_id']?.toString()],
              categoria: h['tipo_actividad']?.toString(),
              descripcion: [
                preguntas[h['item_id']?.toString()] ?? '',
                o['observacion']?.toString().trim() ?? '',
              ].where((s) => s.isNotEmpty).join(' · '),
              criticidad: h['criticidad_actual']?.toString() ?? '',
              estado: h['estado_hallazgo']?.toString(),
            ),
      ];
    } catch (e) {
      debugPrint('⚠️ Cierre: no se pudieron leer los hallazgos: $e');
      return [];
    }
  }

  Future<List<ContactoFuente>> _contactos(String? empresaId) async {
    if (empresaId == null || empresaId.isEmpty) return [];
    try {
      final rows = await _sb
          .from('contratista_contactos')
          .select('contratista_nombre, actividad, supervisor, correo, fono')
          .eq('empresa_id', empresaId);
      String? t(Object? v) {
        final s = v?.toString().trim();
        return (s == null || s.isEmpty) ? null : s;
      }

      return [
        for (final r in rows)
          ContactoFuente(
            empresa: r['contratista_nombre'].toString(),
            actividad: t(r['actividad']),
            supervisor: t(r['supervisor']),
            correo: t(r['correo']),
            fono: t(r['fono']),
          ),
      ];
    } catch (e) {
      // Sin la tabla (migración v3 pendiente) el directorio sale sin contactos.
      debugPrint('⚠️ Cierre: no se pudo leer contratista_contactos: $e');
      return [];
    }
  }

  // ── Guardar, subir y PDF ─────────────────────────────────────────────────

  Future<void> guardarLocal(TurnoCierre c) => _repo.guardar(c);

  /// Sube el cierre y devuelve el que quedó (puede cambiar de id si otro
  /// celular ya subió un cierre del mismo turno). Null si falló: queda
  /// pendiente y lo reintenta el sync.
  Future<TurnoCierre?> subir(TurnoCierre c, {bool reintento = false}) async {
    try {
      final payload = cierrePayloadSupabase(c.toRow());
      payload['empresa_id'] ??= UserSession().empresaId;
      await _sb.from('turno_cierres').upsert(payload, onConflict: 'id');
      // Solo si nadie lo cambió mientras subía (si no, queda pendiente).
      await _repo.marcarSubido(c.id, c.toRow()['updated_at'] as String);
      return c.copyWith(subido: true);
    } on PostgrestException catch (e, st) {
      if (e.code == '23505' && !reintento) {
        final remoto = await _sb
            .from('turno_cierres')
            .select('id')
            .eq('turno_id', c.turnoId)
            .maybeSingle();
        final idRemoto = remoto?['id']?.toString();
        if (idRemoto != null && idRemoto != c.id) {
          await _repo.cambiarId(c.id, idRemoto);
          return subir(
            TurnoCierre.fromRow({...c.toRow(), 'id': idRemoto}),
            reintento: true,
          );
        }
      }
      debugPrint('⚠️ Cierre ${c.id} sin subir: $e');
      _reportar(e, st, 'TurnoCierre subir');
      return null;
    } catch (e, st) {
      debugPrint('⚠️ Cierre ${c.id} sin subir: $e');
      _reportar(e, st, 'TurnoCierre subir');
      return null;
    }
  }

  /// El cierre de este turno que ya está en Supabase (otro celular o una
  /// reinstalación). Lo guarda en el teléfono. Null si no hay o sin señal.
  Future<TurnoCierre?> descargarDeTurno(String turnoId) async {
    try {
      final r = await _sb
          .from('turno_cierres')
          .select()
          .eq('turno_id', turnoId)
          .maybeSingle();
      if (r == null) return null;
      final c = TurnoCierre.fromRow(cierreRowDesdeSupabase(r));
      await _repo.guardar(c, subido: true);
      return c;
    } catch (e) {
      debugPrint('⚠️ Cierre remoto del turno $turnoId: $e');
      return null;
    }
  }

  /// Guarda los contactos corregidos del directorio para la empresa.
  Future<void> guardarContactos(TurnoCierre c, String usuarioId) async {
    final empresaId = c.empresaId;
    if (empresaId == null || empresaId.isEmpty) return;
    // Una fila por contratista: dos con el mismo nombre (mayúsculas o
    // espacios) harían fallar todo el upsert.
    final vistos = <String>{};
    final filas = [
      for (final f in c.filasDe('servicios'))
        if (vistos.add((f['empresa'] ?? '').trim().toLowerCase()))
          if ((f['empresa'] ?? '').trim().isNotEmpty &&
              [
                'actividad',
                'supervisor',
                'correo',
                'fono',
              ].any((k) => (f[k] ?? '').trim().isNotEmpty))
            {
              'empresa_id': empresaId,
              'contratista_nombre': f['empresa']!.trim(),
              'actividad': _vacioANull(f['actividad']),
              'supervisor': _vacioANull(f['supervisor']),
              'correo': _vacioANull(f['correo']),
              'fono': _vacioANull(f['fono']),
              'actualizado_por': usuarioId,
            },
    ];
    if (filas.isEmpty) return;
    try {
      await _sb
          .from('contratista_contactos')
          .upsert(filas, onConflict: 'empresa_id,contratista_clave');
    } catch (e, st) {
      debugPrint('⚠️ No se guardaron los contactos: $e');
      _reportar(e, st, 'TurnoCierre contactos');
    }
  }

  static String? _vacioANull(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Genera el PDF, lo sube y deja el cierre como GENERADO.
  Future<TurnoCierre> generarPdf(
    TurnoCierre c, {
    required String profesional,
    required String area,
  }) async {
    final bytes = await const TurnoCierrePdfService().generar(
      TurnoCierrePdfData(cierre: c, profesional: profesional, area: area),
    );
    String? local;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      local = '${dir.path}/cierre_turno_${c.id}.pdf';
      await File(local).writeAsBytes(bytes, flush: true);
    }
    final ruta = 'turnos/${c.turnoId}/CierreTurno_${c.id}.pdf';
    await _sb.storage
        .from(_bucket)
        .uploadBinary(
          ruta,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/pdf',
          ),
        );
    // Con la hora en la URL el visor no muestra un PDF anterior en caché.
    final url =
        '${_sb.storage.from(_bucket).getPublicUrl(ruta)}'
        '?v=${DateTime.now().millisecondsSinceEpoch}';
    final generado = c.copyWith(
      estado: CierreEstado.generado,
      pdfUrl: url,
      pdfVersion: kTurnoCierrePdfVersion,
      pdfGeneradoAt: DateTime.now(),
      pdfPathLocal: local,
      updatedAt: DateTime.now(),
    );
    await _repo.guardar(generado);
    return await subir(generado) ?? generado;
  }

  void _reportar(Object e, StackTrace st, String reason) {
    try {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: reason,
        fatal: false,
      );
    } catch (_) {}
  }
}
