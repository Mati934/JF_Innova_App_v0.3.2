import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../sync/services/sync_service.dart';
import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../visits/data/repositories/local_visit_repository.dart';
import '../../../tickets/data/repositories/local_ticket_repository.dart';
import '../../../extintores/data/repositories/local_extintor_repository.dart';

class HomeController extends ChangeNotifier {
  final _syncService = SyncService();
  final _localRepo = LocalInspectionRepository();
  final _visitRepo = LocalVisitRepository();
  final _extintorRepo = LocalExtintorRepository();
  final _ticketRepo = LocalTicketRepository();
  final _connectivity = ConnectivityService();

  final User? user = Supabase.instance.client.auth.currentUser;

  bool _isAdminUser = false;
  bool _disposed = false;

  bool get esAdmin => _isAdminUser;

  String nombreUsuario = 'Cargando...';

  // Variables de Sincronización
  bool isSyncing = false;
  String? syncMessage;
  bool isError = false;

  // Variables de Borradores
  List<Map<String, dynamic>> borradores = [];
  bool isLoadingBorradores = true;

  // Variables de Notificaciones
  int _ticketsAbiertos = 0;
  int get ticketsAbiertos => _ticketsAbiertos;

  // Estado de conectividad
  bool get isOnline => _connectivity.isOnline;
  StreamSubscription<bool>? _connectivitySubscription;

  HomeController() {
    _inicializarDatos();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onStatusChange.listen((online) {
      _safeNotify();
    });
  }

  Future<void> _inicializarDatos() async {
    await _cargarPerfil(); // 100% Offline
    await Future.wait([cargarBorradores(), cargarNotificacionesTickets()]);
    _sincronizarSilencioso(); // Background sync para maestros y subidas
  }

  // --- LÓGICA DE BORRADORES ---
  Future<void> cargarBorradores() async {
    isLoadingBorradores = true;
    _safeNotify();

    try {
      final resultados = await Future.wait([
        _localRepo.getBorradores(),
        _visitRepo.getBorradores(),
        _extintorRepo.getBorradores(),
      ]);

      final inspecciones = resultados[0];
      final visitas = resultados[1];
      final extintores = resultados[2];

      // Fusionamos
      borradores = [...inspecciones, ...visitas, ...extintores];

      // Ordenamos por fecha (del más reciente al más antiguo)
      borradores.sort((a, b) {
        final fechaA = a['fecha_realizacion'] ?? '';
        final fechaB = b['fecha_realizacion'] ?? '';
        return fechaB.compareTo(fechaA);
      });
    } catch (e) {
      debugPrint("❌ Error cargando borradores combinados: $e");
      borradores = [];
    } finally {
      isLoadingBorradores = false;
      _safeNotify();
    }
  }

  // --- LÓGICA DE NOTIFICACIONES DE TICKETS ---
  Future<void> cargarNotificacionesTickets() async {
    try {
      _ticketsAbiertos = await _ticketRepo.getCantidadTicketsAbiertos();
    } catch (e) {
      debugPrint('❌ [HomeController] Error al cargar tickets abiertos: $e');
      _ticketsAbiertos = 0;
    } finally {
      _safeNotify();
    }
  }

  Future<void> eliminarBorrador(String id) async {
    // 1. Buscamos el borrador en la lista en memoria para saber qué es
    final borrador = borradores.firstWhere(
      (b) => b['id'] == id,
      orElse: () => {},
    );

    if (borrador.isNotEmpty) {
      final tipoLabel = borrador['tipo_actividad_label']?.toString() ?? '';
      final esVisita =
          borrador['tipo_actividad'] == 'Visita Técnica' ||
          tipoLabel == 'Visita Tecnica';
      final esExtintor = tipoLabel == 'Inspección Extintores';

      if (esExtintor) {
        await _extintorRepo.eliminarBorrador(id);
      } else if (esVisita) {
        await _visitRepo.eliminarBorrador(id);
      } else {
        await _localRepo.eliminarBorrador(id);
      }

      // 3. Disparamos la sincronización en background para limpiar Supabase
      _syncService.sincronizarTodo().catchError(
        (e) => debugPrint("Sync error: $e"),
      );
    }

    // 4. Refrescamos la UI
    await cargarBorradores();
  }

  // --- LÓGICA DE PERFIL (100% OFFLINE FIRST / SSOT) ---
  Future<void> _cargarPerfil() async {
    if (user == null) {
      nombreUsuario = 'Usuario';
      _isAdminUser = false; // Seguridad por defecto
      _safeNotify();
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;

      // Query ultra-rápida y directa a SQLite. Nada de JOINs.
      final List<Map<String, dynamic>> localUser = await db.query(
        'usuarios',
        columns: ['nombre_completo', 'nombre_rol'],
        where: 'id = ?',
        whereArgs: [user!.id],
        limit: 1,
      );

      if (localUser.isNotEmpty) {
        final userData = localUser.first;

        // 1. Asignar Nombre
        nombreUsuario =
            userData['nombre_completo'] ??
            user!.userMetadata?['nombre_completo'] ??
            user!.email ??
            'Usuario';

        // 2. Asignar Rol (Normalizamos a minúsculas y sin espacios extra para evitar errores tontos de tipeo en BD)
        final String nombreRol = (userData['nombre_rol']?.toString() ?? '')
            .toLowerCase()
            .trim();

        // 3. Validación de permisos
        _isAdminUser = (nombreRol == 'administrador' || nombreRol == 'admin');

        debugPrint(
          '👤 Perfil cargado (Offline): $nombreUsuario | Admin: $_isAdminUser ($nombreRol)',
        );
      } else {
        // Fallback si SQLite no tiene al usuario aún (ej. app recién instalada y sync en proceso)
        nombreUsuario =
            user!.userMetadata?['nombre_completo'] ?? user!.email ?? 'Usuario';
        _isAdminUser = false;
      }
    } catch (e) {
      debugPrint("⚠️ Error leyendo perfil desde SQLite: $e");
      nombreUsuario = user!.email ?? 'Usuario';
      _isAdminUser = false; // Ante la duda, se bloquea el acceso
    } finally {
      _safeNotify();
    }
  }

  // --- SINCRONIZACIÓN ---
  Future<void> _sincronizarSilencioso() async {
    if (!isOnline) {
      debugPrint("📴 Sin conexión, omitiendo sync silencioso");
      return;
    }

    isSyncing = true;
    _safeNotify();

    try {
      // 1. Subir pendientes silenciosamente
      final subidos = await _syncService.sincronizarTodo();
      if (subidos > 0) {
        debugPrint("✅ Sync silencioso: $subidos registros subidos");
        await cargarBorradores(); // Actualizar lista si se subieron borradores
      }

      // 2. Descargar datos maestros
      await _syncService.descargarDatosMaestros();
    } catch (e) {
      debugPrint("⚠️ Error en sync silencioso: $e");
    } finally {
      isSyncing = false;
      _safeNotify();
    }
  }

  Future<void> ejecutarSincronizacion() async {
    if (isSyncing) return;

    isSyncing = true;
    syncMessage = "Sincronizando...";
    isError = false;
    _safeNotify();

    try {
      final subidos = await _syncService.sincronizarTodo();
      if (subidos > 0) {
        syncMessage = "✅ Se subieron $subidos registros.";
      } else {
        syncMessage = "👍 Todo sincronizado.";
      }

      await cargarBorradores(); // Refresca UI si se eliminaron zombies
      await cargarNotificacionesTickets(); // Refresca badge de tickets
      await _syncService.descargarDatosMaestros();
    } catch (e) {
      isError = true;
      syncMessage = "Error de red al sincronizar.";
    } finally {
      isSyncing = false;
      _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        syncMessage = null;
        _safeNotify();
      });
    }
  }

  Future<void> cerrarSesion(BuildContext context) async {
    try {
      // Limpiar caché local si fuera necesario en el futuro (opcional)
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint("❌ Error cerrando sesión: $e");
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
