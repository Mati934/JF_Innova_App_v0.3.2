import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';

class EmailPendingService {
  Future<List<Map<String, dynamic>>> listPendings({String? estado}) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'correo_pendientes',
      where: estado == null ? null : 'estado = ?',
      whereArgs: estado == null ? null : [estado],
      orderBy: 'updated_at DESC',
    );
  }

  Map<String, dynamic> parsePayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> enqueuePending({
    required String registroId,
    required String moduleKey,
    required String? empresaId,
    required String? usuarioId,
    required String configId,
    required String? listaId,
    required String subject,
    required String body,
    required List<String> recipients,
    String estado = 'pendiente',
    String? attachmentPath,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    final payload = jsonEncode({
      'subject': subject,
      'body': body,
      'recipients': recipients,
      'attachment_path': attachmentPath,
    });

    await db.insert('correo_pendientes', {
      'id': '${moduleKey}_$registroId',
      'registro_id': registroId,
      'modulo_key': moduleKey,
      'empresa_id': empresaId,
      'usuario_id': usuarioId,
      'config_id': configId,
      'lista_id': listaId,
      'estado': estado,
      'payload_json': payload,
      'intentos': 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markOpened({
    required String registroId,
    required String moduleKey,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'correo_pendientes',
      {'estado': 'abierto', 'updated_at': DateTime.now().toIso8601String()},
      where: 'registro_id = ? AND modulo_key = ?',
      whereArgs: [registroId, moduleKey],
    );
  }

  Future<void> deleteById(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('correo_pendientes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByRegistro({
    required String registroId,
    required String moduleKey,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'correo_pendientes',
      where: 'registro_id = ? AND modulo_key = ?',
      whereArgs: [registroId, moduleKey],
    );
  }

  Future<void> markStatusById({
    required String id,
    required String status,
    String? lastError,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'correo_pendientes',
      {
        'estado': status,
        'updated_at': DateTime.now().toIso8601String(),
        'ultimo_error': lastError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updatePayloadById({
    required String id,
    required String subject,
    required String body,
    required List<String> recipients,
    String? comments,
    String? attachmentPath,
    String status = 'pendiente',
  }) async {
    final db = await DatabaseHelper.instance.database;
    final payload = jsonEncode({
      'subject': subject,
      'body': body,
      'recipients': recipients,
      'comments': comments,
      'attachment_path': attachmentPath,
    });

    await db.update(
      'correo_pendientes',
      {
        'estado': status,
        'payload_json': payload,
        'updated_at': DateTime.now().toIso8601String(),
        'ultimo_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> promoteReadyAfterSync() async {
    final db = await DatabaseHelper.instance.database;
    final pendingSync = await db.query(
      'correo_pendientes',
      where: "estado = 'pendiente_sync'",
    );

    int promoted = 0;
    for (final row in pendingSync) {
      final registroId = (row['registro_id'] ?? '').toString();
      final moduloKey = (row['modulo_key'] ?? '').toString();
      if (registroId.isEmpty || moduloKey.isEmpty) continue;

      final synced = await _isRegistroSynced(db, moduloKey, registroId);
      if (!synced) continue;

      await db.update(
        'correo_pendientes',
        {
          'estado': 'pendiente',
          'updated_at': DateTime.now().toIso8601String(),
          'ultimo_error': null,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      promoted++;
    }
    return promoted;
  }

  Future<bool> _isRegistroSynced(
    DatabaseExecutor db,
    String moduloKey,
    String registroId,
  ) async {
    Future<bool> existsSynced(String table, String idColumn) async {
      final rows = await db.query(
        table,
        columns: ['subido'],
        where: '$idColumn = ? AND subido = 1',
        whereArgs: [registroId],
        limit: 1,
      );
      return rows.isNotEmpty;
    }

    switch (moduloKey) {
      case 'hidroser':
      case 'hidroser_grua_horquilla':
        return existsSynced('hidroser_inspecciones_pendientes', 'id');
      case 'buceo_equipamiento':
        return existsSynced('buceo_equipamiento_inspecciones_pendientes', 'id');
      case 'visita_r003':
        return existsSynced('visitas_tecnicas_pendientes', 'activity_id');
      case 'extintores':
        return existsSynced('extintores_pendientes', 'activity_id');
      default:
        return false;
    }
  }
}
