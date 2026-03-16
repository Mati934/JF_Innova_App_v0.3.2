import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/supabase_tickets_repository.dart';
import '../../domain/models/ticket_model.dart';

class TicketsController extends ChangeNotifier {
  final _repo = SupabaseTicketsRepository();
  final User? _user = Supabase.instance.client.auth.currentUser;

  List<TicketModel> tickets = [];
  bool isLoading = false;
  String? errorMessage;

  String get userId => _user?.id ?? '';

  TicketsController() {
    cargarTickets();
  }

  Future<void> cargarTickets() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      tickets = await _repo.getTickets();
    } catch (e) {
      errorMessage = 'Error al cargar los tickets: $e';
      debugPrint('❌ TicketsController.cargarTickets: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> crearTicket({
    required String titulo,
    required String descripcion,
    required String prioridad,
  }) async {
    if (_user == null) return false;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Intentamos obtener el nombre del usuario desde la tabla usuarios
      String nombreCreador = _user!.email ?? 'Usuario';
      try {
        final perfil = await Supabase.instance.client
            .from('usuarios')
            .select('nombre_completo')
            .eq('id', _user!.id)
            .single()
            .timeout(const Duration(seconds: 3));
        nombreCreador =
            perfil['nombre_completo'] as String? ?? nombreCreador;
      } catch (e) {
        // Si falla, usamos el email como nombre
        debugPrint('⚠️ TicketsController: no se pudo obtener perfil, usando email: $e');
      }

      final nuevo = await _repo.crearTicket(
        titulo: titulo,
        descripcion: descripcion,
        prioridad: prioridad,
        creadoPor: _user!.id,
        nombreCreador: nombreCreador,
      );
      tickets = [nuevo, ...tickets];
      return true;
    } catch (e) {
      errorMessage = 'Error al crear el ticket: $e';
      debugPrint('❌ TicketsController.crearTicket: $e');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> actualizarEstado(String id, String nuevoEstado) async {
    try {
      await _repo.actualizarEstado(id, nuevoEstado);
      // Recargamos la lista para obtener el timestamp real del servidor
      await cargarTickets();
    } catch (e) {
      debugPrint('❌ TicketsController.actualizarEstado: $e');
    }
  }

  Future<void> eliminarTicket(String id) async {
    try {
      await _repo.eliminarTicket(id);
      tickets = tickets.where((t) => t.id != id).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ TicketsController.eliminarTicket: $e');
    }
  }
}
