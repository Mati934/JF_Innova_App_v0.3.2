import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../domain/models/ticket_model.dart';

/// Controlador de la pantalla de lista de Tickets.
/// El módulo es 100% online: si no hay internet, [isBlocked] queda en true
/// y la UI debe mostrar el estado bloqueado (ver plan §7 y §9).
class TicketListController extends ChangeNotifier {
  final _repo = TicketRepository();
  final _connectivity = ConnectivityService();

  bool _disposed = false;
  bool isLoading = true;
  String? errorMessage;
  List<TicketModel> tickets = [];
  Map<String, String> nombresUsuarios = {};

  // Filtros activos (claves: estado, tipo_ticket, tipo_inspeccion, centro_id, embarcacion_id, area_id)
  Map<String, String> activeFilters = {};

  RealtimeChannel? _channel;

  bool get isBlocked => !_connectivity.isOnline;
  String? get usuarioActualId => Supabase.instance.client.auth.currentUser?.id;

  TicketListController() {
    _connectivity.onReconnect(_onReconnect);
    if (!isBlocked) {
      _init();
    } else {
      isLoading = false;
    }
  }

  void _onReconnect() {
    if (!_disposed) {
      cargarTickets();
      _suscribirRealtime();
    }
  }

  Future<void> _init() async {
    await cargarTickets();
    _suscribirRealtime();
  }

  void _suscribirRealtime() {
    _channel ??= _repo.subscribeTickets(() {
      if (!_disposed) cargarTickets(silencioso: true);
    });
  }

  Future<void> cargarTickets({bool silencioso = false}) async {
    if (isBlocked) {
      isLoading = false;
      _safeNotify();
      return;
    }
    if (!silencioso) {
      isLoading = true;
      errorMessage = null;
      _safeNotify();
    }
    try {
      final resultado = await _repo.getTickets(
        estado: activeFilters['estado'],
        tipoTicket: activeFilters['tipo_ticket'],
        tipoInspeccion: activeFilters['tipo_inspeccion'],
        centroId: activeFilters['centro_id'],
        embarcacionId: activeFilters['embarcacion_id'],
        areaId: activeFilters['area_id'],
      );
      // Los tickets tomados por el usuario actual van primero (decisión 13).
      final miId = usuarioActualId;
      resultado.sort((a, b) {
        final aMio = miId != null && a.tomadoPorId == miId ? 0 : 1;
        final bMio = miId != null && b.tomadoPorId == miId ? 0 : 1;
        if (aMio != bMio) return aMio - bMio;
        return (b.createdAt ?? DateTime(2000)).compareTo(
          a.createdAt ?? DateTime(2000),
        );
      });
      tickets = resultado;

      final ids = <String>{
        ...tickets.map((t) => t.generadoPorId),
        ...tickets.map((t) => t.tomadoPorId).whereType<String>(),
      }.toList();
      nombresUsuarios = await _repo.getNombresUsuarios(ids);
    } catch (e) {
      errorMessage = 'No se pudieron cargar los tickets: $e';
      debugPrint('⚠️ [TicketListController] $errorMessage');
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  void applyFilters(Map<String, String> filters) {
    activeFilters = filters;
    cargarTickets();
  }

  Future<String?> tomarTicket(String ticketId) async {
    final uid = usuarioActualId;
    if (uid == null) return 'Sesión no válida.';
    try {
      await _repo.tomarTicket(ticketId: ticketId, usuarioId: uid);
      await cargarTickets(silencioso: true);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('TicketAccionFallidaException: ', '');
    }
  }

  String nombreDe(String? userId) {
    if (userId == null) return '—';
    return nombresUsuarios[userId] ?? 'Usuario';
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivity.removeOnReconnect(_onReconnect);
    if (_channel != null) {
      _repo.unsubscribe(_channel!);
    }
    super.dispose();
  }
}
