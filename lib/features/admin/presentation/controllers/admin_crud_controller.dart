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

  AdminCrudController() {
    cargarCatalogos();
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
      areas = results[0];
      centros = results[1];
      contratistas = results[2];
      embarcaciones = results[3];
    } catch (e) {
      debugPrint('❌ Error cargando catálogos admin: $e');
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<bool> crearCentro(String nombre, String areaId) async {
    try {
      final id = const Uuid().v4();
      await _db.insertCentro(id, nombre.trim(), areaId);
      await cargarCatalogos();
      return true;
    } catch (e) {
      debugPrint('❌ Error creando centro: $e');
      return false;
    }
  }

  Future<bool> editarCentro(String id, String nombre, String areaId) async {
    try {
      final db = await _db.database;
      await db.update('centros', {
        'nombre': nombre.trim(),
        'area_id': areaId,
        'subido': 0,
      }, where: 'id = ?', whereArgs: [id]);
      await cargarCatalogos();
      return true;
    } catch (e) {
      debugPrint('❌ Error editando centro: $e');
      return false;
    }
  }

  Future<bool> crearContratista(String nombre) async {
    try {
      final id = const Uuid().v4();
      await _db.insertContratista(id, nombre.trim());
      await cargarCatalogos();
      return true;
    } catch (e) {
      debugPrint('❌ Error creando contratista: $e');
      return false;
    }
  }

  Future<bool> editarContratista(String id, String nombre) async {
    try {
      final db = await _db.database;
      await db.update('contratistas', {
        'nombre': nombre.trim(),
        'subido': 0,
      }, where: 'id = ?', whereArgs: [id]);
      await cargarCatalogos();
      return true;
    } catch (e) {
      debugPrint('❌ Error editando contratista: $e');
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
      await cargarCatalogos();
      return true;
    } catch (e) {
      debugPrint('❌ Error creando embarcación: $e');
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
      await db.update('embarcaciones', {
        'nombre': nombre.trim(),
        'contratista_id': contratistaId,
        'matricula': matricula?.trim(),
        'subido': 0,
      }, where: 'id = ?', whereArgs: [id]);
      await cargarCatalogos();
      return true;
    } catch (e) {
      debugPrint('❌ Error editando embarcación: $e');
      return false;
    }
  }

  String? getAreaNombre(String areaId) {
    try {
      return areas.firstWhere((a) => a['id'] == areaId)['nombre'] as String?;
    } catch (_) {
      return null;
    }
  }

  String? getContratistaNombre(String contratistaId) {
    try {
      return contratistas.firstWhere((c) => c['id'] == contratistaId)['nombre']
          as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
