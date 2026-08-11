import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/ticket_model.dart';
import '../../domain/models/ticket_item_model.dart';
import '../../domain/models/ticket_historial_entry.dart';
import '../../domain/models/ticket_notificacion_model.dart';

/// Se lanza cuando una acción de ciclo de vida no pudo aplicarse porque el
/// ticket ya cambió de estado en el servidor (ej: alguien más lo tomó primero).
class TicketAccionFallidaException implements Exception {
  final String mensaje;
  TicketAccionFallidaException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Resultado agregado de la generación automática por hallazgos únicos.
class TicketGeneracionResultado {
  final List<TicketModel> creados;
  final List<TicketModel> reutilizados;
  final int respuestasNcProcesadas;

  const TicketGeneracionResultado({
    required this.creados,
    required this.reutilizados,
    required this.respuestasNcProcesadas,
  });

  int get totalTicketsInvolucrados => creados.length + reutilizados.length;
}

class TicketGeneracionPreviewItem {
  final String itemId;
  final String pregunta;
  final String? categoria;
  final int? numeroPregunta;
  final String? observacion;
  final String? hallazgoId;
  final TicketModel? ticketActivoExistente;

  const TicketGeneracionPreviewItem({
    required this.itemId,
    required this.pregunta,
    this.categoria,
    this.numeroPregunta,
    this.observacion,
    this.hallazgoId,
    this.ticketActivoExistente,
  });

  bool get seCrearaTicket => ticketActivoExistente == null;
}

class TicketGeneracionPreview {
  final List<TicketGeneracionPreviewItem> hallazgos;
  final int cantidadNoCumple;
  final int cantidadFotosConObservacion;
  final bool usaFlujoLegacySinNc;

  const TicketGeneracionPreview({
    required this.hallazgos,
    required this.cantidadNoCumple,
    required this.cantidadFotosConObservacion,
    required this.usaFlujoLegacySinNc,
  });

  int get ticketsNuevos =>
      hallazgos.where((hallazgo) => hallazgo.seCrearaTicket).length;

  int get ticketsReutilizados =>
      hallazgos.where((hallazgo) => !hallazgo.seCrearaTicket).length;
}

/// Repositorio 100% online del módulo de Tickets (ver docs/PLAN_TICKETS_MVP.md).
/// No existen tablas `_pendientes` en SQLite: todo se lee/escribe directo en
/// Supabase. La visibilidad por empresa/admin la aplica RLS en el servidor.
class TicketRepository {
  final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------------
  // LECTURA
  // ---------------------------------------------------------------------

  Future<List<TicketModel>> getTickets({
    String? estado,
    String? tipoTicket,
    String? tipoInspeccion,
    String? centroId,
    String? embarcacionId,
    String? areaId,
    String? contratistaId,
  }) async {
    var query = _client.from('tickets').select().eq('eliminado', false);

    if (estado != null) query = query.eq('estado', estado);
    if (tipoTicket != null) query = query.eq('tipo_ticket', tipoTicket);
    if (tipoInspeccion != null) {
      query = query.eq('tipo_inspeccion', tipoInspeccion);
    }
    if (centroId != null) query = query.eq('centro_id', centroId);
    if (embarcacionId != null) {
      query = query.eq('embarcacion_id', embarcacionId);
    }
    if (areaId != null) query = query.eq('area_id', areaId);
    if (contratistaId != null) {
      query = query.eq('contratista_id', contratistaId);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => TicketModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<TicketModel?> getTicketById(String id) async {
    final row = await _client
        .from('tickets')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return TicketModel.fromMap(row);
  }

  Future<String?> getPdfUrlInspeccion(String inspeccionId) async {
    final row = await _client
        .from('actividades')
        .select('pdf_url')
        .eq('id', inspeccionId)
        .maybeSingle();
    return row?['pdf_url'] as String?;
  }

  /// Ticket automático ya existente para una inspección (si lo hay). Ignora
  /// los tickets eliminados (borrado lógico): si el único ticket automático
  /// previo fue eliminado, se debe poder generar uno nuevo.
  Future<TicketModel?> getTicketAutomaticoDeInspeccion(
    String inspeccionId,
  ) async {
    final row = await _client
        .from('tickets')
        .select()
        .eq('inspeccion_id', inspeccionId)
        .eq('origen', TicketOrigen.inspeccion.value)
        .eq('eliminado', false)
        .maybeSingle();
    if (row == null) return null;
    return TicketModel.fromMap(row);
  }

  Future<List<TicketItemModel>> getItems(String ticketId) async {
    final rows = await _client
        .from('ticket_items')
        .select()
        .eq('ticket_id', ticketId)
        .order('orden');
    return (rows as List)
        .map((e) => TicketItemModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TicketHistorialEntry>> getHistorial(String ticketId) async {
    final rows = await _client
        .from('ticket_historial_tomas')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at');
    return (rows as List)
        .map((e) => TicketHistorialEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Cuenta tickets `ABIERTO` visibles para el usuario actual (badge de Home).
  Future<int> countAbiertos() async {
    final rows = await _client
        .from('tickets')
        .select('id')
        .eq('estado', TicketEstado.abierto.value)
        .eq('eliminado', false);
    return (rows as List).length;
  }

  /// Resuelve nombres de usuarios en lote (para mostrar en historial/detalle).
  Future<Map<String, String>> getNombresUsuarios(List<String> ids) async {
    final unicos = ids.toSet().toList();
    if (unicos.isEmpty) return {};
    final rows = await _client
        .from('usuarios')
        .select('id, nombre_completo')
        .inFilter('id', unicos);
    return {
      for (final r in (rows as List))
        (r['id'] as String): (r['nombre_completo'] as String? ?? 'Usuario'),
    };
  }

  /// Resuelve nombres de centros en lote (para mostrar en tarjetas/detalle).
  Future<Map<String, String>> getNombresCentros(List<String> ids) =>
      _resolverNombres('centros', ids);

  /// Resuelve nombres de embarcaciones en lote (para mostrar en
  /// tarjetas/detalle).
  Future<Map<String, String>> getNombresEmbarcaciones(List<String> ids) =>
      _resolverNombres('embarcaciones', ids);

  /// Catálogo completo de áreas (para el selector de filtros).
  Future<List<Map<String, dynamic>>> getCatalogoAreas() async {
    final rows = await _client
        .from('areas')
        .select('id, nombre')
        .order('nombre');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Catálogo completo de centros (para el selector de filtros).
  Future<List<Map<String, dynamic>>> getCatalogoCentros() async {
    final rows = await _client
        .from('centros')
        .select('id, nombre')
        .order('nombre');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Catálogo completo de embarcaciones (para el selector de filtros).
  Future<List<Map<String, dynamic>>> getCatalogoEmbarcaciones() async {
    final rows = await _client
        .from('embarcaciones')
        .select('id, nombre')
        .order('nombre');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Catálogo completo de contratistas (para el selector de filtros).
  Future<List<Map<String, dynamic>>> getCatalogoContratistas() async {
    final rows = await _client
        .from('contratistas')
        .select('id, nombre')
        .order('nombre');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, String>> _resolverNombres(
    String tabla,
    List<String> ids,
  ) async {
    final unicos = ids.toSet().toList();
    if (unicos.isEmpty) return {};
    final rows = await _client
        .from(tabla)
        .select('id, nombre')
        .inFilter('id', unicos);
    return {
      for (final r in (rows as List))
        (r['id'] as String): (r['nombre'] as String? ?? '—'),
    };
  }

  /// Cuenta, en lote, cuántos ítems tiene cada ticket y cuántos ya están
  /// subsanados (para la barra de progreso de la tarjeta del listado).
  Future<Map<String, ({int total, int subsanados})>> getConteoItemsPorTicket(
    List<String> ticketIds,
  ) async {
    final unicos = ticketIds.toSet().toList();
    if (unicos.isEmpty) return {};
    final rows = await _client
        .from('ticket_items')
        .select('ticket_id, subsanado')
        .inFilter('ticket_id', unicos);

    final totales = <String, int>{};
    final subsanados = <String, int>{};
    for (final r in (rows as List)) {
      final ticketId = r['ticket_id'] as String;
      totales[ticketId] = (totales[ticketId] ?? 0) + 1;
      if (r['subsanado'] == true) {
        subsanados[ticketId] = (subsanados[ticketId] ?? 0) + 1;
      }
    }
    return {
      for (final ticketId in totales.keys)
        ticketId: (
          total: totales[ticketId]!,
          subsanados: subsanados[ticketId] ?? 0,
        ),
    };
  }

  /// Trae una referencia resumida del ítem principal por ticket para mostrar
  /// en la tarjeta del listado (número de ítem y/o categoría).
  ///
  /// Regla de prioridad por ticket:
  /// 1) Primer ítem NO subsanado.
  /// 2) Si todos están subsanados, primer ítem disponible.
  /// 3) Orden ascendente por `orden` (y luego por `numero_pregunta`).
  Future<
    Map<String, ({int? numeroPregunta, String? categoria, String origenItem})>
  >
  getReferenciaItemPorTicket(List<String> ticketIds) async {
    final unicos = ticketIds.toSet().toList();
    if (unicos.isEmpty) return {};

    final rows = await _client
        .from('ticket_items')
        .select(
          'ticket_id, numero_pregunta, categoria, origen_item, subsanado, orden',
        )
        .inFilter('ticket_id', unicos);

    final byTicket = <String, List<Map<String, dynamic>>>{};
    for (final row in (rows as List)) {
      final map = (row as Map).cast<String, dynamic>();
      final ticketId = map['ticket_id']?.toString() ?? '';
      if (ticketId.isEmpty) continue;
      byTicket.putIfAbsent(ticketId, () => <Map<String, dynamic>>[]).add(map);
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int? toNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    final result =
        <
          String,
          ({int? numeroPregunta, String? categoria, String origenItem})
        >{};

    for (final entry in byTicket.entries) {
      final items = entry.value;
      items.sort((a, b) {
        final aSubsanado = a['subsanado'] == true ? 1 : 0;
        final bSubsanado = b['subsanado'] == true ? 1 : 0;
        if (aSubsanado != bSubsanado) return aSubsanado - bSubsanado;

        final byOrden = toInt(a['orden']).compareTo(toInt(b['orden']));
        if (byOrden != 0) return byOrden;

        final aNumero = toNullableInt(a['numero_pregunta']) ?? 999999;
        final bNumero = toNullableInt(b['numero_pregunta']) ?? 999999;
        return aNumero.compareTo(bNumero);
      });

      final first = items.first;
      result[entry.key] = (
        numeroPregunta: toNullableInt(first['numero_pregunta']),
        categoria: first['categoria']?.toString(),
        origenItem:
            first['origen_item']?.toString() ??
            TicketItemOrigen.respuestaInspeccion.value,
      );
    }

    return result;
  }

  // ---------------------------------------------------------------------
  // CREACIÓN
  // ---------------------------------------------------------------------

  /// Previsualiza qué hallazgos crearán ticket nuevo y cuáles ya tienen un
  /// ticket activo asociado.
  Future<TicketGeneracionPreview> previewGeneracionDesdeInspeccionPorHallazgos(
    String inspeccionId,
    String empresaId,
  ) async {
    final conteo = await contarObservacionesPotenciales(inspeccionId);

    final actividad = await _client
        .from('actividades')
        .select('id, tipo_actividad, centro_id, embarcacion_id')
        .eq('id', inspeccionId)
        .maybeSingle();
    if (actividad == null) {
      throw TicketAccionFallidaException(
        'No se encontró la inspección indicada.',
      );
    }

    final tipoInspeccion = actividad['tipo_actividad'] as String?;
    final centroId = actividad['centro_id'] as String?;
    final embarcacionId = actividad['embarcacion_id'] as String?;
    if (tipoInspeccion == null || tipoInspeccion.isEmpty) {
      throw TicketAccionFallidaException(
        'La inspección no tiene tipo de actividad válido.',
      );
    }

    final respuestasNc = await _client
        .from('inspeccion_respuestas')
        .select('id, item_id, observacion')
        .eq('actividad_id', inspeccionId)
        .eq('estado', 'NC');

    final ncRows = (respuestasNc as List)
        .cast<Map<String, dynamic>>()
        .where((row) => row['item_id'] != null)
        .toList();

    if (ncRows.isEmpty) {
      return TicketGeneracionPreview(
        hallazgos: const [],
        cantidadNoCumple: conteo.noCumple,
        cantidadFotosConObservacion: conteo.fotosConObservacion,
        usaFlujoLegacySinNc: conteo.fotosConObservacion > 0,
      );
    }

    if (embarcacionId == null && centroId == null) {
      throw TicketAccionFallidaException(
        'No se puede previsualizar continuidad del hallazgo: '
        'la inspección no tiene embarcación ni centro asociado.',
      );
    }

    final itemIds = ncRows
        .map((row) => row['item_id'] as String)
        .toSet()
        .toList(growable: false);
    final preguntas = await _client
        .from('formulario_items')
        .select('id, pregunta, categoria, orden')
        .inFilter('id', itemIds);
    final preguntasPorItemId = {
      for (final p in (preguntas as List))
        (p['id'] as String): (
          pregunta: p['pregunta'] as String? ?? 'Ítem sin descripción',
          categoria: p['categoria'] as String?,
          orden: p['orden'] as int?,
        ),
    };

    final previewItems = <TicketGeneracionPreviewItem>[];
    final ticketsCache = <String, TicketModel>{};
    final dedupeMode = embarcacionId != null
        ? 'EMBARCACION'
        : 'CENTRO_FALLBACK';

    for (final row in ncRows) {
      final itemId = row['item_id'] as String;
      final info = preguntasPorItemId[itemId];
      final rowsHallazgo = embarcacionId != null
          ? await _client
                .from('nc_hallazgos')
                .select('id')
                .eq('empresa_id', empresaId)
                .eq('tipo_actividad', tipoInspeccion)
                .eq('item_id', itemId)
                .eq('dedupe_mode', dedupeMode)
                .eq('embarcacion_id', embarcacionId)
                .inFilter('estado_hallazgo', ['ABIERTO', 'EN_SEGUIMIENTO'])
                .limit(1)
          : await _client
                .from('nc_hallazgos')
                .select('id')
                .eq('empresa_id', empresaId)
                .eq('tipo_actividad', tipoInspeccion)
                .eq('item_id', itemId)
                .eq('dedupe_mode', dedupeMode)
                .eq('centro_id', centroId!)
                .inFilter('estado_hallazgo', ['ABIERTO', 'EN_SEGUIMIENTO'])
                .limit(1);

      String? hallazgoId;
      TicketModel? existente;
      if (rowsHallazgo.isNotEmpty) {
        hallazgoId = rowsHallazgo.first['id'] as String;
        if (!ticketsCache.containsKey(hallazgoId)) {
          final ticketActivoRows = await _client
              .from('tickets')
              .select()
              .eq('hallazgo_id', hallazgoId)
              .eq('eliminado', false)
              .neq('estado', TicketEstado.cerrado.value)
              .limit(1);
          if (ticketActivoRows.isNotEmpty) {
            ticketsCache[hallazgoId] = TicketModel.fromMap(
              ticketActivoRows.first,
            );
          }
        }
        existente = ticketsCache[hallazgoId];
      }

      previewItems.add(
        TicketGeneracionPreviewItem(
          itemId: itemId,
          pregunta: info?.pregunta ?? 'Ítem sin descripción',
          categoria: info?.categoria,
          numeroPregunta: info?.orden,
          observacion: (row['observacion'] as String?)?.trim(),
          hallazgoId: hallazgoId,
          ticketActivoExistente: existente,
        ),
      );
    }

    return TicketGeneracionPreview(
      hallazgos: previewItems,
      cantidadNoCumple: conteo.noCumple,
      cantidadFotosConObservacion: conteo.fotosConObservacion,
      usaFlujoLegacySinNc: false,
    );
  }

  /// Genera el ticket automático de tipo REVISION_OBSERVACIONES a partir de
  /// una inspección de buceo/embarcación ya finalizada.
  Future<TicketModel> generarDesdeInspeccion({
    required String inspeccionId,
    required String empresaId,
    required String generadoPorId,
    required String motivo,
    String? asunto,
    DateTime? fechaLimite,
  }) async {
    final resultado = await generarDesdeInspeccionPorHallazgos(
      inspeccionId: inspeccionId,
      empresaId: empresaId,
      generadoPorId: generadoPorId,
      motivo: motivo,
      asunto: asunto,
      fechaLimite: fechaLimite,
    );

    if (resultado.creados.isNotEmpty) {
      return resultado.creados.first;
    }
    if (resultado.reutilizados.isNotEmpty) {
      return resultado.reutilizados.first;
    }
    throw TicketAccionFallidaException(
      'No se encontraron hallazgos NC para generar tickets automáticos.',
    );
  }

  /// Nuevo flujo: 1 hallazgo NC = 1 ticket.
  ///
  /// - Si el hallazgo ya existe y tiene ticket activo, reutiliza ese ticket.
  /// - Si el hallazgo existe pero no tiene ticket activo, crea ticket nuevo.
  /// - Si el hallazgo no existe, crea hallazgo + ocurrencia + ticket nuevo.
  Future<TicketGeneracionResultado> generarDesdeInspeccionPorHallazgos({
    required String inspeccionId,
    required String empresaId,
    required String generadoPorId,
    required String motivo,
    String? asunto,
    DateTime? fechaLimite,
  }) async {
    try {
      return await _generarDesdeInspeccionPorHallazgosCore(
        inspeccionId: inspeccionId,
        empresaId: empresaId,
        generadoPorId: generadoPorId,
        motivo: motivo,
        asunto: asunto,
        fechaLimite: fechaLimite,
      );
    } catch (e) {
      // Compatibilidad temporal: si la migración nueva aún no está ejecutada,
      // se usa el flujo legacy (1 ticket por inspección) para no bloquear
      // operación en terreno.
      final msg = e.toString().toLowerCase();
      final pareceSchemaIncompleto =
          msg.contains('nc_hallazgos') ||
          msg.contains('nc_hallazgo_ocurrencias') ||
          msg.contains('hallazgo_id') ||
          msg.contains('42p01') ||
          msg.contains('42703');

      final indiceLegacyPorInspeccion =
          msg.contains('uq_tickets_inspeccion_automatico') ||
          msg.contains('23505');

      if (indiceLegacyPorInspeccion) {
        throw TicketAccionFallidaException(
          'La base aún mantiene el índice antiguo de 1 ticket por inspección. '
          'Debes eliminar/reemplazar `uq_tickets_inspeccion_automatico` para '
          'permitir 1 ticket por hallazgo único.',
        );
      }

      if (!pareceSchemaIncompleto) rethrow;

      final legacy = await _generarDesdeInspeccionLegacy(
        inspeccionId: inspeccionId,
        empresaId: empresaId,
        generadoPorId: generadoPorId,
        motivo: motivo,
        asunto: asunto,
        fechaLimite: fechaLimite,
      );
      return TicketGeneracionResultado(
        creados: [legacy],
        reutilizados: const [],
        respuestasNcProcesadas: 0,
      );
    }
  }

  Future<TicketGeneracionResultado> _generarDesdeInspeccionPorHallazgosCore({
    required String inspeccionId,
    required String empresaId,
    required String generadoPorId,
    required String motivo,
    String? asunto,
    DateTime? fechaLimite,
  }) async {
    // Nota: con hallazgos únicos, una misma inspección puede terminar
    // generando múltiples tickets (uno por hallazgo). Por compatibilidad,
    // si ya existe un ticket legacy de esta inspección, se sigue permitiendo
    // generar/reutilizar por hallazgo sin bloquear por inspección.

    final actividad = await _client
        .from('actividades')
        .select('id, tipo_actividad, numero_informe, centro_id, embarcacion_id')
        .eq('id', inspeccionId)
        .maybeSingle();
    if (actividad == null) {
      throw TicketAccionFallidaException(
        'No se encontró la inspección indicada.',
      );
    }

    final centroId = actividad['centro_id'] as String?;
    final embarcacionId = actividad['embarcacion_id'] as String?;
    final tipoInspeccion = actividad['tipo_actividad'] as String?;
    if (tipoInspeccion == null || tipoInspeccion.isEmpty) {
      throw TicketAccionFallidaException(
        'La inspección no tiene tipo de actividad válido.',
      );
    }

    String? areaId;
    if (centroId != null) {
      final centro = await _client
          .from('centros')
          .select('area_id')
          .eq('id', centroId)
          .maybeSingle();
      areaId = centro?['area_id'] as String?;
    }

    // El ticket hereda el contratista dueño de la embarcación (si aplica).
    String? contratistaId;
    if (embarcacionId != null) {
      final embarcacion = await _client
          .from('embarcaciones')
          .select('contratista_id')
          .eq('id', embarcacionId)
          .maybeSingle();
      contratistaId = embarcacion?['contratista_id'] as String?;
    }

    final respuestasNc = await _client
        .from('inspeccion_respuestas')
        .select('id, item_id, observacion, criticidad_registrada')
        .eq('actividad_id', inspeccionId)
        .eq('estado', 'NC');

    final ncRows = (respuestasNc as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r['item_id'] != null)
        .toList();

    if (ncRows.isEmpty) {
      final legacy = await _generarDesdeInspeccionLegacy(
        inspeccionId: inspeccionId,
        empresaId: empresaId,
        generadoPorId: generadoPorId,
        motivo: motivo,
        asunto: asunto,
        fechaLimite: fechaLimite,
      );
      return TicketGeneracionResultado(
        creados: [legacy],
        reutilizados: const [],
        respuestasNcProcesadas: 0,
      );
    }

    final itemIds = ncRows
        .map((r) => r['item_id'] as String)
        .toSet()
        .toList(growable: false);

    final preguntas = await _client
        .from('formulario_items')
        .select('id, pregunta, categoria, orden')
        .inFilter('id', itemIds);
    final preguntasPorItemId = {
      for (final p in (preguntas as List))
        (p['id'] as String): (
          pregunta: p['pregunta'] as String? ?? 'Ítem sin descripción',
          categoria: p['categoria'] as String?,
          orden: p['orden'] as int?,
        ),
    };

    final fotos = await _client
        .from('registro_fotografico')
        .select('foto_url, inspeccion_respuesta_id')
        .eq('actividad_id', inspeccionId);
    final fotoPorRespuestaId = <String, String>{};
    for (final f in (fotos as List)) {
      final respId = f['inspeccion_respuesta_id'] as String?;
      final url = f['foto_url'] as String?;
      if (respId != null && url != null && url.isNotEmpty) {
        fotoPorRespuestaId[respId] = url;
      }
    }

    final creados = <TicketModel>[];
    final reutilizadosPorId = <String, TicketModel>{};

    for (final row in ncRows) {
      final respuestaId = row['id'] as String;
      final itemId = row['item_id'] as String;
      final observacion = (row['observacion'] as String?)?.trim();
      final criticidad = row['criticidad_registrada'] as String?;

      if (embarcacionId == null && centroId == null) {
        throw TicketAccionFallidaException(
          'No se puede resolver continuidad del hallazgo: '
          'la inspección no tiene embarcación ni centro asociado.',
        );
      }

      final dedupeMode = embarcacionId != null
          ? 'EMBARCACION'
          : 'CENTRO_FALLBACK';

      final rowsHallazgo = embarcacionId != null
          ? await _client
                .from('nc_hallazgos')
                .select()
                .eq('empresa_id', empresaId)
                .eq('tipo_actividad', tipoInspeccion)
                .eq('item_id', itemId)
                .eq('dedupe_mode', dedupeMode)
                .eq('embarcacion_id', embarcacionId)
                .inFilter('estado_hallazgo', ['ABIERTO', 'EN_SEGUIMIENTO'])
                .limit(1)
          : await _client
                .from('nc_hallazgos')
                .select()
                .eq('empresa_id', empresaId)
                .eq('tipo_actividad', tipoInspeccion)
                .eq('item_id', itemId)
                .eq('dedupe_mode', dedupeMode)
                .eq('centro_id', centroId!)
                .inFilter('estado_hallazgo', ['ABIERTO', 'EN_SEGUIMIENTO'])
                .limit(1);

      Map<String, dynamic>? hallazgo;
      if (rowsHallazgo.isNotEmpty) {
        hallazgo = rowsHallazgo.first;
        await _client
            .from('nc_hallazgos')
            .update({
              'criticidad_actual': criticidad,
              'fecha_ultima_deteccion': DateTime.now().toIso8601String(),
              'informe_ultima_ocurrencia_id': inspeccionId,
              'estado_hallazgo': 'EN_SEGUIMIENTO',
            })
            .eq('id', hallazgo['id'] as String);
      } else {
        final inserted = await _client
            .from('nc_hallazgos')
            .insert({
              'id': _uuid.v4(),
              'empresa_id': empresaId,
              'tipo_actividad': tipoInspeccion,
              'item_id': itemId,
              'dedupe_mode': dedupeMode,
              'embarcacion_id': embarcacionId,
              'centro_id': centroId,
              'estado_hallazgo': 'ABIERTO',
              'criticidad_inicial': criticidad,
              'criticidad_actual': criticidad,
              'fecha_primera_deteccion': DateTime.now().toIso8601String(),
              'fecha_ultima_deteccion': DateTime.now().toIso8601String(),
              'informe_inicial_id': inspeccionId,
              'informe_ultima_ocurrencia_id': inspeccionId,
              'creado_por': generadoPorId,
            })
            .select()
            .single();
        hallazgo = inserted;
      }

      final hallazgoId = hallazgo['id'] as String;

      final ocurrenciaExistente = await _client
          .from('nc_hallazgo_ocurrencias')
          .select('id')
          .eq('inspeccion_respuesta_id', respuestaId)
          .maybeSingle();

      String? ocurrenciaId;
      if (ocurrenciaExistente != null) {
        ocurrenciaId = ocurrenciaExistente['id'] as String;
      } else {
        final insertedOcurrencia = await _client
            .from('nc_hallazgo_ocurrencias')
            .insert({
              'id': _uuid.v4(),
              'hallazgo_id': hallazgoId,
              'inspeccion_respuesta_id': respuestaId,
              'informe_id': inspeccionId,
              'empresa_id': empresaId,
              'contratista_id': contratistaId,
              'centro_id': centroId,
              'embarcacion_id': embarcacionId,
              'fecha_ocurrencia': DateTime.now().toIso8601String(),
              'observacion': observacion,
              'criticidad_registrada': criticidad,
              'evidencia_foto_count': fotoPorRespuestaId[respuestaId] == null
                  ? 0
                  : 1,
              'creado_por': generadoPorId,
            })
            .select('id')
            .single();
        ocurrenciaId = insertedOcurrencia['id'] as String;
      }

      final ticketActivoRows = await _client
          .from('tickets')
          .select()
          .eq('hallazgo_id', hallazgoId)
          .eq('eliminado', false)
          .neq('estado', TicketEstado.cerrado.value)
          .limit(1);

      if (ticketActivoRows.isNotEmpty) {
        final t = TicketModel.fromMap(ticketActivoRows.first);
        reutilizadosPorId[t.id] = t;
        continue;
      }

      final info = preguntasPorItemId[itemId];
      final numeroInforme = actividad['numero_informe']?.toString();
      final asuntoFinal = (asunto != null && asunto.trim().isNotEmpty)
          ? asunto.trim()
          : info != null
          ? numeroInforme != null && numeroInforme.isNotEmpty
                ? 'Informe N° $numeroInforme · ${info.pregunta}'
                : info.pregunta
          : numeroInforme != null && numeroInforme.isNotEmpty
          ? 'Informe N° $numeroInforme'
          : 'Observación de inspección';

      final ticket = TicketModel(
        id: _uuid.v4(),
        empresaId: empresaId,
        origen: TicketOrigen.inspeccion,
        tipoTicket: TicketTipo.revisionObservaciones,
        inspeccionId: inspeccionId,
        tipoInspeccion: tipoInspeccion,
        numeroInforme: numeroInforme,
        areaId: areaId,
        centroId: centroId,
        embarcacionId: embarcacionId,
        contratistaId: contratistaId,
        asunto: asuntoFinal,
        motivo: motivo,
        generadoPorId: generadoPorId,
        fechaLimite: fechaLimite,
      );

      await _client.from('tickets').insert({
        ...ticket.toInsertMap(),
        'hallazgo_id': hallazgoId,
        'hallazgo_ocurrencia_id': ocurrenciaId,
      });

      final ticketItem = TicketItemModel(
        id: _uuid.v4(),
        ticketId: ticket.id,
        origenItem: TicketItemOrigen.respuestaInspeccion,
        referenciaId: respuestaId,
        pregunta: info?.pregunta ?? 'Ítem sin descripción',
        categoria: info?.categoria,
        numeroPregunta: info?.orden,
        descripcion: observacion != null && observacion.isNotEmpty
            ? observacion
            : 'Sin observación adicional del inspector.',
        fotoOriginalUrl: fotoPorRespuestaId[respuestaId],
        orden: 0,
      );
      await _client.from('ticket_items').insert(ticketItem.toInsertMap());

      final creado = await getTicketById(ticket.id);
      creados.add(creado ?? ticket);
    }

    return TicketGeneracionResultado(
      creados: creados,
      reutilizados: reutilizadosPorId.values.toList(growable: false),
      respuestasNcProcesadas: ncRows.length,
    );
  }

  Future<TicketModel> _generarDesdeInspeccionLegacy({
    required String inspeccionId,
    required String empresaId,
    required String generadoPorId,
    required String motivo,
    String? asunto,
    DateTime? fechaLimite,
  }) async {
    final existente = await getTicketAutomaticoDeInspeccion(inspeccionId);
    if (existente != null) {
      throw TicketAccionFallidaException(
        'Ya existe un ticket generado para esta inspección '
        '(${existente.codigoTicket ?? existente.id}).',
      );
    }

    final actividad = await _client
        .from('actividades')
        .select('id, tipo_actividad, numero_informe, centro_id, embarcacion_id')
        .eq('id', inspeccionId)
        .maybeSingle();
    if (actividad == null) {
      throw TicketAccionFallidaException(
        'No se encontró la inspección indicada.',
      );
    }

    final centroId = actividad['centro_id'] as String?;
    final embarcacionId = actividad['embarcacion_id'] as String?;

    String? areaId;
    if (centroId != null) {
      final centro = await _client
          .from('centros')
          .select('area_id')
          .eq('id', centroId)
          .maybeSingle();
      areaId = centro?['area_id'] as String?;
    }

    String? contratistaId;
    if (embarcacionId != null) {
      final embarcacion = await _client
          .from('embarcaciones')
          .select('contratista_id')
          .eq('id', embarcacionId)
          .maybeSingle();
      contratistaId = embarcacion?['contratista_id'] as String?;
    }

    final ticket = TicketModel(
      id: _uuid.v4(),
      empresaId: empresaId,
      origen: TicketOrigen.inspeccion,
      tipoTicket: TicketTipo.revisionObservaciones,
      inspeccionId: inspeccionId,
      tipoInspeccion: actividad['tipo_actividad'] as String?,
      numeroInforme: actividad['numero_informe']?.toString(),
      areaId: areaId,
      centroId: centroId,
      embarcacionId: embarcacionId,
      contratistaId: contratistaId,
      asunto: asunto,
      motivo: motivo,
      generadoPorId: generadoPorId,
      fechaLimite: fechaLimite,
    );

    await _client.from('tickets').insert(ticket.toInsertMap());

    try {
      final items = await _armarItemsDesdeInspeccion(
        ticketId: ticket.id,
        inspeccionId: inspeccionId,
      );
      if (items.isNotEmpty) {
        await _client
            .from('ticket_items')
            .insert(items.map((e) => e.toInsertMap()).toList());
      }
    } catch (e) {
      // Si no se pudieron armar/insertar los ítems, no dejamos un ticket
      // "fantasma" sin observaciones: además de confundir al usuario, el
      // índice único de "1 ticket automático por inspección" bloquearía
      // cualquier reintento posterior para la misma inspección. Se revierte
      // el ticket recién creado y se relanza el error original.
      await _client.from('tickets').delete().eq('id', ticket.id);
      rethrow;
    }

    final creado = await getTicketById(ticket.id);
    return creado ?? ticket;
  }

  /// Cuenta cuántos `ticket_items` se generarían para [inspeccionId] sin
  /// crearlos: respuestas `NC` y fotos con observación no asociadas a una
  /// respuesta. Se usa para advertir al usuario cuando intenta generar un
  /// ticket de una inspección con 100% de cumplimiento (sin nada que
  /// subsanar), en vez de dejarlo crear un ticket vacío en silencio.
  Future<({int noCumple, int fotosConObservacion})>
  contarObservacionesPotenciales(String inspeccionId) async {
    final respuestasNc = await _client
        .from('inspeccion_respuestas')
        .select('id')
        .eq('actividad_id', inspeccionId)
        .eq('estado', 'NC');

    final fotos = await _client
        .from('registro_fotografico')
        .select('descripcion, inspeccion_respuesta_id')
        .eq('actividad_id', inspeccionId);

    var fotosConObservacion = 0;
    for (final f in (fotos as List)) {
      final respId = f['inspeccion_respuesta_id'] as String?;
      final descripcion = (f['descripcion'] as String?)?.trim() ?? '';
      if (respId == null && descripcion.isNotEmpty) fotosConObservacion++;
    }

    return (
      noCumple: (respuestasNc as List).length,
      fotosConObservacion: fotosConObservacion,
    );
  }

  /// Arma los `ticket_items` a partir de las respuestas `NC` y las fotos con
  /// observación de una inspección (ver plan §5.1).
  Future<List<TicketItemModel>> _armarItemsDesdeInspeccion({
    required String ticketId,
    required String inspeccionId,
  }) async {
    final items = <TicketItemModel>[];
    int orden = 0;

    final respuestasNc = await _client
        .from('inspeccion_respuestas')
        .select('id, item_id, observacion')
        .eq('actividad_id', inspeccionId)
        .eq('estado', 'NC');

    final itemIds = (respuestasNc as List)
        .map((r) => r['item_id'] as String?)
        .whereType<String>()
        .toList();

    Map<String, ({String pregunta, String? categoria, int? orden})>
    preguntasPorItemId = {};
    if (itemIds.isNotEmpty) {
      final preguntas = await _client
          .from('formulario_items')
          .select('id, pregunta, categoria, orden')
          .inFilter('id', itemIds);
      preguntasPorItemId = {
        for (final p in (preguntas as List))
          (p['id'] as String): (
            pregunta: p['pregunta'] as String? ?? 'Ítem',
            categoria: p['categoria'] as String?,
            orden: p['orden'] as int?,
          ),
      };
    }

    final fotos = await _client
        .from('registro_fotografico')
        .select('id, foto_url, descripcion, inspeccion_respuesta_id')
        .eq('actividad_id', inspeccionId);

    final fotoPorRespuestaId = <String, String>{};
    final fotosGeneralesConObservacion = <Map<String, dynamic>>[];
    for (final f in (fotos as List)) {
      final respId = f['inspeccion_respuesta_id'] as String?;
      final descripcion = (f['descripcion'] as String?)?.trim() ?? '';
      if (respId != null) {
        fotoPorRespuestaId[respId] = f['foto_url'] as String;
      } else if (descripcion.isNotEmpty) {
        fotosGeneralesConObservacion.add(f);
      }
    }

    for (final r in respuestasNc) {
      final respuestaId = r['id'] as String;
      final itemId = r['item_id'] as String?;
      final info = preguntasPorItemId[itemId];
      final observacion = (r['observacion'] as String?)?.trim();
      items.add(
        TicketItemModel(
          id: _uuid.v4(),
          ticketId: ticketId,
          origenItem: TicketItemOrigen.respuestaInspeccion,
          referenciaId: respuestaId,
          pregunta: info?.pregunta ?? 'Ítem sin descripción',
          categoria: info?.categoria,
          numeroPregunta: info?.orden,
          descripcion: observacion != null && observacion.isNotEmpty
              ? observacion
              : 'Sin observación adicional del inspector.',
          fotoOriginalUrl: fotoPorRespuestaId[respuestaId],
          orden: orden++,
        ),
      );
    }

    for (final f in fotosGeneralesConObservacion) {
      items.add(
        TicketItemModel(
          id: _uuid.v4(),
          ticketId: ticketId,
          origenItem: TicketItemOrigen.fotoObservacion,
          referenciaId: f['id'] as String?,
          descripcion:
              (f['descripcion'] as String?)?.trim() ??
              'Observación fotográfica',
          fotoOriginalUrl: f['foto_url'] as String?,
          orden: orden++,
        ),
      );
    }

    return items;
  }

  /// Crea un ticket de tipo SOLICITUD (manual, sin inspección asociada).
  Future<TicketModel> crearSolicitud({
    required String empresaId,
    required String generadoPorId,
    required String motivo,
    String? asunto,
    String? areaId,
    String? centroId,
    String? embarcacionId,
    String? contratistaId,
    DateTime? fechaLimite,
  }) async {
    final ticket = TicketModel(
      id: _uuid.v4(),
      empresaId: empresaId,
      origen: TicketOrigen.solicitud,
      tipoTicket: TicketTipo.solicitud,
      areaId: areaId,
      centroId: centroId,
      embarcacionId: embarcacionId,
      contratistaId: contratistaId,
      asunto: asunto,
      motivo: motivo,
      generadoPorId: generadoPorId,
      fechaLimite: fechaLimite,
    );
    await _client.from('tickets').insert(ticket.toInsertMap());
    final creado = await getTicketById(ticket.id);
    return creado ?? ticket;
  }

  // ---------------------------------------------------------------------
  // CICLO DE VIDA: TOMAR / SOLTAR / SUBSANAR / FINALIZAR
  // ---------------------------------------------------------------------

  /// Intenta tomar el ticket de forma atómica (gana el primero en confirmar).
  Future<TicketModel> tomarTicket({
    required String ticketId,
    required String usuarioId,
  }) async {
    final rows = await _client
        .from('tickets')
        .update({
          'estado': TicketEstado.tomado.value,
          'tomado_por_id': usuarioId,
        })
        .eq('id', ticketId)
        .filter('tomado_por_id', 'is', null)
        .inFilter('estado', [
          TicketEstado.abierto.value,
          TicketEstado.parcial.value,
        ])
        .select();

    if ((rows as List).isEmpty) {
      final actual = await getTicketById(ticketId);
      String detalle = 'ya fue tomado por otro usuario';
      if (actual?.tomadoPorId != null) {
        final nombres = await getNombresUsuarios([actual!.tomadoPorId!]);
        final nombre = nombres[actual.tomadoPorId];
        if (nombre != null) detalle = 'ya fue tomado por $nombre';
      }
      throw TicketAccionFallidaException(
        'No se pudo tomar el ticket: $detalle.',
      );
    }

    await _registrarHistorial(
      ticketId: ticketId,
      usuarioId: usuarioId,
      accion: TicketHistorialAccion.tomado,
    );

    final ticket = TicketModel.fromMap(rows.first);
    if (ticket.generadoPorId != usuarioId) {
      await _crearNotificacion(
        ticketId: ticketId,
        usuarioDestinoId: ticket.generadoPorId,
        tipo: TicketNotificacionTipo.tomado,
        mensaje: 'Tu ticket fue tomado por un profesional.',
      );
    }
    return ticket;
  }

  /// Suelta el ticket que el usuario tiene tomado (queda `PARCIAL`).
  Future<void> soltarTicket({
    required String ticketId,
    required String usuarioId,
  }) async {
    final rows = await _client
        .from('tickets')
        .update({'estado': TicketEstado.parcial.value, 'tomado_por_id': null})
        .eq('id', ticketId)
        .eq('tomado_por_id', usuarioId)
        .select();

    if ((rows as List).isEmpty) {
      throw TicketAccionFallidaException(
        'No se pudo soltar el ticket: ya no lo tienes tomado.',
      );
    }

    await _registrarHistorial(
      ticketId: ticketId,
      usuarioId: usuarioId,
      accion: TicketHistorialAccion.soltado,
    );

    final ticket = TicketModel.fromMap(rows.first);
    if (ticket.generadoPorId != usuarioId) {
      await _crearNotificacion(
        ticketId: ticketId,
        usuarioDestinoId: ticket.generadoPorId,
        tipo: TicketNotificacionTipo.parcial,
        mensaje:
            'Tu ticket quedó parcialmente resuelto y está disponible de nuevo.',
      );
    }
  }

  /// Marca (o desmarca) un ítem como subsanado. Al activar exige [foto].
  Future<TicketItemModel> marcarItemSubsanado({
    required TicketItemModel item,
    required String usuarioId,
    required bool subsanado,
    File? foto,
  }) async {
    String? fotoUrl;
    if (subsanado) {
      if (foto == null) {
        throw TicketAccionFallidaException(
          'Debes adjuntar una foto para marcar esta observación como subsanada.',
        );
      }
      final path =
          'tickets/${item.ticketId}/${item.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('evidencias').upload(path, foto);
      fotoUrl = _client.storage.from('evidencias').getPublicUrl(path);
    }

    final update = <String, dynamic>{
      'subsanado': subsanado,
      'foto_subsanacion_url': subsanado ? fotoUrl : null,
      'subsanado_por_id': subsanado ? usuarioId : null,
      'subsanado_at': subsanado ? DateTime.now().toIso8601String() : null,
    };

    final rows = await _client
        .from('ticket_items')
        .update(update)
        .eq('id', item.id)
        .select();

    final actualizado = TicketItemModel.fromMap((rows as List).first);

    // Auditoría histórica por item: permite reportar última subsanación,
    // recuento de retrabajos y tiempos de ciclo en dashboard.
    try {
      final ticket = await getTicketById(item.ticketId);
      await _client.from('ticket_item_subsanaciones').insert({
        'id': _uuid.v4(),
        'ticket_id': item.ticketId,
        'ticket_item_id': item.id,
        'hallazgo_id': ticket?.hallazgoId,
        'accion': subsanado ? 'SUBSANADO' : 'DESHECHO',
        'usuario_id': usuarioId,
        'foto_subsanacion_url': actualizado.fotoSubsanacionUrl,
      });
    } catch (e) {
      debugPrint(
        '⚠️ [TicketRepository] Error guardando bitácora de subsanación: $e',
      );
    }

    if (subsanado) {
      await _finalizarSiCorresponde(
        ticketId: item.ticketId,
        usuarioId: usuarioId,
      );
    }

    return actualizado;
  }

  Future<void> _finalizarSiCorresponde({
    required String ticketId,
    required String usuarioId,
  }) async {
    final items = await getItems(ticketId);
    if (items.isEmpty || items.any((i) => !i.subsanado)) return;

    final rows = await _client
        .from('tickets')
        .update({'estado': TicketEstado.finalizadoPendienteRevision.value})
        .eq('id', ticketId)
        .eq('estado', TicketEstado.tomado.value)
        .select();

    if ((rows as List).isEmpty) return; // ya estaba en otro estado

    await _registrarHistorial(
      ticketId: ticketId,
      usuarioId: usuarioId,
      accion: TicketHistorialAccion.finalizado,
    );
  }

  /// Finaliza explícitamente el ticket que [usuarioId] tiene tomado y lo
  /// envía a revisión del admin. A diferencia de [_finalizarSiCorresponde]
  /// (que solo se dispara como efecto colateral de subsanar el último ítem),
  /// esto permite finalizar tickets sin ítems (ej. SOLICITUD), que de otra
  /// forma nunca podrían salir del estado TOMADO.
  Future<void> finalizarTicket({
    required String ticketId,
    required String usuarioId,
  }) async {
    final items = await getItems(ticketId);
    if (items.isNotEmpty && items.any((i) => !i.subsanado)) {
      throw TicketAccionFallidaException('Aún hay observaciones sin subsanar.');
    }

    final rows = await _client
        .from('tickets')
        .update({'estado': TicketEstado.finalizadoPendienteRevision.value})
        .eq('id', ticketId)
        .eq('estado', TicketEstado.tomado.value)
        .eq('tomado_por_id', usuarioId)
        .select();

    if ((rows as List).isEmpty) {
      throw TicketAccionFallidaException(
        'No se pudo finalizar: el ticket ya no está tomado por ti.',
      );
    }

    await _registrarHistorial(
      ticketId: ticketId,
      usuarioId: usuarioId,
      accion: TicketHistorialAccion.finalizado,
    );
  }

  /// Elimina (borrado lógico) un ticket. Solo el autor del ticket o un admin
  /// pueden hacerlo (reforzado también por un trigger en la base de datos,
  /// ver supabase_migration_tickets_borrado_y_mejoras.sql).
  Future<void> eliminarTicket({
    required String ticketId,
    required String usuarioId,
  }) async {
    try {
      final rows = await _client
          .from('tickets')
          .update({'eliminado': true})
          .eq('id', ticketId)
          .select();

      if ((rows as List).isEmpty) {
        throw TicketAccionFallidaException(
          'No se pudo eliminar: el ticket ya no existe o no tienes permiso.',
        );
      }
    } on PostgrestException catch (e) {
      throw TicketAccionFallidaException(
        'No se pudo eliminar el ticket: ${e.message}',
      );
    }
  }

  // ---------------------------------------------------------------------
  // REVISIÓN (ADMIN)
  // ---------------------------------------------------------------------

  Future<void> aprobarTicket({
    required String ticketId,
    required String adminId,
  }) async {
    final rows = await _client
        .from('tickets')
        .update({
          'estado': TicketEstado.cerrado.value,
          'revisado_por_id': adminId,
          'revisado_at': DateTime.now().toIso8601String(),
          'rechazado': false,
        })
        .eq('id', ticketId)
        .eq('estado', TicketEstado.finalizadoPendienteRevision.value)
        .select();

    if ((rows as List).isEmpty) {
      throw TicketAccionFallidaException(
        'No se pudo aprobar: el ticket ya no está pendiente de revisión.',
      );
    }

    await _registrarHistorial(
      ticketId: ticketId,
      usuarioId: adminId,
      accion: TicketHistorialAccion.revisadoAprobado,
    );

    final ticket = TicketModel.fromMap(rows.first);
    final destinatarios = <String>{ticket.generadoPorId};
    for (final id in destinatarios) {
      await _crearNotificacion(
        ticketId: ticketId,
        usuarioDestinoId: id,
        tipo: TicketNotificacionTipo.aprobado,
        mensaje: 'Tu ticket fue aprobado.',
      );
    }
  }

  Future<void> rechazarTicket({
    required String ticketId,
    required String adminId,
    required String motivo,
  }) async {
    final antes = await getTicketById(ticketId);
    final rows = await _client
        .from('tickets')
        .update({
          'estado': TicketEstado.parcial.value,
          'tomado_por_id': null,
          'rechazado': true,
          'motivo_rechazo': motivo,
          'rechazado_por_id': adminId,
          'rechazado_at': DateTime.now().toIso8601String(),
        })
        .eq('id', ticketId)
        .eq('estado', TicketEstado.finalizadoPendienteRevision.value)
        .select();

    if ((rows as List).isEmpty) {
      throw TicketAccionFallidaException(
        'No se pudo rechazar: el ticket ya no está pendiente de revisión.',
      );
    }

    await _registrarHistorial(
      ticketId: ticketId,
      usuarioId: adminId,
      accion: TicketHistorialAccion.revisadoRechazado,
      comentario: motivo,
    );

    final ticket = TicketModel.fromMap(rows.first);
    final destinatarios = <String>{
      ticket.generadoPorId,
      if (antes?.tomadoPorId != null) antes!.tomadoPorId!,
    };
    for (final id in destinatarios) {
      await _crearNotificacion(
        ticketId: ticketId,
        usuarioDestinoId: id,
        tipo: TicketNotificacionTipo.rechazado,
        mensaje: 'Tu ticket fue rechazado: $motivo',
      );
    }
  }

  Future<void> _registrarHistorial({
    required String ticketId,
    required String usuarioId,
    required TicketHistorialAccion accion,
    String? comentario,
  }) async {
    try {
      await _client.from('ticket_historial_tomas').insert({
        'id': _uuid.v4(),
        'ticket_id': ticketId,
        'usuario_id': usuarioId,
        'accion': accion.value,
        'comentario': comentario,
      });
    } catch (e) {
      debugPrint('⚠️ [TicketRepository] Error registrando historial: $e');
    }
  }

  Future<void> _crearNotificacion({
    required String ticketId,
    required String usuarioDestinoId,
    required TicketNotificacionTipo tipo,
    required String mensaje,
  }) async {
    try {
      await _client.from('ticket_notificaciones').insert({
        'id': _uuid.v4(),
        'ticket_id': ticketId,
        'usuario_destino_id': usuarioDestinoId,
        'tipo': tipo.value,
        'mensaje': mensaje,
      });
    } catch (e) {
      debugPrint('⚠️ [TicketRepository] Error creando notificación: $e');
    }
  }

  // ---------------------------------------------------------------------
  // NOTIFICACIONES IN-APP
  // ---------------------------------------------------------------------

  Future<List<TicketNotificacionModel>> getNotificaciones(
    String usuarioId, {
    int limit = 30,
  }) async {
    final rows = await _client
        .from('ticket_notificaciones')
        .select()
        .eq('usuario_destino_id', usuarioId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => TicketNotificacionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> countNoLeidas(String usuarioId) async {
    final rows = await _client
        .from('ticket_notificaciones')
        .select('id')
        .eq('usuario_destino_id', usuarioId)
        .eq('leido', false);
    return (rows as List).length;
  }

  Future<void> marcarNotificacionLeida(String id) async {
    await _client
        .from('ticket_notificaciones')
        .update({'leido': true})
        .eq('id', id);
  }

  // ---------------------------------------------------------------------
  // REALTIME
  // ---------------------------------------------------------------------

  /// Se suscribe a cambios de la tabla `tickets` para refrescar listas en vivo.
  RealtimeChannel subscribeTickets(void Function() onChange) {
    final channel = _client.channel('tickets_realtime_${_uuid.v4()}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tickets',
          callback: (payload) => onChange(),
        )
        .subscribe();
    return channel;
  }

  /// Se suscribe a notificaciones nuevas para el usuario actual.
  RealtimeChannel subscribeNotificaciones({
    required String usuarioId,
    required void Function(TicketNotificacionModel) onNotify,
  }) {
    final channel = _client.channel('ticket_notif_realtime_${_uuid.v4()}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ticket_notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_destino_id',
            value: usuarioId,
          ),
          callback: (payload) {
            onNotify(TicketNotificacionModel.fromMap(payload.newRecord));
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
