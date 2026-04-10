import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/user_session.dart';

class AdminCrudController extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  bool _disposed = false;

  List<Map<String, dynamic>> areas = [];
  List<Map<String, dynamic>> centros = [];
  List<Map<String, dynamic>> contratistas = [];
  List<Map<String, dynamic>> embarcaciones = [];
  bool isLoading = true;

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
      return true;
    } catch (e) {
      debugPrint('Error editando centro: $e');
      return false;
    }
  }

  Future<bool> crearContratista(String nombre) async {
    try {
      final id = const Uuid().v4();
      await _db.insertContratista(id, nombre.trim());
      await _recargarTabla('contratistas');
      return true;
    } catch (e) {
      debugPrint('Error creando contratista: $e');
      return false;
    }
  }

  Future<bool> editarContratista(String id, String nombre) async {
    try {
      final db = await _db.database;
      await db.update(
        'contratistas',
        {'nombre': nombre.trim(), 'subido': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _recargarTabla('contratistas');
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
      return true;
    } catch (e) {
      debugPrint('Error editando embarcacion: $e');
      return false;
    }
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
