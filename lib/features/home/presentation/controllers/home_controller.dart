import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../sync/services/sync_service.dart';
// Importamos el repositorio local
import '../../../inspection/data/repositories/local_inspection_repository.dart';

class HomeController extends ChangeNotifier {
  final _syncService = SyncService();
  final _localRepo = LocalInspectionRepository(); // Instancia del repo local

  final User? user = Supabase.instance.client.auth.currentUser;

  String nombreUsuario = 'Cargando...';

  // Variables de Sincronización
  bool isSyncing = false;
  String? syncMessage;
  bool isError = false;

  // Variables de Borradores (NUEVO)
  List<Map<String, dynamic>> borradores = [];
  bool isLoadingBorradores = true;

  HomeController() {
    _cargarPerfil();
    _sincronizarSilencioso();
    cargarBorradores(); // Cargamos borradores al iniciar
  }

  // --- LÓGICA DE BORRADORES (NUEVO) ---

  Future<void> cargarBorradores() async {
    isLoadingBorradores = true;
    notifyListeners(); // Notifica a la UI para mostrar spinner

    try {
      borradores = await _localRepo.getBorradores();
    } catch (e) {
      debugPrint("❌ Error cargando borradores en controller: $e");
      borradores = [];
    } finally {
      isLoadingBorradores = false;
      notifyListeners(); // Notifica a la UI para mostrar la lista
    }
  }

  Future<void> eliminarBorrador(String id) async {
    await _localRepo.eliminarBorrador(id);
    await cargarBorradores(); // Recargamos la lista automáticamente
  }

  // --- LÓGICA DE USUARIO Y SYNC (EXISTENTE) ---

  Future<void> _cargarPerfil() async {
    if (user == null) {
      nombreUsuario = 'Usuario';
      notifyListeners();
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('usuarios')
          .select('nombre_completo')
          .eq('id', user!.id)
          .single()
          .timeout(const Duration(seconds: 2));

      nombreUsuario = data['nombre_completo'] ?? user!.email;
    } catch (e) {
      nombreUsuario = user!.email ?? 'Usuario';
    } finally {
      notifyListeners();
    }
  }

  Future<void> _sincronizarSilencioso() async {
    isSyncing = true;
    notifyListeners();
    await _syncService.descargarDatosMaestros();
    isSyncing = false;
    notifyListeners();
  }

  Future<void> ejecutarSincronizacion() async {
    if (isSyncing) return;

    isSyncing = true;
    syncMessage = "Conectando...";
    isError = false;
    notifyListeners();

    try {
      final subidos = await _syncService.sincronizarTodo();
      if (subidos > 0) {
        syncMessage = "✅ Se subieron $subidos registros.";
      } else {
        syncMessage = "👍 Todo sincronizado.";
      }
      // Al terminar de sincronizar, recargamos borradores por si algo cambió
      await cargarBorradores();
    } catch (e) {
      isError = true;
      syncMessage = "Error de conexión.";
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
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint("Error cerrando sesión: $e");
    }
  }
}
