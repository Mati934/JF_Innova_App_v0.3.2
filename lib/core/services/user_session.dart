import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Singleton que mantiene el perfil del usuario logueado en memoria.
/// Se carga una vez al login y se limpia al cerrar sesión.
class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? _userId;
  String? _empresaId;
  String? _nombreCompleto;
  String? _nombreRol;
  String? _email;

  String? get userId => _userId;
  String? get empresaId => _empresaId;
  String? get nombreCompleto => _nombreCompleto;
  String? get nombreRol => _nombreRol;
  String? get email => _email;

  bool get isLoaded => _userId != null;

  bool get esAdmin {
    final rol = (_nombreRol ?? '').toLowerCase().trim();
    return rol == 'administrador' || rol == 'admin';
  }

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
      _empresaId = data['empresa_id'] as String?;
      _nombreCompleto = data['nombre_completo'] as String?;
      _nombreRol = data['nombre_rol'] as String?;
      _email = data['email'] as String?;
      debugPrint(
        '👤 UserSession cargado: $_nombreCompleto | empresa: $_empresaId | admin: $esAdmin',
      );
    } else {
      _userId = authUserId;
      debugPrint('⚠️ UserSession: usuario $authUserId no encontrado en SQLite');
    }
  }

  /// Limpia la sesión al cerrar sesión.
  void clear() {
    _userId = null;
    _empresaId = null;
    _nombreCompleto = null;
    _nombreRol = null;
    _email = null;
    debugPrint('🧹 UserSession limpiado');
  }
}
