import 'package:jf_innova_app/features/tickets/domain/models/ticket_categoria_model.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';

abstract class TicketRepository {
  Future<List<TicketCategoriaModel>> getCategoriasLocales();
  Future<List<TicketModel>> getTicketsLocales();
  Future<void> saveTicketLocal(TicketModel ticket);
  Future<void> updateTicketLocal(TicketModel ticket);
  Future<void> softDeleteTicket(String id);
  Future<void> syncTicketsHaciaSupabase();
  Future<int> getCantidadTicketsAbiertos();
}
