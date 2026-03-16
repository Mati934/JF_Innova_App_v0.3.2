import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/ticket_model.dart';
import '../../domain/repositories/tickets_repository.dart';

class SupabaseTicketsRepository implements TicketsRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  @override
  Future<List<TicketModel>> getTickets() async {
    final response = await _client
        .from('tickets')
        .select()
        .order('fecha_creacion', ascending: false);

    return (response as List)
        .map((e) => TicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TicketModel> crearTicket({
    required String titulo,
    required String descripcion,
    required String prioridad,
    required String creadoPor,
    required String nombreCreador,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    final data = {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'estado': 'Abierto',
      'prioridad': prioridad,
      'creado_por': creadoPor,
      'nombre_creador': nombreCreador,
      'fecha_creacion': now,
      'fecha_actualizacion': now,
    };

    final response =
        await _client.from('tickets').insert(data).select().single();

    return TicketModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> actualizarEstado(String id, String nuevoEstado) async {
    await _client
        .from('tickets')
        .update({'estado': nuevoEstado})
        .eq('id', id);
  }

  @override
  Future<void> eliminarTicket(String id) async {
    await _client.from('tickets').delete().eq('id', id);
  }
}
