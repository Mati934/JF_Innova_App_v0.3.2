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
  }) async {
    var query = _client.from('tickets').select().eq('eliminado', false);

    if (estado != null) query = query.eq('estado', estado);
    if (tipoTicket != null) query = query.eq('tipo_ticket', tipoTicket);
    if (tipoInspeccion != null) {
      query = query.eq('tipo_inspeccion', tipoInspeccion);
    }
    if (centroId != null) query = query.eq('centro_id', centroId);
    if (embarcacionId != null)
      query = query.eq('embarcacion_id', embarcacionId);
    if (areaId != null) query = query.eq('area_id', areaId);

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

  /// Ticket automático ya existente para una inspección (si lo hay).
  Future<TicketModel?> getTicketAutomaticoDeInspeccion(
    String inspeccionId,
  ) async {
    final row = await _client
        .from('tickets')
        .select()
        .eq('inspeccion_id', inspeccionId)
        .eq('origen', TicketOrigen.inspeccion.value)
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

  // ---------------------------------------------------------------------
  // CREACIÓN
  // ---------------------------------------------------------------------

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
      asunto: asunto,
      motivo: motivo,
      generadoPorId: generadoPorId,
      fechaLimite: fechaLimite,
    );

    await _client.from('tickets').insert(ticket.toInsertMap());

    final items = await _armarItemsDesdeInspeccion(
      ticketId: ticket.id,
      inspeccionId: inspeccionId,
    );
    if (items.isNotEmpty) {
      await _client
          .from('ticket_items')
          .insert(items.map((e) => e.toInsertMap()).toList());
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

    Map<String, String> preguntasPorItemId = {};
    if (itemIds.isNotEmpty) {
      final preguntas = await _client
          .from('formulario_items')
          .select('id, pregunta')
          .inFilter('id', itemIds);
      preguntasPorItemId = {
        for (final p in (preguntas as List))
          (p['id'] as String): (p['pregunta'] as String? ?? 'Ítem'),
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
      final pregunta = preguntasPorItemId[itemId] ?? 'Ítem sin descripción';
      final observacion = (r['observacion'] as String?)?.trim();
      items.add(
        TicketItemModel(
          id: _uuid.v4(),
          ticketId: ticketId,
          origenItem: TicketItemOrigen.respuestaInspeccion,
          referenciaId: respuestaId,
          descripcion: observacion != null && observacion.isNotEmpty
              ? '$pregunta — $observacion'
              : pregunta,
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
