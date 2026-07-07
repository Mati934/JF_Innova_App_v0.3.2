import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_item_model.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';
import 'package:jf_innova_app/features/tickets/domain/ticket_reglas.dart';

/// Tests de las reglas de negocio puras del módulo Tickets (TicketReglas),
/// que cubren dos bugs reportados:
///  1) Un ticket sin ítems (ej. SOLICITUD) nunca podía finalizarse/cerrarse
///     porque la única vía de finalización era un efecto colateral de
///     subsanar el último ítem.
///  2) Se podía generar un ticket automático desde una inspección con 100%
///     de cumplimiento sin ninguna advertencia.
void main() {
  TicketModel ticketDe({
    required TicketEstado estado,
    String? tomadoPorId,
    String generadoPorId = 'user-autor',
  }) {
    return TicketModel(
      id: 't1',
      empresaId: 'empresa-1',
      origen: TicketOrigen.solicitud,
      tipoTicket: TicketTipo.solicitud,
      motivo: 'motivo',
      generadoPorId: generadoPorId,
      estado: estado,
      tomadoPorId: tomadoPorId,
    );
  }

  TicketItemModel itemDe({required bool subsanado}) {
    return TicketItemModel(
      id: 'i1',
      ticketId: 't1',
      origenItem: TicketItemOrigen.respuestaInspeccion,
      descripcion: 'desc',
      subsanado: subsanado,
    );
  }

  group('TicketReglas.puedeFinalizar', () {
    test('false si el ticket es null', () {
      expect(
        TicketReglas.puedeFinalizar(
          ticket: null,
          items: const [],
          usuarioId: 'u1',
        ),
        isFalse,
      );
    });

    test('false si el usuario no está autenticado', () {
      final t = ticketDe(estado: TicketEstado.tomado, tomadoPorId: 'u1');
      expect(
        TicketReglas.puedeFinalizar(
          ticket: t,
          items: const [],
          usuarioId: null,
        ),
        isFalse,
      );
    });

    test('false si el ticket no está TOMADO', () {
      final t = ticketDe(estado: TicketEstado.abierto);
      expect(
        TicketReglas.puedeFinalizar(
          ticket: t,
          items: const [],
          usuarioId: 'u1',
        ),
        isFalse,
      );
    });

    test('false si lo tomó otro usuario', () {
      final t = ticketDe(estado: TicketEstado.tomado, tomadoPorId: 'otro');
      expect(
        TicketReglas.puedeFinalizar(
          ticket: t,
          items: const [],
          usuarioId: 'u1',
        ),
        isFalse,
      );
    });

    test('true sin ítems (bug corregido: ticket SOLICITUD sin observaciones '
        'ahora sí se puede finalizar)', () {
      final t = ticketDe(estado: TicketEstado.tomado, tomadoPorId: 'u1');
      expect(
        TicketReglas.puedeFinalizar(
          ticket: t,
          items: const [],
          usuarioId: 'u1',
        ),
        isTrue,
      );
    });

    test('false si hay ítems sin subsanar', () {
      final t = ticketDe(estado: TicketEstado.tomado, tomadoPorId: 'u1');
      final items = [itemDe(subsanado: true), itemDe(subsanado: false)];
      expect(
        TicketReglas.puedeFinalizar(ticket: t, items: items, usuarioId: 'u1'),
        isFalse,
      );
    });

    test('true si todos los ítems están subsanados', () {
      final t = ticketDe(estado: TicketEstado.tomado, tomadoPorId: 'u1');
      final items = [itemDe(subsanado: true), itemDe(subsanado: true)];
      expect(
        TicketReglas.puedeFinalizar(ticket: t, items: items, usuarioId: 'u1'),
        isTrue,
      );
    });
  });

  group('TicketReglas.puedeEliminar', () {
    test('false si el ticket es null', () {
      expect(
        TicketReglas.puedeEliminar(
          ticket: null,
          usuarioId: 'u1',
          esAdmin: false,
        ),
        isFalse,
      );
    });

    test('true para el autor del ticket', () {
      final t = ticketDe(estado: TicketEstado.abierto, generadoPorId: 'u1');
      expect(
        TicketReglas.puedeEliminar(ticket: t, usuarioId: 'u1', esAdmin: false),
        isTrue,
      );
    });

    test('true para un admin aunque no sea el autor', () {
      final t = ticketDe(estado: TicketEstado.abierto, generadoPorId: 'otro');
      expect(
        TicketReglas.puedeEliminar(ticket: t, usuarioId: 'u1', esAdmin: true),
        isTrue,
      );
    });

    test('false para un usuario que no es el autor ni admin', () {
      final t = ticketDe(estado: TicketEstado.abierto, generadoPorId: 'otro');
      expect(
        TicketReglas.puedeEliminar(ticket: t, usuarioId: 'u1', esAdmin: false),
        isFalse,
      );
    });
  });

  group('TicketReglas.debeConfirmarGeneracionSinNoCumple', () {
    test('true cuando no hay ningún "No Cumple" (100% cumplimiento)', () {
      expect(
        TicketReglas.debeConfirmarGeneracionSinNoCumple(cantidadNoCumple: 0),
        isTrue,
      );
    });

    test('false cuando hay al menos un "No Cumple"', () {
      expect(
        TicketReglas.debeConfirmarGeneracionSinNoCumple(cantidadNoCumple: 1),
        isFalse,
      );
    });
  });
}
