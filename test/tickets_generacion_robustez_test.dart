// Tests de ROBUSTEZ del flujo de generación automática de tickets por
// hallazgos (TicketRepository.generarDesdeInspeccionPorHallazgos).
//
// A diferencia de tickets_reglas_test.dart (lógica pura), aquí se ejercita
// el flujo completo contra un backend PostgREST SIMULADO CON ESTADO
// (FakePostgrest): un http.BaseClient que mantiene "tablas" en memoria y
// entiende los filtros que usa el repositorio (eq, neq, in, is, contains,
// order, limit, maybeSingle/single, insert con return=representation).
//
// Filosofía: varios de estos tests están DISEÑADOS PARA FALLAR con el código
// actual. Cada fallo documenta un bug real detectado en producción
// (2026-08-21: tickets TCK-2026-0001 y -0005 aparecieron "de la nada" tras
// limpieza total, con salto de correlativo 0001 -> 0005 y actividades que
// nunca quedaron marcadas con tickets_generados_at).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jf_innova_app/features/tickets/data/repositories/ticket_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// BACKEND FAKE: mini PostgREST con estado en memoria
// ---------------------------------------------------------------------------

/// http.BaseClient que emula PostgREST con tablas en memoria.
/// Soporta inyección de fallos y un interceptor para simular carreras.
class FakePostgrest extends http.BaseClient {
  FakePostgrest({Map<String, List<Map<String, dynamic>>>? seed})
    : tables = {
        for (final e in (seed ?? {}).entries)
          e.key: e.value.map((r) => Map<String, dynamic>.from(r)).toList(),
      };

  final Map<String, List<Map<String, dynamic>>> tables;
  final List<String> callLog = [];

  /// Interceptor opcional: se llama ANTES de procesar la request. Si devuelve
  /// una respuesta, se usa tal cual (para inyectar errores 23505, carreras,
  /// etc.). Recibe método, tabla y body decodificado (null si no hay).
  FutureOr<http.Response?> Function(String method, String table, Object? body)?
  onRequest;

  static const _defaults = <String, Map<String, dynamic>>{
    'tickets': {
      'estado': 'ABIERTO',
      'eliminado': false,
      'rechazado': false,
      'campos_extra_json': <String, dynamic>{},
    },
    'nc_hallazgos': {'estado_hallazgo': 'ABIERTO'},
  };

  int countInserts(String table) =>
      callLog.where((e) => e.startsWith('POST $table')).length;

  List<Map<String, dynamic>> rows(String table) =>
      List.unmodifiable(tables[table] ?? const []);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();
    final table = request.url.pathSegments.last;
    final method = request.method;
    final body = bodyBytes.isNotEmpty
        ? jsonDecode(utf8.decode(bodyBytes))
        : null;
    callLog.add('$method $table ${request.url.query}');

    http.Response resp;
    final interceptada = await onRequest?.call(method, table, body);
    if (interceptada != null) {
      resp = interceptada;
    } else {
      resp = switch (method) {
        'GET' => _handleGet(table, request),
        'POST' => _handlePost(table, request, body),
        'PATCH' => _handlePatch(table, request, body as Map<String, dynamic>),
        'DELETE' => _handleDelete(table, request),
        _ => http.Response('{"message":"unsupported"}', 405),
      };
    }

    return http.StreamedResponse(
      Stream.value(resp.bodyBytes),
      resp.statusCode,
      headers: resp.headers,
      request: request,
      reasonPhrase: resp.reasonPhrase,
    );
  }

  http.Response errorResp(int status, String code, String message) {
    return http.Response(
      jsonEncode({'message': message, 'code': code, 'hint': null}),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  // --- GET con filtros eq/neq/in/is/contains + order/limit -----------------
  http.Response _handleGet(String table, http.BaseRequest request) {
    var rows = List<Map<String, dynamic>>.from(tables[table] ?? []);

    request.url.queryParameters.forEach((key, expr) {
      if (key == 'select' || key == 'order' || key == 'limit') return;
      rows = rows.where((row) => _matches(row, key, expr)).toList();
    });

    final order = request.url.queryParameters['order'];
    if (order != null) {
      final parts = order.split('.');
      final col = parts[0];
      final asc = parts.length < 2 || parts[1] != 'desc';
      rows.sort((a, b) {
        final av = a[col]?.toString() ?? '';
        final bv = b[col]?.toString() ?? '';
        return asc ? av.compareTo(bv) : bv.compareTo(av);
      });
    }

    final limit = request.url.queryParameters['limit'];
    if (limit != null) rows = rows.take(int.parse(limit)).toList();

    final wantsObject = (request.headers['accept'] ?? '').contains(
      'vnd.pgrst.object+json',
    );
    if (wantsObject) {
      if (rows.length != 1) {
        // PostgREST devuelve 406 + PGRST116; maybeSingle lo traduce a null
        // (0 filas) y single lanza PostgrestException.
        return errorResp(
          406,
          'PGRST116',
          rows.isEmpty
              ? 'The result contains 0 rows'
              : 'Cannot coerce the result to a single JSON object',
        );
      }
      return _json(rows.first);
    }
    return _json(rows);
  }

  bool _matches(Map<String, dynamic> row, String col, String expr) {
    if (expr.startsWith('eq.')) {
      return _norm(row[col]) == _norm(expr.substring(3));
    }
    if (expr.startsWith('neq.')) {
      return _norm(row[col]) != _norm(expr.substring(4));
    }
    if (expr.startsWith('in.(') && expr.endsWith(')')) {
      // PostgREST quotea los valores: in.("ABIERTO","EN_SEGUIMIENTO")
      final opciones = expr
          .substring(4, expr.length - 1)
          .split(',')
          .map((v) => _norm(v.replaceAll('"', '')))
          .toSet();
      return opciones.contains(_norm(row[col]));
    }
    if (expr == 'is.null') return row[col] == null;
    if (expr == 'not.null' || expr == 'is.not.null') return row[col] != null;
    if (expr.startsWith('cs.')) {
      final contenido = jsonDecode(expr.substring(3)) as Map<String, dynamic>;
      final valor = row[col];
      if (valor is! Map) return false;
      return contenido.entries.every((e) => valor[e.key] == e.value);
    }
    return true; // operador no soportado: no filtrar
  }

  Object? _norm(Object? v) {
    if (v == null) return null;
    if (v is String) {
      if (v == 'true') return true;
      if (v == 'false') return false;
      if (v == 'null') return null;
      return v;
    }
    return v;
  }

  // --- INSERT ---------------------------------------------------------------
  http.Response _handlePost(
    String table,
    http.BaseRequest request,
    Object? body,
  ) {
    final filasNuevas = <Map<String, dynamic>>[];
    final lista = body is List ? body : [body];
    for (final item in lista) {
      final row = Map<String, dynamic>.from(item as Map);
      _defaults[table]?.forEach((k, v) => row.putIfAbsent(k, () => v));
      tables.putIfAbsent(table, () => []).add(row);
      filasNuevas.add(row);
    }

    final prefer = request.headers['prefer'] ?? '';
    if (!prefer.contains('return=representation')) {
      return http.Response('', 201);
    }
    final wantsObject = (request.headers['accept'] ?? '').contains(
      'vnd.pgrst.object+json',
    );
    return _json(wantsObject ? filasNuevas.first : filasNuevas, status: 201);
  }

  // --- UPDATE ---------------------------------------------------------------
  http.Response _handlePatch(
    String table,
    http.BaseRequest request,
    Map<String, dynamic> cambios,
  ) {
    for (final row in tables[table] ?? <Map<String, dynamic>>[]) {
      var aplica = true;
      request.url.queryParameters.forEach((key, expr) {
        if (key == 'select' || key == 'order' || key == 'limit') return;
        if (!_matches(row, key, expr)) aplica = false;
      });
      if (aplica) row.addAll(cambios);
    }
    return http.Response('', 204);
  }

  // --- DELETE ---------------------------------------------------------------
  http.Response _handleDelete(String table, http.BaseRequest request) {
    tables[table]?.removeWhere((row) {
      var aplica = true;
      request.url.queryParameters.forEach((key, expr) {
        if (key == 'select' || key == 'order' || key == 'limit') return;
        if (!_matches(row, key, expr)) aplica = false;
      });
      return aplica;
    });
    return http.Response('', 204);
  }

  http.Response _json(Object? data, {int status = 200}) {
    return http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

// ---------------------------------------------------------------------------
// FIXTURES
// ---------------------------------------------------------------------------

const _empresa = 'empresa-1';
const _usuarioSync = 'usuario-que-sincroniza';
const _insp = 'insp-1';
const _item = 'item-1';
const _resp = 'resp-1';

Map<String, List<Map<String, dynamic>>> _seedBase({
  List<Map<String, dynamic>>? fotos,
}) {
  return {
    'actividades': [
      {
        'id': _insp,
        'tipo_actividad': 'INSPECCION_BUCEO',
        'numero_informe': '496',
        'centro_id': 'centro-1',
        'embarcacion_id': 'emb-1',
      },
    ],
    'centros': [
      {'id': 'centro-1', 'area_id': 'area-1'},
    ],
    'embarcaciones': [
      {'id': 'emb-1', 'contratista_id': 'cont-1'},
    ],
    'inspeccion_respuestas': [
      {
        'id': _resp,
        'actividad_id': _insp,
        'item_id': _item,
        'estado': 'NC',
        'observacion': 'No cuentan con escalera.',
        'criticidad_registrada': 'Moderado',
      },
    ],
    'formulario_items': [
      {
        'id': _item,
        'pregunta': 'Escalera en buen estado',
        'categoria': 'SEGURIDAD Y APOYO',
        'orden': 32,
      },
    ],
    'registro_fotografico': fotos ?? [],
  };
}

TicketRepository _repo(FakePostgrest db) => TicketRepository(
  client: SupabaseClient(
    'https://fake.supabase.co',
    'anon-key',
    httpClient: db,
  ),
);

void main() {
  group('generación automática por hallazgos — robustez', () {
    test('control: 1 NC crea hallazgo + ocurrencia + ticket + item', () async {
      final db = FakePostgrest(seed: _seedBase());
      final repo = _repo(db);

      final r = await repo.generarDesdeInspeccionPorHallazgos(
        inspeccionId: _insp,
        empresaId: _empresa,
        generadoPorId: _usuarioSync,
      );

      expect(r.creados, hasLength(1));
      expect(r.reutilizados, isEmpty);
      expect(db.rows('nc_hallazgos'), hasLength(1));
      expect(db.rows('nc_hallazgo_ocurrencias'), hasLength(1));
      expect(db.rows('tickets'), hasLength(1));
      expect(db.rows('ticket_items'), hasLength(1));
    });

    test(
      'reproceso (tickets_generados_at nunca marcado) no duplica nada',
      () async {
        final db = FakePostgrest(seed: _seedBase());
        final repo = _repo(db);

        await repo.generarDesdeInspeccionPorHallazgos(
          inspeccionId: _insp,
          empresaId: _empresa,
          generadoPorId: _usuarioSync,
        );
        // Segunda corrida (como si el sync reintentara por marca perdida).
        final r2 = await repo.generarDesdeInspeccionPorHallazgos(
          inspeccionId: _insp,
          empresaId: _empresa,
          generadoPorId: _usuarioSync,
        );

        expect(r2.creados, isEmpty, reason: 'no debe crear tickets de nuevo');
        expect(r2.reutilizados, hasLength(1));
        expect(db.rows('tickets'), hasLength(1));
        expect(db.rows('nc_hallazgos'), hasLength(1));
        expect(db.countInserts('tickets'), 1);
      },
    );

    test('BUG: fotos legacy con descripcion "General" (app vieja) NO deben '
        'gatillar un ticket FOTOS_OBSERVACION con texto basura', () async {
      // Datos subidos con la versión publicada vieja: fotos de galería
      // general quedaron con descripcion 'General' (placeholder no vacío).
      final db = FakePostgrest(
        seed: _seedBase(
          fotos: [
            {
              'id': 'foto-g1',
              'actividad_id': _insp,
              'inspeccion_respuesta_id': null,
              'descripcion': 'General',
              'foto_url': 'https://x/general1.jpg',
            },
            {
              'id': 'foto-g2',
              'actividad_id': _insp,
              'inspeccion_respuesta_id': null,
              'descripcion': 'General',
              'foto_url': 'https://x/general2.jpg',
            },
          ],
        ),
      );
      final repo = _repo(db);

      final r = await repo.generarDesdeInspeccionPorHallazgos(
        inspeccionId: _insp,
        empresaId: _empresa,
        generadoPorId: _usuarioSync,
      );

      final ticketsFotos = db
          .rows('tickets')
          .where(
            (t) =>
                (t['campos_extra_json'] as Map?)?['automatico_tipo'] ==
                'FOTOS_OBSERVACION',
          )
          .toList();
      expect(
        ticketsFotos,
        isEmpty,
        reason:
            'Las fotos de galería con placeholder "General" no son '
            'observaciones reales; generan un ticket basura con items '
            '"General" que confunde al usuario.',
      );
      expect(r.creados, hasLength(1), reason: 'solo el ticket del NC');
    });

    test('BUG: si falla el INSERT de ticket_items después de crear el ticket, '
        'no debe quedar ticket fantasma (rollback)', () async {
      final db = FakePostgrest(seed: _seedBase());
      db.onRequest = (method, table, body) {
        if (method == 'POST' && table == 'ticket_items') {
          return db.errorResp(
            400,
            '42703',
            'column ticket_items.categoria does not exist',
          );
        }
        return null;
      };
      final repo = _repo(db);

      await expectLater(
        repo.generarDesdeInspeccionPorHallazgos(
          inspeccionId: _insp,
          empresaId: _empresa,
          generadoPorId: _usuarioSync,
        ),
        throwsA(anything),
      );

      expect(
        db.rows('tickets'),
        isEmpty,
        reason:
            'Sin rollback queda un ticket con 0 items que además puede '
            'bloquear reintentos por índices únicos (bug 2026-07-06, '
            'TCK-2026-0003). El flujo nuevo por hallazgos perdió ese '
            'rollback.',
      );
    });

    test('BUG: si falla el ticket de FOTOS_OBSERVACION después de crear los '
        'tickets NC, no debe lanzarse excepción total (el sync nunca marca '
        'tickets_generados_at y reprocesa infinitamente)', () async {
      final db = FakePostgrest(
        seed: _seedBase(
          fotos: [
            {
              'id': 'foto-obs-1',
              'actividad_id': _insp,
              'inspeccion_respuesta_id': null,
              'descripcion': 'Observación real de terreno',
              'foto_url': 'https://x/obs1.jpg',
            },
          ],
        ),
      );
      // El ticket del NC (1er POST a tickets) funciona; el de fotos (2º)
      // choca con el índice único legacy re-creado fuera de orden.
      var postsTickets = 0;
      db.onRequest = (method, table, body) {
        if (method == 'POST' && table == 'tickets') {
          postsTickets++;
          if (postsTickets > 1) {
            return db.errorResp(
              409,
              '23505',
              'duplicate key value violates unique constraint '
                  '"uq_tickets_inspeccion_automatico"',
            );
          }
        }
        return null;
      };
      final repo = _repo(db);

      Object? error;
      TicketGeneracionResultado? resultado;
      try {
        resultado = await repo.generarDesdeInspeccionPorHallazgos(
          inspeccionId: _insp,
          empresaId: _empresa,
          generadoPorId: _usuarioSync,
        );
      } catch (e) {
        error = e;
      }

      expect(
        error,
        isNull,
        reason:
            'El ticket NC ya se creó bien; que el ticket de fotos falle no '
            'debería tumbar toda la operación. Hoy la excepción escapa y el '
            'sync no marca tickets_generados_at -> reproceso infinito y '
            'consumo de correlativo en cada reintento (salto 0001 -> 0005 '
            'observado en producción).',
      );
      expect(resultado!.creados, hasLength(1));
    });

    test(
      'BUG: un 23505 del índice de hallazgo/fotos no debe reportarse como '
      '"índice antiguo de 1 ticket por inspección" (mensaje engañoso)',
      () async {
        final db = FakePostgrest(seed: _seedBase());
        db.onRequest = (method, table, body) {
          if (method == 'POST' && table == 'tickets') {
            return db.errorResp(
              409,
              '23505',
              'duplicate key value violates unique constraint '
                  '"uq_tickets_hallazgo_activo"',
            );
          }
          return null;
        };
        final repo = _repo(db);

        Object? error;
        try {
          await repo.generarDesdeInspeccionPorHallazgos(
            inspeccionId: _insp,
            empresaId: _empresa,
            generadoPorId: _usuarioSync,
          );
        } catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        final msg = error.toString();
        expect(
          msg.contains('uq_tickets_inspeccion_automatico') ||
              msg.toLowerCase().contains('índice antiguo'),
          isFalse,
          reason:
              'El catch clasifica CUALQUIER 23505 como "índice legacy por '
              'inspección" y pide borrar un índice que quizás no existe. El '
              'constraint real fue uq_tickets_hallazgo_activo (carrera entre '
              'dos syncs).',
        );
      },
    );

    test(
      'BUG: carrera de doble sync — si otro proceso crea el ticket del '
      'hallazgo entre el SELECT y el INSERT, debe reutilizarlo, no explotar',
      () async {
        final db = FakePostgrest(seed: _seedBase());
        // Simula: el SELECT de ticket activo devuelve vacío, pero al INSERTar
        // otro proceso ya lo creó (23505 en uq_tickets_hallazgo_activo) y la
        // fila "del otro" ya existe en la tabla.
        var primerPostTickets = true;
        db.onRequest = (method, table, body) {
          if (method == 'POST' && table == 'tickets' && primerPostTickets) {
            primerPostTickets = false;
            final hallazgo = db.rows('nc_hallazgos').first;
            db.tables.putIfAbsent('tickets', () => []).add({
              'id': 'ticket-del-otro-proceso',
              'empresa_id': _empresa,
              'origen': 'INSPECCION',
              'tipo_ticket': 'REVISION_OBSERVACIONES',
              'inspeccion_id': _insp,
              'hallazgo_id': hallazgo['id'],
              'estado': 'ABIERTO',
              'eliminado': false,
              'rechazado': false,
              'campos_extra_json': <String, dynamic>{},
              'generado_por_id': 'otro-usuario',
            });
            return db.errorResp(
              409,
              '23505',
              'duplicate key value violates unique constraint '
                  '"uq_tickets_hallazgo_activo"',
            );
          }
          return null;
        };
        final repo = _repo(db);

        Object? error;
        TicketGeneracionResultado? resultado;
        try {
          resultado = await repo.generarDesdeInspeccionPorHallazgos(
            inspeccionId: _insp,
            empresaId: _empresa,
            generadoPorId: _usuarioSync,
          );
        } catch (e) {
          error = e;
        }

        expect(
          error,
          isNull,
          reason:
              'En carrera, el perdedor debería re-leer el ticket ganador y '
              'reportarlo como reutilizado en vez de lanzar error.',
        );
        expect(resultado, isNotNull);
        expect(db.rows('tickets'), hasLength(1));
        expect(resultado!.reutilizados.single.id, 'ticket-del-otro-proceso');
      },
    );

    test(
      'control: error de esquema no relacionado (23502 NOT NULL) no entra al '
      'flujo legacy ni se disfraza',
      () async {
        final db = FakePostgrest(seed: _seedBase());
        db.onRequest = (method, table, body) {
          if (method == 'POST' && table == 'tickets') {
            return db.errorResp(
              400,
              '23502',
              'null value in column "motivo" violates not-null constraint',
            );
          }
          return null;
        };
        final repo = _repo(db);

        Object? error;
        try {
          await repo.generarDesdeInspeccionPorHallazgos(
            inspeccionId: _insp,
            empresaId: _empresa,
            generadoPorId: _usuarioSync,
          );
        } catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        expect(
          error.toString(),
          contains('23502'),
          reason: 'errores desconocidos deben propagarse tal cual',
        );
      },
    );

    test('control: inspección 100% cumplimiento sin fotos con observación no '
        'genera nada', () async {
      final seed = _seedBase();
      seed['inspeccion_respuestas'] = []; // sin NC
      final db = FakePostgrest(seed: seed);
      final repo = _repo(db);

      final r = await repo.generarDesdeInspeccionPorHallazgos(
        inspeccionId: _insp,
        empresaId: _empresa,
        generadoPorId: _usuarioSync,
      );

      expect(r.totalTicketsInvolucrados, 0);
      expect(db.rows('tickets'), isEmpty);
      expect(db.rows('nc_hallazgos'), isEmpty);
    });

    test('BUG: el flujo legacy no debe crear un ticket VACÍO cuando no hay '
        'nada que subsanar (TCK-2026-0001 en produccion: ABIERTO, 0 items, '
        'sin hallazgo_id)', () async {
      // Escenario real: el core falla con un error que "parece schema
      // incompleto" y cae al flujo legacy. Si en ese momento la inspección no
      // tiene NC ni fotos con observación (p.ej. las respuestas aún no
      // sincronizaron), _armarItemsDesdeInspeccion devuelve [] y el legacy
      // dejaba el ticket recién insertado sin ningún ítem y sin rollback,
      // quemando además un correlativo TCK-2026-XXXX.
      final seed = _seedBase();
      seed['inspeccion_respuestas'] = [];
      final db = FakePostgrest(seed: seed);

      var fallosPendientes = 1;
      db.onRequest = (method, table, body) {
        if (method == 'GET' &&
            table == 'embarcaciones' &&
            fallosPendientes > 0) {
          fallosPendientes--;
          return db.errorResp(
            400,
            '42703',
            'column tickets.hallazgo_id does not exist',
          );
        }
        return null;
      };
      final repo = _repo(db);

      final r = await repo.generarDesdeInspeccionPorHallazgos(
        inspeccionId: _insp,
        empresaId: _empresa,
        generadoPorId: _usuarioSync,
      );

      expect(
        db.rows('tickets'),
        isEmpty,
        reason:
            'Un ticket sin ítems no se puede tomar ni subsanar: queda '
            'ABIERTO para siempre y consume un correlativo.',
      );
      expect(db.rows('ticket_items'), isEmpty);
      expect(
        r.totalTicketsInvolucrados,
        0,
        reason:
            'Debe terminar OK y sin tickets: si lanzara excepción, el sync '
            'nunca marca tickets_generados_at y reprocesa en cada corrida.',
      );
    });

    test(
      'el flujo legacy SÍ crea el ticket cuando hay algo que subsanar',
      () async {
        final db = FakePostgrest(seed: _seedBase());

        var fallosPendientes = 1;
        db.onRequest = (method, table, body) {
          if (method == 'GET' &&
              table == 'embarcaciones' &&
              fallosPendientes > 0) {
            fallosPendientes--;
            return db.errorResp(
              400,
              '42703',
              'column tickets.hallazgo_id does not exist',
            );
          }
          return null;
        };
        final repo = _repo(db);

        final r = await repo.generarDesdeInspeccionPorHallazgos(
          inspeccionId: _insp,
          empresaId: _empresa,
          generadoPorId: _usuarioSync,
        );

        expect(r.creados, hasLength(1));
        expect(db.rows('tickets'), hasLength(1));
        expect(db.rows('ticket_items'), isNotEmpty);
      },
    );
  });
}
