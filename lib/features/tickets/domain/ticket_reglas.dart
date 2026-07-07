import 'models/ticket_item_model.dart';
import 'models/ticket_model.dart';

/// Reglas de negocio puras del ciclo de vida de un ticket, separadas del
/// controlador para poder testearlas sin depender de Supabase/UserSession.
class TicketReglas {
  TicketReglas._();

  /// true si [usuarioId] puede finalizar (enviar a revisión del admin) el
  /// ticket que tiene tomado.
  ///
  /// Cubre dos casos:
  /// - Ticket con ítems: todos deben estar subsanados.
  /// - Ticket sin ítems (típico de un ticket de tipo SOLICITUD, que no tiene
  ///   observaciones que subsanar): se puede finalizar directamente, ya que
  ///   de lo contrario nunca podría salir del estado TOMADO (bug corregido:
  ///   antes solo se finalizaba automáticamente al marcar el último ítem
  ///   subsanado, lo que dejaba a los tickets sin ítems sin forma de
  ///   cerrarse).
  static bool puedeFinalizar({
    required TicketModel? ticket,
    required List<TicketItemModel> items,
    required String? usuarioId,
  }) {
    if (ticket == null || usuarioId == null) return false;
    if (ticket.estado != TicketEstado.tomado) return false;
    if (ticket.tomadoPorId != usuarioId) return false;
    return items.isEmpty || items.every((i) => i.subsanado);
  }

  /// true si [usuarioId] puede eliminar (borrado lógico) el ticket: el propio
  /// autor del ticket, o cualquier usuario admin.
  static bool puedeEliminar({
    required TicketModel? ticket,
    required String? usuarioId,
    required bool esAdmin,
  }) {
    if (ticket == null || usuarioId == null) return false;
    return esAdmin || ticket.generadoPorId == usuarioId;
  }

  /// true si se debe pedir confirmación explícita antes de generar un ticket
  /// automático porque la inspección no tiene ninguna respuesta "No Cumple"
  /// (100% de cumplimiento). El usuario igual puede continuar si hay fotos
  /// con observación que ameriten seguimiento.
  static bool debeConfirmarGeneracionSinNoCumple({
    required int cantidadNoCumple,
  }) {
    return cantidadNoCumple == 0;
  }
}
