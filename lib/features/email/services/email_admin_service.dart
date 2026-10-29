import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';

class EmailAdminService {
  final _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final db = await _dbHelper.database;
    return db.query('correo_plantillas', orderBy: 'updated_at DESC');
  }

  Future<void> upsertTemplate({
    String? id,
    required String nombre,
    required String asuntoTemplate,
    required String cuerpoTemplate,
    required String modulo,
    String? empresaId,
    String variablesPermitidas = '',
    bool activo = true,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final templateId = (id == null || id.isEmpty) ? _uuid.v4() : id;

    await db.insert('correo_plantillas', {
      'id': templateId,
      'nombre': nombre.trim(),
      'asunto_template': asuntoTemplate,
      'cuerpo_template': cuerpoTemplate,
      'modulo': modulo.trim().toLowerCase(),
      'empresa_id': (empresaId == null || empresaId.trim().isEmpty)
          ? null
          : empresaId.trim(),
      'variables_permitidas': variablesPermitidas.trim(),
      'activo': activo ? 1 : 0,
      'version': 1,
      'created_at': now,
      'updated_at': now,
      'updated_by': 'app_admin',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getLists() async {
    final db = await _dbHelper.database;
    return db.query('correo_listas', orderBy: 'updated_at DESC');
  }

  Future<void> upsertList({
    String? id,
    required String nombre,
    required String proposito,
    bool activo = true,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final listId = (id == null || id.isEmpty) ? _uuid.v4() : id;

    await db.insert('correo_listas', {
      'id': listId,
      'nombre': nombre.trim(),
      'proposito': proposito.trim(),
      'activo': activo ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getRecipientsByList(String listaId) async {
    final db = await _dbHelper.database;
    return db.query(
      'correo_lista_destinatarios',
      where: 'lista_id = ?',
      whereArgs: [listaId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> upsertRecipient({
    String? id,
    required String listaId,
    required String nombre,
    required String correo,
    String tipoSugerido = 'to',
    bool activo = true,
  }) async {
    final db = await _dbHelper.database;
    final recId = (id == null || id.isEmpty) ? _uuid.v4() : id;
    String targetListId = listaId;

    if (id != null && id.isNotEmpty) {
      // En edición conservamos la lista original para evitar mover
      // destinatarios por errores de estado/UI.
      final existing = await db.query(
        'correo_lista_destinatarios',
        columns: ['lista_id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        targetListId = (existing.first['lista_id'] ?? listaId).toString();
      }
    }

    await db.insert('correo_lista_destinatarios', {
      'id': recId,
      'lista_id': targetListId,
      'nombre': nombre.trim(),
      'correo': correo.trim(),
      'tipo_sugerido': tipoSugerido,
      'activo': activo ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRecipient(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'correo_lista_destinatarios',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getConfigs() async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT c.*, p.nombre AS template_nombre, l.nombre AS lista_nombre
      FROM correo_configuracion c
      LEFT JOIN correo_plantillas p ON p.id = c.plantilla_id
      LEFT JOIN correo_listas l ON l.id = c.lista_id
      ORDER BY c.updated_at DESC
    ''');
  }

  Future<void> upsertConfig({
    String? id,
    required String modulo,
    required String plantillaId,
    required String listaId,
    String? empresaId,
    int prioridad = 0,
    bool activo = true,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final cfgId = (id == null || id.isEmpty) ? _uuid.v4() : id;

    await db.insert('correo_configuracion', {
      'id': cfgId,
      'empresa_id': (empresaId == null || empresaId.trim().isEmpty)
          ? null
          : empresaId.trim(),
      'modulo': modulo.trim().toLowerCase(),
      'plantilla_id': plantillaId,
      'lista_id': listaId,
      'prioridad': prioridad,
      'activo': activo ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await _dbHelper.database;
    return db.query('usuarios', orderBy: 'nombre_completo ASC');
  }

  Future<List<Map<String, dynamic>>> getEmpresas() async {
    final db = await _dbHelper.database;
    return db.query('empresas', orderBy: 'nombre ASC');
  }

  Future<List<Map<String, dynamic>>> getAssignments() async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT a.*, u.nombre_completo, u.email,
             c.modulo, l.nombre AS lista_nombre
      FROM correo_usuario_asignacion a
      LEFT JOIN usuarios u ON u.id = a.usuario_id
      LEFT JOIN correo_configuracion c ON c.id = a.config_id
      LEFT JOIN correo_listas l ON l.id = a.lista_id
      ORDER BY a.updated_at DESC
    ''');
  }

  Future<void> upsertAssignment({
    String? id,
    required String usuarioId,
    String? configId,
    String? listaId,
    bool activo = true,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final asgId = (id == null || id.isEmpty) ? _uuid.v4() : id;

    await db.insert('correo_usuario_asignacion', {
      'id': asgId,
      'usuario_id': usuarioId,
      'config_id': (configId == null || configId.trim().isEmpty)
          ? null
          : configId,
      'lista_id': (listaId == null || listaId.trim().isEmpty) ? null : listaId,
      'activo': activo ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteById(String table, String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (table == 'correo_listas') {
        await txn.delete(
          'correo_lista_destinatarios',
          where: 'lista_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'correo_usuario_asignacion',
          where:
              'lista_id = ? OR config_id IN (SELECT id FROM correo_configuracion WHERE lista_id = ?)',
          whereArgs: [id, id],
        );
        await txn.delete(
          'correo_configuracion',
          where: 'lista_id = ?',
          whereArgs: [id],
        );
      } else if (table == 'correo_plantillas') {
        await txn.delete(
          'correo_usuario_asignacion',
          where:
              'config_id IN (SELECT id FROM correo_configuracion WHERE plantilla_id = ?)',
          whereArgs: [id],
        );
        await txn.delete(
          'correo_configuracion',
          where: 'plantilla_id = ?',
          whereArgs: [id],
        );
      } else if (table == 'correo_configuracion') {
        await txn.delete(
          'correo_usuario_asignacion',
          where: 'config_id = ?',
          whereArgs: [id],
        );
      }

      await txn.delete(table, where: 'id = ?', whereArgs: [id]);
    });
  }
}
