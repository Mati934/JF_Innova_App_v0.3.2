import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/user_session.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../domain/models/ticket_model.dart';
import '../../domain/models/ticket_item_model.dart';
import '../../domain/models/ticket_historial_entry.dart';
import '../../domain/ticket_reglas.dart';

/// Controlador de la pantalla de detalle de un ticket: ítems, historial y
/// acciones de ciclo de vida (tomar/soltar/subsanar/aprobar/rechazar).
class TicketDetailController extends ChangeNotifier {
  final _repo = TicketRepository();
  final String ticketId;

  bool _disposed = false;
  bool isLoading = true;
  String? errorMessage;
  bool isProcessing = false;

  TicketModel? ticket;
  List<TicketItemModel> items = [];
  List<TicketHistorialEntry> historial = [];
  Map<String, String> nombresUsuarios = {};
  String? nombreCentro;
  String? nombreEmbarcacion;

  TicketDetailController(this.ticketId) {
    cargar();
  }

  String? get usuarioActualId => Supabase.instance.client.auth.currentUser?.id;
  bool get esAdmin => UserSession().esAdmin;

  bool get puedoTomar =>
      ticket != null &&
      (ticket!.estado == TicketEstado.abierto ||
          ticket!.estado == TicketEstado.parcial);

  bool get puedoSoltar =>
      ticket != null &&
      ticket!.estado == TicketEstado.tomado &&
      ticket!.tomadoPorId == usuarioActualId;

  bool get puedoSubsanar =>
      ticket != null &&
      ticket!.estado == TicketEstado.tomado &&
      ticket!.tomadoPorId == usuarioActualId;

  bool get puedoRevisar =>
      esAdmin &&
      ticket != null &&
      ticket!.estado == TicketEstado.finalizadoPendienteRevision;

  /// Puede enviar el ticket a revisión: ya subsanó todo (o no tenía ítems,
  /// caso de una SOLICITUD sin observaciones).
  bool get puedoFinalizar => TicketReglas.puedeFinalizar(
    ticket: ticket,
    items: items,
    usuarioId: usuarioActualId,
  );

  bool get puedoEliminar => TicketReglas.puedeEliminar(
    ticket: ticket,
    usuarioId: usuarioActualId,
    esAdmin: esAdmin,
  );

  Future<void> cargar() async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();
    try {
      final t = await _repo.getTicketById(ticketId);
      if (t == null) {
        errorMessage = 'El ticket ya no existe.';
        return;
      }
      final its = await _repo.getItems(ticketId);
      final hist = await _repo.getHistorial(ticketId);

      final ids = <String>{
        t.generadoPorId,
        if (t.tomadoPorId != null) t.tomadoPorId!,
        if (t.rechazadoPorId != null) t.rechazadoPorId!,
        if (t.revisadoPorId != null) t.revisadoPorId!,
        ...hist.map((h) => h.usuarioId),
        ...its.map((i) => i.subsanadoPorId).whereType<String>(),
      }.toList();

      ticket = t;
      items = its;
      historial = hist;
      nombresUsuarios = await _repo.getNombresUsuarios(ids);
      nombreCentro = t.centroId != null
          ? (await _repo.getNombresCentros([t.centroId!]))[t.centroId!]
          : null;
      nombreEmbarcacion = t.embarcacionId != null
          ? (await _repo.getNombresEmbarcaciones([
              t.embarcacionId!,
            ]))[t.embarcacionId!]
          : null;
    } catch (e) {
      errorMessage = 'No se pudo cargar el ticket: $e';
      debugPrint('⚠️ [TicketDetailController] $errorMessage');
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  String nombreDe(String? userId) {
    if (userId == null) return '—';
    return nombresUsuarios[userId] ?? 'Usuario';
  }

  Future<String?> tomar() async {
    final uid = usuarioActualId;
    if (uid == null) return 'Sesión no válida.';
    return _ejecutar(() async {
      await _repo.tomarTicket(ticketId: ticketId, usuarioId: uid);
    });
  }

  Future<String?> soltar() async {
    final uid = usuarioActualId;
    if (uid == null) return 'Sesión no válida.';
    return _ejecutar(
      () => _repo.soltarTicket(ticketId: ticketId, usuarioId: uid),
    );
  }

  Future<String?> marcarItem({
    required TicketItemModel item,
    required bool subsanado,
    File? foto,
  }) async {
    final uid = usuarioActualId;
    if (uid == null) return 'Sesión no válida.';
    return _ejecutar(() async {
      await _repo.marcarItemSubsanado(
        item: item,
        usuarioId: uid,
        subsanado: subsanado,
        foto: foto,
      );
    });
  }

  Future<String?> finalizar() async {
    final uid = usuarioActualId;
    if (uid == null) return 'Sesión no válida.';
    return _ejecutar(
      () => _repo.finalizarTicket(ticketId: ticketId, usuarioId: uid),
    );
  }

  /// Elimina (borrado lógico) el ticket. No recarga el detalle: quien llame
  /// a esto debe salir de la pantalla si no hubo error.
  Future<String?> eliminar() async {
    final uid = usuarioActualId;
    if (uid == null) return 'Sesión no válida.';
    isProcessing = true;
    _safeNotify();
    try {
      await _repo.eliminarTicket(ticketId: ticketId, usuarioId: uid);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('TicketAccionFallidaException: ', '');
    } finally {
      isProcessing = false;
      _safeNotify();
    }
  }

  Future<String?> aprobar() async {
    final uid = usuarioActualId;
    if (uid == null) return 'Sesión no válida.';
    return _ejecutar(
      () => _repo.aprobarTicket(ticketId: ticketId, adminId: uid),
    );
  }

  Future<String?> rechazar(String motivo) async {
    final uid = usuarioActualId;
    if (uid == null) return 'Sesión no válida.';
    return _ejecutar(
      () => _repo.rechazarTicket(
        ticketId: ticketId,
        adminId: uid,
        motivo: motivo,
      ),
    );
  }

  Future<String?> _ejecutar(Future<void> Function() accion) async {
    isProcessing = true;
    _safeNotify();
    try {
      await accion();
      await cargar();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('TicketAccionFallidaException: ', '');
    } finally {
      isProcessing = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
