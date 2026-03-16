import '../models/ticket_model.dart';

abstract class TicketsRepository {
  /// Obtiene todos los tickets (visibles para todos los usuarios autenticados).
  Future<List<TicketModel>> getTickets();

  /// Crea un nuevo ticket.
  Future<TicketModel> crearTicket({
    required String titulo,
    required String descripcion,
    required String prioridad,
    required String creadoPor,
    required String nombreCreador,
  });

  /// Actualiza el estado de un ticket propio.
  Future<void> actualizarEstado(String id, String nuevoEstado);

  /// Elimina un ticket propio.
  Future<void> eliminarTicket(String id);
}
