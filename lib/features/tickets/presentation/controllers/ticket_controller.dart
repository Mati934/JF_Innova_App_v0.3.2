import 'package:flutter/foundation.dart';
import 'package:jf_innova_app/features/tickets/data/repositories/supabase_ticket_repository.dart';
import 'package:jf_innova_app/features/tickets/data/repositories/ticket_repository.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_categoria_model.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';

class TicketController extends ChangeNotifier {
  final TicketRepository _repository;
  final _supaRepo = SupabaseTicketRepository();

  TicketController(this._repository);

  List<TicketModel> _allTickets = [];
  List<TicketModel> _tickets = [];
  List<TicketCategoriaModel> _categorias = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isCategoriasLoaded = false;
  String? errorMessage;

  List<TicketModel> get tickets => _tickets;
  List<TicketCategoriaModel> get categorias => _categorias;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isCategoriasLoaded => _isCategoriasLoaded;

  Future<void> loadTickets() async {
    _isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _allTickets = await _repository.getTicketsLocales();
      _tickets = List.from(_allTickets);
    } catch (e) {
      errorMessage = 'No se pudieron cargar los tickets.';
      debugPrint('❌ [TicketController] Error en loadTickets: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filtra la lista en memoria sin volver a consultar la BD.
  void applyFilters(Map<String, String> filters) {
    if (filters.isEmpty) {
      _tickets = List.from(_allTickets);
      notifyListeners();
      return;
    }

    _tickets = _allTickets.where((ticket) {
      if (filters.containsKey('empresa_id') &&
          ticket.empresaId != filters['empresa_id']) {
        return false;
      }
      if (filters.containsKey('area_id') && ticket.areaId != filters['area_id']) {
        return false;
      }
      if (filters.containsKey('solicitante_id') &&
          ticket.solicitanteId != filters['solicitante_id']) {
        return false;
      }
      if (filters.containsKey('criticidad') &&
          ticket.criticidad.toLowerCase() !=
              filters['criticidad']!.toLowerCase()) {
        return false;
      }
      if (filters.containsKey('estado') &&
          ticket.estado.toLowerCase() != filters['estado']!.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    notifyListeners();
  }

  /// Carga las categorías una sola vez (lazy-load idempotente).
  Future<void> loadCategorias() async {
    if (_isCategoriasLoaded) return;
    try {
      _categorias = await _repository.getCategoriasLocales();
      if (_categorias.isEmpty) {
        _categorias = [
          TicketCategoriaModel(id: '1', nombre: 'Buceo'),
          TicketCategoriaModel(id: '2', nombre: 'Trabajo Marítimo'),
          TicketCategoriaModel(id: '3', nombre: 'Mantenimiento'),
          TicketCategoriaModel(id: '4', nombre: 'Otro'),
        ];
      }
    } catch (e) {
      debugPrint('❌ [TicketController] Error en loadCategorias: $e');
    } finally {
      _isCategoriasLoaded = true;
      notifyListeners();
    }
  }

  /// Intenta subir a Supabase inmediatamente si hay red.
  Future<void> _trySyncNow() async {
    try {
      await _supaRepo.syncTicketsHaciaSupabase();
    } catch (_) {
      // Sin internet — se sincronizará en el próximo sync manual.
    }
  }

  Future<void> _refreshList() async {
    _allTickets = await _repository.getTicketsLocales();
    _tickets = List.from(_allTickets);
  }

  /// Guarda un ticket localmente y trata de subirlo inmediatamente si hay red.
  Future<bool> saveTicket(TicketModel ticket) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _repository.saveTicketLocal(ticket);
      await _trySyncNow();
      await _refreshList();
      return true;
    } catch (e) {
      debugPrint('❌ [TicketController] Error en saveTicket: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Actualiza un ticket existente (tomar / cerrar / editar) y trata de sincronizar.
  Future<bool> updateTicket(TicketModel ticket) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _repository.updateTicketLocal(ticket);
      await _trySyncNow();
      await _refreshList();
      return true;
    } catch (e) {
      debugPrint('❌ [TicketController] Error en updateTicket: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Elimina un ticket localmente (soft-delete) y también en Supabase si hay red.
  Future<bool> deleteTicket(String id) async {
    try {
      await _repository.softDeleteTicket(id);
      // Intentar eliminar en Supabase (si no estaba subido, simplemente no hace nada).
      try {
        await _supaRepo.deleteRemoteTicket(id);
      } catch (_) {
        // Sin internet — no está en Supabase o se borrará en próxima sesión.
      }
      await _refreshList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ [TicketController] Error en deleteTicket: $e');
      return false;
    }
  }
}
