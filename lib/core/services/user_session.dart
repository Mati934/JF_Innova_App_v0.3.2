import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Singleton que mantiene el perfil del usuario logueado en memoria.
/// Soporta multi-empresa: un usuario puede pertenecer a varias empresas.
class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? _userId;
  String? _nombreCompleto;
  String? _nombreRol;
  String? _email;

  // Multi-empresa
  List<EmpresaUsuario> _empresas = [];
  String? _currentEmpresaId;
  bool _empresaAdministradora = false;

  String? get userId => _userId;
  String? get nombreCompleto => _nombreCompleto;
  String? get nombreRol => _nombreRol;
  String? get email => _email;

  /// La empresa actualmente seleccionada.
  String? get empresaId => _currentEmpresaId;

  /// Todas las empresas a las que tiene acceso el usuario.
  List<EmpresaUsuario> get empresas => List.unmodifiable(_empresas);

  /// Nombre de la empresa activa (para mostrar en UI).
  String? get empresaNombre {
    if (_currentEmpresaId == null) return null;
    try {
      return _empresas.firstWhere((e) => e.id == _currentEmpresaId).nombre;
    } catch (_) {
      return null;
    }
  }

  /// true si el usuario tiene acceso a más de una empresa.
  bool get tieneMultiEmpresa => _empresas.length > 1;

  bool get isLoaded => _userId != null;

  bool get esAdmin {
    final rol = (_nombreRol ?? '').toLowerCase().trim();
    return rol == 'administrador' || rol == 'admin';
  }

  /// true si el usuario es admin Y su empresa activa es administradora (ej: Servimaf).
  bool get esSuperAdmin => esAdmin && _empresaAdministradora;

  /// Carga el perfil del usuario desde SQLite.
  Future<void> loadFromSQLite(String authUserId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [authUserId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final data = rows.first;
      _userId = authUserId;
      _nombreCompleto = data['nombre_completo'] as String?;
      _nombreRol = data['nombre_rol'] as String?;
      _email = data['email'] as String?;

      // Cargar empresas del usuario
      await _cargarEmpresas(authUserId);

      debugPrint(
        '👤 UserSession cargado: $_nombreCompleto | '
        'empresas: ${_empresas.map((e) => e.nombre).toList()} | '
        'activa: $empresaNombre | admin: $esAdmin',
      );
    } else {
      _userId = authUserId;
      debugPrint('⚠️ UserSession: usuario $authUserId no encontrado en SQLite');
    }
  }

  Future<void> _cargarEmpresas(String userId) async {
    final db = await DatabaseHelper.instance.database;

    // Cargar desde tabla usuario_empresas (JOIN con empresas)
    final rows = await db.rawQuery(
      '''
      SELECT ue.empresa_id, e.nombre, e.es_administradora
      FROM usuario_empresas ue
      INNER JOIN empresas e ON e.id = ue.empresa_id
      WHERE ue.usuario_id = ?
      ORDER BY e.nombre
    ''',
      [userId],
    );

    if (rows.isNotEmpty) {
      _empresas = rows
          .map(
            (r) => EmpresaUsuario(
              id: r['empresa_id'] as String,
              nombre: r['nombre'] as String? ?? 'Sin nombre',
              esAdministradora: (r['es_administradora'] as int?) == 1,
            ),
          )
          .toList();

      // Si no hay empresa seleccionada, seleccionar la primera
      if (_currentEmpresaId == null ||
          !_empresas.any((e) => e.id == _currentEmpresaId)) {
        _currentEmpresaId = _empresas.first.id;
      }
      _actualizarFlagAdministradora();
    } else {
      // Fallback: usar empresa_id de la tabla usuarios (legacy)
      final userRows = await db.query(
        'usuarios',
        columns: ['empresa_id'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (userRows.isNotEmpty) {
        final legacyEmpresaId = userRows.first['empresa_id'] as String?;
        if (legacyEmpresaId != null) {
          // Buscar nombre y flag de la empresa
          final empresaRows = await db.query(
            'empresas',
            where: 'id = ?',
            whereArgs: [legacyEmpresaId],
            limit: 1,
          );
          final nombre = empresaRows.isNotEmpty
              ? empresaRows.first['nombre'] as String? ?? 'Sin nombre'
              : 'Sin nombre';
          final esAdmin = empresaRows.isNotEmpty
              ? (empresaRows.first['es_administradora'] as int?) == 1
              : false;
          _empresas = [
            EmpresaUsuario(
              id: legacyEmpresaId,
              nombre: nombre,
              esAdministradora: esAdmin,
            ),
          ];
          _currentEmpresaId = legacyEmpresaId;
          _actualizarFlagAdministradora();
        }
      }
    }
  }

  void _actualizarFlagAdministradora() {
    try {
      final empresa = _empresas.firstWhere((e) => e.id == _currentEmpresaId);
      _empresaAdministradora = empresa.esAdministradora;
    } catch (_) {
      _empresaAdministradora = false;
    }
  }

  /// Cambia la empresa activa. Retorna true si cambió.
  bool cambiarEmpresa(String empresaId) {
    if (_empresas.any((e) => e.id == empresaId)) {
      _currentEmpresaId = empresaId;
      _actualizarFlagAdministradora();
      debugPrint(
        '🏢 Empresa cambiada a: $empresaNombre (superAdmin: $esSuperAdmin)',
      );
      return true;
    }
    return false;
  }

  /// Limpia la sesión al cerrar sesión.
  void clear() {
    _userId = null;
    _nombreCompleto = null;
    _nombreRol = null;
    _email = null;
    _empresas = [];
    _currentEmpresaId = null;
    _empresaAdministradora = false;
    debugPrint('🧹 UserSession limpiado');
  }
}

class EmpresaUsuario {
  final String id;
  final String nombre;
  final bool esAdministradora;

  const EmpresaUsuario({
    required this.id,
    required this.nombre,
    this.esAdministradora = false,
  });
}
