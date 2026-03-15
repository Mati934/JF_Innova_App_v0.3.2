import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../sync/services/sync_service.dart';
import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../visits/data/repositories/local_visit_repository.dart';
import '../../../tickets/data/repositories/local_ticket_repository.dart';

class HomeController extends ChangeNotifier {
  final _syncService = SyncService();
  final _localRepo = LocalInspectionRepository();
  final _visitRepo = LocalVisitRepository();
  final _ticketRepo = LocalTicketRepository();

  final User? user = Supabase.instance.client.auth.currentUser;

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

  HomeController() {
    _inicializarDatos();
  }

  Future<void> _inicializarDatos() async {
    await _cargarPerfil(); // 100% Offline
    await Future.wait([cargarBorradores(), cargarNotificacionesTickets()]);
    _sincronizarSilencioso(); // Background sync para maestros y subidas
  }

  // --- LÓGICA DE BORRADORES ---
  Future<void> cargarBorradores() async {
    isLoadingBorradores = true;
    notifyListeners();

    try {
      // CLEAN CODE: Ejecución en paralelo (Concurrencia)
      // Disparamos ambas queries a SQLite al mismo tiempo.
      final resultados = await Future.wait([
        _localRepo.getBorradores(),
        _visitRepo.getBorradores(),
      ]);

      final inspecciones = resultados[0];
      final visitas =
          resultados[1]; // Ya vienen normalizadas desde el Repositorio

      // Fusionamos
      borradores = [...inspecciones, ...visitas];

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
      notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> eliminarBorrador(String id) async {
    // 1. Buscamos el borrador en la lista en memoria para saber qué es
    final borrador = borradores.firstWhere(
      (b) => b['id'] == id,
      orElse: () => {},
    );

    if (borrador.isNotEmpty) {
      final esVisita = borrador['tipo_actividad'] == 'Visita Técnica';

      // 2. Enrutamos la orden de eliminación al repositorio correcto
      if (esVisita) {
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
      notifyListeners();
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> localUser = await db.query(
        'usuarios',
        columns: ['nombre_completo'],
        where: 'id = ?',
        whereArgs: [user!.id],
        limit: 1,
      );

      if (localUser.isNotEmpty && localUser.first['nombre_completo'] != null) {
        nombreUsuario = localUser.first['nombre_completo'];
      } else {
        // Fallback al token si algo rarísimo pasó y SQLite falló
        nombreUsuario =
            user!.userMetadata?['nombre_completo'] ?? user!.email ?? 'Usuario';
      }
    } catch (e) {
      debugPrint("⚠️ Error leyendo perfil desde SQLite: $e");
      nombreUsuario = user!.email ?? 'Usuario';
    } finally {
      notifyListeners();
    }
  }

  // --- SINCRONIZACIÓN ---
  Future<void> _sincronizarSilencioso() async {
    isSyncing = true;
    notifyListeners();

    // Solo descarga áreas, barcos, contratistas. YA NO TOCA AL USUARIO.
    await _syncService.descargarDatosMaestros();

    isSyncing = false;
    notifyListeners();
  }

  Future<void> ejecutarSincronizacion() async {
    if (isSyncing) return;

    isSyncing = true;
    syncMessage = "Sincronizando...";
    isError = false;
    notifyListeners();

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
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        syncMessage = null;
        notifyListeners();
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
}
