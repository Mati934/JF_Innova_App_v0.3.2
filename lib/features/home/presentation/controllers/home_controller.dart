import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../sync/services/sync_service.dart';
import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/user_session.dart';
import '../../../../core/modules/module_registry.dart';
import '../../../visits/data/repositories/local_visit_repository.dart';
import '../../../extintores/data/repositories/local_extintor_repository.dart';
import '../../../hidroser/data/repositories/local_hidroser_repository.dart';
import '../../../buceo_equipment/data/repositories/local_buceo_equipment_repository.dart';
import '../../../prosesso/data/repositories/local_prosesso_repository.dart';
import '../../domain/draft_card_data.dart';
import '../../domain/draft_card_mapper.dart';

class HomeController extends ChangeNotifier {
  final _syncService = SyncService();
  final _localRepo = LocalInspectionRepository();
  final _visitRepo = LocalVisitRepository();
  final _extintorRepo = LocalExtintorRepository();
  final _hidroserRepo = LocalHidroserRepository();
  final _buceoRepo = LocalBuceoEquipmentRepository();
  final _prosessoRepo = LocalProsessoRepository();
  final _connectivity = ConnectivityService();

  final User? user = Supabase.instance.client.auth.currentUser;

  bool _isAdminUser = false;
  bool _disposed = false;

  bool get esAdmin => _isAdminUser;

  String nombreUsuario = 'Cargando...';

  // Módulos habilitados para la empresa del usuario
  List<String> _enabledModuleKeys = [];

  List<ModuleDefinition> get enabledModules {
    return ModuleRegistry.all.where((m) {
      // Admin Maestros solo visible para SuperAdmin (admin + empresa administradora)
      if (m.requiresAdmin) return UserSession().esSuperAdmin;
      return _enabledModuleKeys.contains(m.moduleKey);
    }).toList();
  }

  // Variables de Sincronización
  bool isSyncing = false;
  String? syncMessage;
  bool isError = false;

  // Variables de Borradores
  List<DraftCardData> borradores = [];
  bool isLoadingBorradores = true;

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
    await cargarBorradores();
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
        _prosessoRepo.getBorradores(),
        _hidroserRepo.getBorradores(),
        _buceoRepo.getBorradores(),
      ]);

      final inspecciones = resultados[0].map(DraftCardMapper.fromInspeccion);
      final visitas = resultados[1].map(DraftCardMapper.fromVisita);
      final extintores = resultados[2].map(DraftCardMapper.fromExtintor);
      final prosesso = resultados[3].map(DraftCardMapper.fromProsesso);
      final hidroser = resultados[4].map(DraftCardMapper.fromHidroser);
      final buceo = resultados[5].map(DraftCardMapper.fromBuceoEquipamiento);

      // Fusionamos y ordenamos por fecha (del más reciente al más antiguo)
      borradores = [
        ...inspecciones,
        ...visitas,
        ...extintores,
        ...prosesso,
        ...hidroser,
        ...buceo,
      ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    } catch (e) {
      debugPrint("❌ Error cargando borradores combinados: $e");
      borradores = [];
    } finally {
      isLoadingBorradores = false;
      _safeNotify();
    }
  }

  Future<void> eliminarBorrador(String id) async {
    // 1. Buscamos el borrador en la lista en memoria para saber qué es
    DraftCardData? borrador;
    for (final b in borradores) {
      if (b.id == id) {
        borrador = b;
        break;
      }
    }

    if (borrador != null) {
      switch (borrador.kind) {
        case DraftKind.inspeccionExtintores:
          await _extintorRepo.eliminarBorrador(id);
          break;
        case DraftKind.mantencionProsesso:
          await _prosessoRepo.eliminarBorrador(id);
          break;
        case DraftKind.hidroserGruaHorquilla:
          await _hidroserRepo.eliminarBorrador(id);
          break;
        case DraftKind.buceoEquipamiento:
          await _buceoRepo.eliminarBorrador(id);
          break;
        case DraftKind.visitaTecnica:
        case DraftKind.visitaChecklistElectricidad:
        case DraftKind.visitaChecklistPisos:
        case DraftKind.visitaChecklistOtro:
          await _visitRepo.eliminarBorrador(id);
          break;
        default:
          await _localRepo.eliminarBorrador(id);
      }

      // 3. Disparamos la sincronización en background para limpiar Supabase
      _syncService.sincronizarTodo().catchError((Object e) {
        debugPrint("Sync error: $e");
        return 0;
      });
    }

    // 4. Refrescamos la UI
    await cargarBorradores();
  }

  // --- LÓGICA DE PERFIL (100% OFFLINE FIRST / SSOT) ---
  Future<void> _cargarPerfil() async {
    if (user == null) {
      nombreUsuario = 'Usuario';
      _isAdminUser = false;
      _safeNotify();
      return;
    }

    try {
      // Cargar UserSession si aún no está cargado
      if (!UserSession().isLoaded) {
        await UserSession().loadFromSQLite(user!.id);
      }

      final session = UserSession();
      nombreUsuario = session.nombreCompleto ?? user!.email ?? 'Usuario';
      _isAdminUser = session.esAdmin;

      debugPrint(
        '👤 Perfil cargado via UserSession: $nombreUsuario | Admin: $_isAdminUser',
      );

      // Cargar módulos habilitados para la empresa
      await _cargarModulosHabilitados();
    } catch (e) {
      debugPrint("⚠️ Error leyendo perfil: $e");
      nombreUsuario = user!.email ?? 'Usuario';
      _isAdminUser = false;
      _enabledModuleKeys = List.from(ModuleRegistry.defaultModuleKeys);
    } finally {
      _safeNotify();
    }
  }

  Future<void> _cargarModulosHabilitados() async {
    final empresaId = UserSession().empresaId;
    if (empresaId == null) {
      _enabledModuleKeys = List.from(ModuleRegistry.defaultModuleKeys);
      return;
    }

    final rows = await DatabaseHelper.instance.getModulosHabilitados(empresaId);
    if (rows.isEmpty) {
      // Sin configuración → mostrar módulos default
      _enabledModuleKeys = List.from(ModuleRegistry.defaultModuleKeys);
    } else {
      // Filtrar solo los habilitados (rows ahora incluye todos, habilitados y no)
      _enabledModuleKeys = rows
          .where((r) => (r['habilitado'] as int) == 1)
          .map((r) => r['modulo_key'] as String)
          .toList();
    }
    debugPrint('📦 Módulos habilitados: $_enabledModuleKeys');
  }

  /// Recarga módulos habilitados desde SQLite (e.g. al volver del admin).
  Future<void> recargarModulos() async {
    await _cargarModulosHabilitados();
    _safeNotify();
  }

  /// Recarga módulos y borradores cuando el usuario cambia de empresa.
  Future<void> recargarParaEmpresa() async {
    await _cargarModulosHabilitados();
    await cargarBorradores();
    if (isOnline) {
      await _syncService.descargarDatosMaestros();
      await _cargarModulosHabilitados();
    }
    _safeNotify();
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
      await _cargarModulosHabilitados();
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
      await _syncService.descargarDatosMaestros();
      await _cargarModulosHabilitados();
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
      UserSession().clear();
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
