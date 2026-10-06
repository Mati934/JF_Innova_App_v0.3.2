import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_item_model.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';

/// Tests de serialización/deserialización y getters puros de los modelos de
/// Tickets (TicketModel, TicketItemModel), incluyendo el flujo de hallazgos
/// únicos (hallazgoId) agregado en supabase_migration_nc_hallazgos_unicos_v1.sql.
void main() {
  group('TicketOrigen', () {
    test('fromValue mapea INSPECCION y SOLICITUD', () {
      expect(TicketOrigen.fromValue('INSPECCION'), TicketOrigen.inspeccion);
      expect(TicketOrigen.fromValue('SOLICITUD'), TicketOrigen.solicitud);
    });

    test('fromValue cae a SOLICITUD con valor desconocido o null', () {
      expect(TicketOrigen.fromValue(null), TicketOrigen.solicitud);
      expect(TicketOrigen.fromValue('ALGO_RARO'), TicketOrigen.solicitud);
    });
  });

  group('TicketEstado', () {
    test('fromValue mapea todos los estados válidos', () {
      expect(TicketEstado.fromValue('ABIERTO'), TicketEstado.abierto);
      expect(TicketEstado.fromValue('TOMADO'), TicketEstado.tomado);
      expect(TicketEstado.fromValue('PARCIAL'), TicketEstado.parcial);
      expect(
        TicketEstado.fromValue('FINALIZADO_PENDIENTE_REVISION'),
        TicketEstado.finalizadoPendienteRevision,
      );
      expect(TicketEstado.fromValue('CERRADO'), TicketEstado.cerrado);
    });

    test('fromValue cae a ABIERTO con valor desconocido o null', () {
      expect(TicketEstado.fromValue(null), TicketEstado.abierto);
      expect(TicketEstado.fromValue('XYZ'), TicketEstado.abierto);
    });
  });

  group('TicketItemOrigen', () {
    test('fromValue mapea todos los orígenes válidos', () {
      expect(
        TicketItemOrigen.fromValue('FOTO_OBSERVACION'),
        TicketItemOrigen.fotoObservacion,
      );
      expect(TicketItemOrigen.fromValue('MANUAL'), TicketItemOrigen.manual);
    });

    test(
      'fromValue cae a RESPUESTA_INSPECCION con valor desconocido o null',
      () {
        expect(
          TicketItemOrigen.fromValue(null),
          TicketItemOrigen.respuestaInspeccion,
        );
        expect(
          TicketItemOrigen.fromValue('OTRO'),
          TicketItemOrigen.respuestaInspeccion,
        );
      },
    );
  });

  group('TicketModel.tituloVisible', () {
    TicketModel base({
      String? asunto,
      String? motivo,
      TicketOrigen origen = TicketOrigen.solicitud,
    }) {
      return TicketModel(
        id: 't1',
        empresaId: 'empresa-1',
        origen: origen,
        tipoTicket: TicketTipo.solicitud,
        asunto: asunto,
        motivo: motivo,
        generadoPorId: 'user-1',
      );
    }

    test('usa el asunto si existe y no está vacío', () {
      final t = base(asunto: 'Mi asunto', motivo: 'Motivo largo');
      expect(t.tituloVisible, 'Mi asunto');
    });

    test('usa el motivo si el asunto es null o vacío', () {
      final t = base(asunto: '  ', motivo: 'Motivo corto');
      expect(t.tituloVisible, 'Motivo corto');
    });

    test('trunca el motivo a 60 caracteres con elipsis', () {
      final motivoLargo = 'a' * 100;
      final t = base(motivo: motivoLargo);
      expect(t.tituloVisible.length, 61); // 60 chars + '…'
      expect(t.tituloVisible.endsWith('…'), isTrue);
    });

    test('sin asunto ni motivo, usa el fallback según origen', () {
      final tInspeccion = base(origen: TicketOrigen.inspeccion);
      final tSolicitud = base(origen: TicketOrigen.solicitud);
      expect(tInspeccion.tituloVisible, 'Observación de inspección');
      expect(tSolicitud.tituloVisible, 'Solicitud');
    });
  });

  group('TicketModel.estaVencido', () {
    TicketModel conFecha({
      DateTime? fechaLimite,
      TicketEstado estado = TicketEstado.abierto,
    }) {
      return TicketModel(
        id: 't1',
        empresaId: 'empresa-1',
        origen: TicketOrigen.solicitud,
        tipoTicket: TicketTipo.solicitud,
        generadoPorId: 'user-1',
        fechaLimite: fechaLimite,
        estado: estado,
      );
    }

    test('false si no tiene fecha límite', () {
      expect(conFecha(fechaLimite: null).estaVencido, isFalse);
    });

    test('true si la fecha límite ya pasó y no está cerrado', () {
      final t = conFecha(
        fechaLimite: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(t.estaVencido, isTrue);
    });

    test('false si la fecha límite es futura', () {
      final t = conFecha(
        fechaLimite: DateTime.now().add(const Duration(days: 1)),
      );
      expect(t.estaVencido, isFalse);
    });

    test('false si ya está CERRADO aunque la fecha límite haya pasado', () {
      final t = conFecha(
        fechaLimite: DateTime.now().subtract(const Duration(days: 1)),
        estado: TicketEstado.cerrado,
      );
      expect(t.estaVencido, isFalse);
    });
  });

  group('TicketModel.fromMap / toInsertMap', () {
    test('round-trip conserva hallazgoId y campos_extra_json', () {
      final map = {
        'id': 't1',
        'codigo_ticket': 'TCK-2026-0001',
        'empresa_id': 'empresa-1',
        'origen': 'INSPECCION',
        'tipo_ticket': 'REVISION_OBSERVACIONES',
        'inspeccion_id': 'insp-1',
        'hallazgo_id': 'hallazgo-1',
        'tipo_inspeccion': 'INSPECCION_BUCEO',
        'numero_informe': '123',
        'area_id': 'area-1',
        'centro_id': 'centro-1',
        'embarcacion_id': 'emb-1',
        'contratista_id': 'contr-1',
        'asunto': null,
        'motivo': 'Motivo',
        'generado_por_id': 'user-1',
        'estado': 'ABIERTO',
        'tomado_por_id': null,
        'fecha_limite': null,
        'revisado_por_id': null,
        'revisado_at': null,
        'rechazado': false,
        'motivo_rechazo': null,
        'rechazado_por_id': null,
        'rechazado_at': null,
        'campos_extra_json': {'sla_dias': 5},
        'eliminado': false,
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      };

      final ticket = TicketModel.fromMap(map);
      expect(ticket.hallazgoId, 'hallazgo-1');
      expect(ticket.camposExtra, {'sla_dias': 5});
      expect(ticket.estado, TicketEstado.abierto);

      final insertMap = ticket.toInsertMap();
      expect(insertMap['hallazgo_id'], 'hallazgo-1');
      expect(insertMap['campos_extra_json'], {'sla_dias': 5});
      // toInsertMap no debe incluir codigo_ticket (lo asigna la BD).
      expect(insertMap.containsKey('codigo_ticket'), isFalse);
    });

    test('eliminado y rechazado se leen como booleanos aunque vengan null', () {
      final map = {
        'id': 't1',
        'empresa_id': 'empresa-1',
        'origen': 'SOLICITUD',
        'tipo_ticket': 'SOLICITUD',
        'generado_por_id': 'user-1',
      };
      final ticket = TicketModel.fromMap(map);
      expect(ticket.eliminado, isFalse);
      expect(ticket.rechazado, isFalse);
      expect(ticket.hallazgoId, isNull);
      expect(ticket.camposExtra, isEmpty);
    });
  });

  group('TicketItemModel.fromMap / toInsertMap', () {
    test('round-trip conserva categoria, numeroPregunta y pregunta', () {
      final map = {
        'id': 'i1',
        'ticket_id': 't1',
        'origen_item': 'RESPUESTA_INSPECCION',
        'referencia_id': 'resp-1',
        'descripcion': 'desc',
        'foto_original_url': 'http://foto.jpg',
        'subsanado': false,
        'orden': 2,
        'categoria': 'Seguridad',
        'numero_pregunta': 7,
        'pregunta': '¿Usa arnés?',
      };
      final item = TicketItemModel.fromMap(map);
      expect(item.categoria, 'Seguridad');
      expect(item.numeroPregunta, 7);
      expect(item.pregunta, '¿Usa arnés?');

      final insertMap = item.toInsertMap();
      expect(insertMap['categoria'], 'Seguridad');
      expect(insertMap['numero_pregunta'], 7);
      expect(insertMap['pregunta'], '¿Usa arnés?');
    });

    test('descripcion vacía por defecto si viene null', () {
      final map = {
        'id': 'i1',
        'ticket_id': 't1',
        'origen_item': 'FOTO_OBSERVACION',
        'descripcion': null,
      };
      final item = TicketItemModel.fromMap(map);
      expect(item.descripcion, '');
      expect(item.origenItem, TicketItemOrigen.fotoObservacion);
      expect(item.categoria, isNull);
      expect(item.numeroPregunta, isNull);
    });

    test('copyWith solo cambia subsanado y fotoSubsanacionUrl', () {
      final item = TicketItemModel(
        id: 'i1',
        ticketId: 't1',
        origenItem: TicketItemOrigen.respuestaInspeccion,
        descripcion: 'desc',
        categoria: 'Cat',
        numeroPregunta: 3,
        pregunta: 'Pregunta',
      );
      final subsanadoItem = item.copyWith(
        subsanado: true,
        fotoSubsanacionUrl: 'http://subsanacion.jpg',
      );
      expect(subsanadoItem.subsanado, isTrue);
      expect(subsanadoItem.fotoSubsanacionUrl, 'http://subsanacion.jpg');
      expect(subsanadoItem.categoria, 'Cat');
      expect(subsanadoItem.numeroPregunta, 3);
      expect(subsanadoItem.pregunta, 'Pregunta');
    });
  });
}
