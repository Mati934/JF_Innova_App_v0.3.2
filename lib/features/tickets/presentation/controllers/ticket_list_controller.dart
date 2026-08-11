import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../domain/models/ticket_model.dart';

class AreaTicketSummary {
  static const sinAreaKey = '_solicitudes_sin_area_';

  final String areaKey;
  final String areaNombre;
  final int total;
  final int abiertos;
  final int tomados;
  final int parciales;
  final int pendientesRevision;
  final int cerrados;
  final int vencidos;
  final int hechos;
  final int noHechos;
  final int faltanAprobacion;
  final DateTime? fechaTentativaMasCercana;
  final double porcentajeHechos;
  final double porcentajeAprobadosDeHechos;

  const AreaTicketSummary({
    required this.areaKey,
    required this.areaNombre,
    required this.total,
    required this.abiertos,
    required this.tomados,
    required this.parciales,
    required this.pendientesRevision,
    required this.cerrados,
    required this.vencidos,
    required this.hechos,
    required this.noHechos,
    required this.faltanAprobacion,
    required this.fechaTentativaMasCercana,
    required this.porcentajeHechos,
    required this.porcentajeAprobadosDeHechos,
  });
}

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
  Map<String, String> nombresCentros = {};
  Map<String, String> nombresEmbarcaciones = {};
  Map<String, ({int total, int subsanados})> conteoItems = {};
  Map<String, ({int? numeroPregunta, String? categoria, String origenItem})>
  referenciaItems = {};

  // Catálogos completos para los selectores de filtro (no solo los ids
  // usados por los tickets cargados, sino todo el listado disponible).
  List<Map<String, dynamic>> catalogoAreas = [];
  List<Map<String, dynamic>> catalogoCentros = [];
  List<Map<String, dynamic>> catalogoEmbarcaciones = [];
  List<Map<String, dynamic>> catalogoContratistas = [];

  // Filtros activos (claves: estado, tipo_ticket, tipo_inspeccion, centro_id, embarcacion_id, area_id, contratista_id)
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
    _cargarCatalogosFiltro();
    _suscribirRealtime();
  }

  Future<void> _cargarCatalogosFiltro() async {
    try {
      final resultados = await Future.wait([
        _repo.getCatalogoAreas(),
        _repo.getCatalogoCentros(),
        _repo.getCatalogoEmbarcaciones(),
        _repo.getCatalogoContratistas(),
      ]);
      catalogoAreas = resultados[0];
      catalogoCentros = resultados[1];
      catalogoEmbarcaciones = resultados[2];
      catalogoContratistas = resultados[3];
      _safeNotify();
    } catch (e) {
      debugPrint(
        '⚠️ [TicketListController] No se pudieron cargar catálogos de filtro: $e',
      );
    }
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
        contratistaId: activeFilters['contratista_id'],
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
      final centroIds = tickets
          .map((t) => t.centroId)
          .whereType<String>()
          .toList();
      final embarcacionIds = tickets
          .map((t) => t.embarcacionId)
          .whereType<String>()
          .toList();
      final ticketIds = tickets.map((t) => t.id).toList();

      final resultados = await Future.wait([
        _repo.getNombresUsuarios(ids),
        _repo.getNombresCentros(centroIds),
        _repo.getNombresEmbarcaciones(embarcacionIds),
        _repo.getConteoItemsPorTicket(ticketIds),
        _repo.getReferenciaItemPorTicket(ticketIds),
      ]);
      nombresUsuarios = resultados[0] as Map<String, String>;
      nombresCentros = resultados[1] as Map<String, String>;
      nombresEmbarcaciones = resultados[2] as Map<String, String>;
      conteoItems = resultados[3] as Map<String, ({int total, int subsanados})>;
      referenciaItems =
          resultados[4]
              as Map<
                String,
                ({int? numeroPregunta, String? categoria, String origenItem})
              >;
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

  String? nombreCentro(String? centroId) =>
      centroId == null ? null : nombresCentros[centroId];

  String? nombreEmbarcacion(String? embarcacionId) =>
      embarcacionId == null ? null : nombresEmbarcaciones[embarcacionId];

  /// Progreso de subsanación de un ticket (null si no tiene ítems).
  ({int total, int subsanados})? progresoDe(String ticketId) =>
      conteoItems[ticketId];

  ({int? numeroPregunta, String? categoria, String origenItem})?
  referenciaItemDe(String ticketId) => referenciaItems[ticketId];

  String nombreArea(String? areaId) {
    if (areaId == null || areaId.isEmpty) return 'Solicitudes';
    for (final area in catalogoAreas) {
      if (area['id']?.toString() == areaId) {
        final nombre = area['nombre']?.toString().trim() ?? '';
        if (nombre.isNotEmpty) return nombre;
      }
    }
    return 'Area ${areaId.substring(0, areaId.length > 6 ? 6 : areaId.length)}';
  }

  List<AreaTicketSummary> resumenPorArea() {
    final grouped = <String, List<TicketModel>>{};

    // Siempre mostrar todas las áreas del catálogo, incluso con 0 tickets.
    for (final area in catalogoAreas) {
      final id = area['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      grouped[id] = <TicketModel>[];
    }

    for (final ticket in tickets) {
      final key = (ticket.areaId == null || ticket.areaId!.isEmpty)
          ? AreaTicketSummary.sinAreaKey
          : ticket.areaId!;
      grouped.putIfAbsent(key, () => <TicketModel>[]).add(ticket);
    }

    final summary = <AreaTicketSummary>[];
    for (final entry in grouped.entries) {
      final areaKey = entry.key;
      final areaTickets = entry.value;

      final total = areaTickets.length;
      final abiertos = areaTickets
          .where((t) => t.estado == TicketEstado.abierto)
          .length;
      final tomados = areaTickets
          .where((t) => t.estado == TicketEstado.tomado)
          .length;
      final parciales = areaTickets
          .where((t) => t.estado == TicketEstado.parcial)
          .length;
      final pendientesRevision = areaTickets
          .where((t) => t.estado == TicketEstado.finalizadoPendienteRevision)
          .length;
      final cerrados = areaTickets
          .where((t) => t.estado == TicketEstado.cerrado)
          .length;

      final hechos = pendientesRevision + cerrados;
      final noHechos = total - hechos;
      final faltanAprobacion = pendientesRevision;

      final vencidos = areaTickets
          .where(
            (t) =>
                t.estado != TicketEstado.cerrado &&
                t.fechaLimite != null &&
                t.fechaLimite!.isBefore(DateTime.now()),
          )
          .length;

      DateTime? fechaMasCercana;
      for (final ticket in areaTickets) {
        final fecha = ticket.fechaLimite;
        if (ticket.estado == TicketEstado.cerrado || fecha == null) continue;
        if (fechaMasCercana == null || fecha.isBefore(fechaMasCercana)) {
          fechaMasCercana = fecha;
        }
      }

      summary.add(
        AreaTicketSummary(
          areaKey: areaKey,
          areaNombre: areaKey == AreaTicketSummary.sinAreaKey
              ? 'Solicitudes'
              : nombreArea(areaKey),
          total: total,
          abiertos: abiertos,
          tomados: tomados,
          parciales: parciales,
          pendientesRevision: pendientesRevision,
          cerrados: cerrados,
          vencidos: vencidos,
          hechos: hechos,
          noHechos: noHechos,
          faltanAprobacion: faltanAprobacion,
          fechaTentativaMasCercana: fechaMasCercana,
          porcentajeHechos: total == 0 ? 0 : (hechos / total),
          porcentajeAprobadosDeHechos: hechos == 0 ? 0 : (cerrados / hechos),
        ),
      );
    }

    summary.sort((a, b) {
      final aEsSolicitud = a.areaKey == AreaTicketSummary.sinAreaKey;
      final bEsSolicitud = b.areaKey == AreaTicketSummary.sinAreaKey;
      if (aEsSolicitud && !bEsSolicitud) return 1;
      if (!aEsSolicitud && bEsSolicitud) return -1;

      final aFecha = a.fechaTentativaMasCercana;
      final bFecha = b.fechaTentativaMasCercana;
      if (aFecha == null && bFecha == null) {
        if (a.total != b.total) return b.total.compareTo(a.total);
        return a.areaNombre.toLowerCase().compareTo(b.areaNombre.toLowerCase());
      }
      if (aFecha == null) return 1;
      if (bFecha == null) return -1;
      return aFecha.compareTo(bFecha);
    });

    return summary;
  }

  AreaTicketSummary resumenGlobal() {
    final byArea = resumenPorArea();
    if (byArea.isEmpty) {
      return const AreaTicketSummary(
        areaKey: 'global',
        areaNombre: 'Global',
        total: 0,
        abiertos: 0,
        tomados: 0,
        parciales: 0,
        pendientesRevision: 0,
        cerrados: 0,
        vencidos: 0,
        hechos: 0,
        noHechos: 0,
        faltanAprobacion: 0,
        fechaTentativaMasCercana: null,
        porcentajeHechos: 0,
        porcentajeAprobadosDeHechos: 0,
      );
    }

    int total = 0;
    int abiertos = 0;
    int tomados = 0;
    int parciales = 0;
    int pendientesRevision = 0;
    int cerrados = 0;
    int vencidos = 0;
    int hechos = 0;
    int noHechos = 0;
    int faltanAprobacion = 0;

    DateTime? fechaMasCercana;

    for (final area in byArea) {
      total += area.total;
      abiertos += area.abiertos;
      tomados += area.tomados;
      parciales += area.parciales;
      pendientesRevision += area.pendientesRevision;
      cerrados += area.cerrados;
      vencidos += area.vencidos;
      hechos += area.hechos;
      noHechos += area.noHechos;
      faltanAprobacion += area.faltanAprobacion;

      final fecha = area.fechaTentativaMasCercana;
      if (fecha != null &&
          (fechaMasCercana == null || fecha.isBefore(fechaMasCercana))) {
        fechaMasCercana = fecha;
      }
    }

    return AreaTicketSummary(
      areaKey: 'global',
      areaNombre: 'Global',
      total: total,
      abiertos: abiertos,
      tomados: tomados,
      parciales: parciales,
      pendientesRevision: pendientesRevision,
      cerrados: cerrados,
      vencidos: vencidos,
      hechos: hechos,
      noHechos: noHechos,
      faltanAprobacion: faltanAprobacion,
      fechaTentativaMasCercana: fechaMasCercana,
      porcentajeHechos: total == 0 ? 0 : (hechos / total),
      porcentajeAprobadosDeHechos: hechos == 0 ? 0 : (cerrados / hechos),
    );
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
