import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../sync/services/sync_service.dart';
import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../../core/database/database_helper.dart';

class HomeController extends ChangeNotifier {
  final _syncService = SyncService();
  final _localRepo = LocalInspectionRepository();

  final User? user = Supabase.instance.client.auth.currentUser;

  String nombreUsuario = 'Cargando...';

  // Variables de Sincronización
  bool isSyncing = false;
  String? syncMessage;
  bool isError = false;

  // Variables de Borradores
  List<Map<String, dynamic>> borradores = [];
  bool isLoadingBorradores = true;

  HomeController() {
    _inicializarDatos();
  }

  Future<void> _inicializarDatos() async {
    await _cargarPerfil(); // 100% Offline
    await cargarBorradores();
    _sincronizarSilencioso(); // Background sync para maestros y subidas
  }

  // --- LÓGICA DE BORRADORES ---
  Future<void> cargarBorradores() async {
    isLoadingBorradores = true;
    notifyListeners();

    try {
      borradores = await _localRepo.getBorradores();
    } catch (e) {
      debugPrint("❌ Error cargando borradores: $e");
      borradores = [];
    } finally {
      isLoadingBorradores = false;
      notifyListeners();
    }
  }

  Future<void> eliminarBorrador(String id) async {
    await _localRepo.eliminarBorrador(id);
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
