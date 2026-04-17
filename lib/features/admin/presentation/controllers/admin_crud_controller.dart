import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/user_session.dart';
import '../../../sync/services/sync_service.dart';

class AdminCrudController extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _syncService = SyncService();
  bool _disposed = false;

  List<Map<String, dynamic>> areas = [];
  List<Map<String, dynamic>> centros = [];
  List<Map<String, dynamic>> contratistas = [];
  List<Map<String, dynamic>> embarcaciones = [];
  bool isLoading = true;
  String? lastSyncError;
  bool isSyncing = false;

  // O(1) lookup caches
  Map<String, String> _areaNombreCache = {};
  Map<String, String> _contratistaNombreCache = {};

  AdminCrudController() {
    cargarCatalogos();
  }

  void _rebuildCaches() {
    _areaNombreCache = {
      for (var a in areas) a['id'] as String: a['nombre'] as String? ?? '',
    };
    _contratistaNombreCache = {
      for (var c in contratistas)
        c['id'] as String: c['nombre'] as String? ?? '',
    };
  }

  Future<void> cargarCatalogos() async {
    isLoading = true;
    _safeNotify();

    try {
      final empresaId = UserSession().empresaId;
      final results = await Future.wait([
        empresaId != null ? _db.getAreasByEmpresa(empresaId) : _db.getAreas(),
        _db.getAllCentros(),
        _db.getContratistas(),
        _db.getAllEmbarcaciones(),
      ]);
      final areasResult = results[0];
      // Fallback: si empresa_areas no tiene datos aún, cargar todas
      areas = areasResult.isNotEmpty ? areasResult : await _db.getAreas();
      centros = results[1];
      contratistas = results[2];
      embarcaciones = results[3];
      _rebuildCaches();
    } catch (e) {
      debugPrint('Error cargando catalogos admin: $e');
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  /// Reload only the specific table that changed + its dependents.
  Future<void> _recargarTabla(String tabla) async {
    try {
      final empresaId = UserSession().empresaId;
      switch (tabla) {
        case 'centros':
          centros = await _db.getAllCentros();
          break;
        case 'contratistas':
          contratistas = await _db.getContratistas();
          _contratistaNombreCache = {
            for (var c in contratistas)
              c['id'] as String: c['nombre'] as String? ?? '',
          };
          break;
        case 'embarcaciones':
          embarcaciones = await _db.getAllEmbarcaciones();
          break;
        case 'areas':
          final filtered = empresaId != null
              ? await _db.getAreasByEmpresa(empresaId)
              : await _db.getAreas();
          areas = filtered.isNotEmpty ? filtered : await _db.getAreas();
          _areaNombreCache = {
            for (var a in areas)
              a['id'] as String: a['nombre'] as String? ?? '',
          };
          break;
      }
      _safeNotify();
    } catch (e) {
      debugPrint('Error recargando $tabla: $e');
    }
  }

  Future<bool> crearCentro(String nombre, String areaId) async {
    try {
      final id = const Uuid().v4();
      await _db.insertCentro(id, nombre.trim(), areaId);
      await _recargarTabla('centros');
      _syncMaestrosPendientes();
      return true;
    } catch (e) {
      debugPrint('Error creando centro: $e');
      return false;
    }
  }

  Future<bool> editarCentro(String id, String nombre, String areaId) async {
    try {
      final db = await _db.database;
      await db.update(
        'centros',
        {'nombre': nombre.trim(), 'area_id': areaId, 'subido': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _recargarTabla('centros');
      _syncMaestrosPendientes();
      return true;
    } catch (e) {
      debugPrint('Error editando centro: $e');
      return false;
    }
  }

  Future<bool> crearContratista(String nombre, {String? rut}) async {
    try {
      final id = const Uuid().v4();
      // Si no se proporciona RUT, generar placeholder
      final rutFinal = (rut != null && rut.trim().isNotEmpty)
          ? rut.trim()
          : 'PENDIENTE-${id.substring(0, 8)}';
      debugPrint(
        '🔍 DEBUG-SYNC [1/4] Creando contratista: id=$id, nombre="${nombre.trim()}", rut="$rutFinal"',
      );
      await _db.insertContratista(id, nombre.trim(), rutFinal);
      debugPrint('🔍 DEBUG-SYNC [2/4] Insertado en SQLite con subido=0');
      await _recargarTabla('contratistas');
      debugPrint('🔍 DEBUG-SYNC [3/4] Tabla recargada. Disparando sync...');
      _syncMaestrosPendientes();
      debugPrint('🔍 DEBUG-SYNC [4/4] Sync disparado (async)');
      return true;
    } catch (e) {
      debugPrint('🔍 DEBUG-SYNC ❌ Error creando contratista: $e');
      return false;
    }
  }

  Future<bool> editarContratista(String id, String nombre, {String? rut}) async {
    try {
      final db = await _db.database;
      final updateMap = <String, dynamic>{
        'nombre': nombre.trim(),
        'subido': 0,
      };
      if (rut != null && rut.trim().isNotEmpty) {
        updateMap['rut'] = rut.trim();
      }
      await db.update(
        'contratistas',
        updateMap,
        where: 'id = ?',
        whereArgs: [id],
      );
      await _recargarTabla('contratistas');
      _syncMaestrosPendientes();
      return true;
    } catch (e) {
      debugPrint('Error editando contratista: $e');
      return false;
    }
  }

  Future<bool> crearEmbarcacion(
    String nombre,
    String contratistaId,
    String? matricula,
  ) async {
    try {
      final id = const Uuid().v4();
      await _db.insertEmbarcacion(
        id,
        nombre.trim(),
        contratistaId,
        matricula?.trim(),
      );
      await _recargarTabla('embarcaciones');
      _syncMaestrosPendientes();
      return true;
    } catch (e) {
      debugPrint('Error creando embarcacion: $e');
      return false;
    }
  }

  Future<bool> editarEmbarcacion(
    String id,
    String nombre,
    String contratistaId,
    String? matricula,
  ) async {
    try {
      final db = await _db.database;
      await db.update(
        'embarcaciones',
        {
          'nombre': nombre.trim(),
          'contratista_id': contratistaId,
          'matricula': matricula?.trim(),
          'subido': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _recargarTabla('embarcaciones');
      _syncMaestrosPendientes();
      return true;
    } catch (e) {
      debugPrint('Error editando embarcacion: $e');
      return false;
    }
  }

  /// Sync de datos maestros pendientes con feedback al usuario.
  void _syncMaestrosPendientes() {
    isSyncing = true;
    lastSyncError = null;
    _safeNotify();
    debugPrint('🔍 DEBUG-SYNC [SYNC] Iniciando sincronizarMaestros()...');

    _syncService
        .sincronizarMaestros()
        .then((resultados) {
          debugPrint('🔍 DEBUG-SYNC [SYNC] Resultados recibidos:');
          for (final entry in resultados.entries) {
            debugPrint(
              '🔍 DEBUG-SYNC   ${entry.key}: exitosos=${entry.value.exitosos}, fallidos=${entry.value.fallidos}${entry.value.ultimoError != null ? ", error=${entry.value.ultimoError}" : ""}',
            );
          }

          final fallidos = <String>[];
          String? errorDetalle;
          for (final entry in resultados.entries) {
            if (entry.value.fallidos > 0) {
              fallidos.add(entry.key);
              errorDetalle ??= entry.value.ultimoError;
            }
          }
          if (fallidos.isNotEmpty) {
            lastSyncError =
                'Error al sincronizar: ${fallidos.join(", ")}. ${_mensajeSyncAmigable(errorDetalle)}';
            debugPrint('🔍 DEBUG-SYNC [SYNC] ❌ lastSyncError=$lastSyncError');
          } else {
            lastSyncError = null;
            debugPrint(
              '🔍 DEBUG-SYNC [SYNC] ✅ Todo sincronizado correctamente',
            );
          }
          isSyncing = false;
          _safeNotify();
        })
        .catchError((e) {
          lastSyncError =
              'Error de sincronización: ${_mensajeSyncAmigable(e.toString())}';
          isSyncing = false;
          _safeNotify();
          debugPrint('🔍 DEBUG-SYNC [SYNC] ❌ catchError: $e');
        });
  }

  /// Reintentar sincronización de datos maestros pendientes.
  void retrySyncMaestros() {
    _syncMaestrosPendientes();
  }

  /// Eliminar un registro de datos maestros (local + Supabase).
  Future<bool> eliminarRegistro(String tabla, String id) async {
    try {
      final db = await _db.database;
      // Eliminar en Supabase primero
      try {
        await _syncService.eliminarMaestro(tabla, id);
        debugPrint('🔍 DEBUG-SYNC [eliminar] $tabla/$id eliminado de Supabase');
      } catch (e) {
        debugPrint('🔍 DEBUG-SYNC [eliminar] $tabla/$id error Supabase: $e');
        // Si falla en Supabase (ej: sin conexión), igual borramos local
      }
      // Eliminar local
      await db.delete(tabla, where: 'id = ?', whereArgs: [id]);
      await _recargarTabla(tabla);
      return true;
    } catch (e) {
      debugPrint('Error eliminando $tabla/$id: $e');
      return false;
    }
  }

  String _mensajeSyncAmigable(String? error) {
    if (error == null) return 'Inténtelo de nuevo.';
    final msg = error.toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('timeout')) {
      return 'Sin conexión a internet.';
    }
    if (msg.contains('permission') ||
        msg.contains('rls') ||
        msg.contains('policy')) {
      return 'Sin permisos en el servidor.';
    }
    if (msg.contains('duplicate') || msg.contains('unique')) {
      return 'Registro duplicado en el servidor.';
    }
    return 'Inténtelo de nuevo.';
  }

  String? getAreaNombre(String areaId) => _areaNombreCache[areaId];

  String? getContratistaNombre(String contratistaId) =>
      _contratistaNombreCache[contratistaId];

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
