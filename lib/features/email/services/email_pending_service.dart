import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';

class EmailPendingService {
  String _newEventId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _logEvent(
    DatabaseExecutor db, {
    required String inspeccionId,
    required String? empresaId,
    required String? usuarioId,
    required String eventType,
    required String resultado,
    required String canal,
    required String configId,
    required String? listaId,
    required String? listaNombre,
    required String templateId,
    required String? templateNombre,
    int? templateVersion,
    required String reglaEnvioNombre,
    String? asunto,
    String? adjuntoNombre,
    List<String>? destinatarios,
    String? errorCode,
    String? errorMessage,
  }) async {
    await db.insert('correo_eventos', {
      'id': _newEventId('evt_correo'),
      'inspeccion_id': inspeccionId,
      'empresa_id': empresaId,
      'usuario_id': usuarioId,
      'config_id': configId,
      'lista_id': listaId,
      'lista_nombre': listaNombre,
      'event_type': eventType,
      'event_timestamp': DateTime.now().toIso8601String(),
      'resultado_evento': resultado,
      'canal': canal,
      'template_id': templateId,
      'template_nombre': templateNombre,
      'template_version': templateVersion,
      'regla_envio_nombre': reglaEnvioNombre,
      'asunto_generado': asunto,
      'adjunto_nombre': adjuntoNombre,
      'adjunto_tipo': (adjuntoNombre != null && adjuntoNombre.trim().isNotEmpty)
          ? 'PDF'
          : null,
      'error_code': errorCode,
      'error_message': errorMessage,
      'modulo_key': canal.startsWith('APP_OUTLOOK/')
          ? canal.substring('APP_OUTLOOK/'.length)
          : canal,
      'destinatarios_json': destinatarios == null
          ? null
          : jsonEncode(destinatarios),
      'destinatarios_count': destinatarios?.length,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> _getPendingById(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      'correo_pendientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> _getDispatchMetaByConfigId(
    DatabaseExecutor db,
    String? configId,
  ) async {
    final cfgId = (configId ?? '').trim();
    if (cfgId.isEmpty) return null;

    final rows = await db.rawQuery(
      '''
      SELECT
        c.id AS config_id,
        c.modulo AS modulo,
        c.lista_id AS lista_id,
        p.id AS template_id,
        p.nombre AS template_nombre,
        p.version AS template_version,
        l.nombre AS lista_nombre
      FROM correo_configuracion c
      INNER JOIN correo_plantillas p ON p.id = c.plantilla_id
      LEFT JOIN correo_listas l ON l.id = c.lista_id
      WHERE c.id = ?
      LIMIT 1
      ''',
      [cfgId],
    );

    if (rows.isEmpty) return null;
    final row = rows.first;
    final templateId = (row['template_id'] ?? '').toString().trim();
    if (templateId.isEmpty) return null;

    int? templateVersion;
    final rawVersion = row['template_version'];
    if (rawVersion is int) {
      templateVersion = rawVersion;
    } else if (rawVersion != null) {
      templateVersion = int.tryParse(rawVersion.toString());
    }

    return {
      'config_id': cfgId,
      'modulo': row['modulo']?.toString() ?? '',
      'lista_id': row['lista_id']?.toString(),
      'lista_nombre': row['lista_nombre']?.toString(),
      'template_id': templateId,
      'template_nombre': row['template_nombre']?.toString(),
      'template_version': templateVersion,
    };
  }

  String? _attachmentNameFromPath(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    if (parts.isEmpty) return null;
    return parts.last;
  }

  String _buildCanalLabel(String moduleKey) {
    final key = moduleKey.trim().isEmpty ? 'desconocido' : moduleKey.trim();
    return 'APP_OUTLOOK/$key';
  }

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

    final templateMeta = await _getDispatchMetaByConfigId(db, configId);
    if (templateMeta != null) {
      final modulo = (templateMeta['modulo']?.toString() ?? '').trim();
      await _logEvent(
        db,
        inspeccionId: registroId,
        empresaId: empresaId,
        usuarioId: usuarioId,
        eventType: 'PENDIENTE_ENCOLADO',
        resultado: estado,
        canal: _buildCanalLabel(moduleKey),
        configId: templateMeta['config_id'].toString(),
        listaId: templateMeta['lista_id']?.toString(),
        listaNombre: templateMeta['lista_nombre']?.toString(),
        templateId: templateMeta['template_id'].toString(),
        templateNombre: templateMeta['template_nombre']?.toString(),
        templateVersion: templateMeta['template_version'] as int?,
        reglaEnvioNombre: modulo.isEmpty ? moduleKey : modulo,
        asunto: subject,
        adjuntoNombre: _attachmentNameFromPath(attachmentPath),
        destinatarios: recipients,
      );
    }
  }

  Future<void> markOpened({
    required String registroId,
    required String moduleKey,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final row = await db.query(
      'correo_pendientes',
      where: 'registro_id = ? AND modulo_key = ?',
      whereArgs: [registroId, moduleKey],
      limit: 1,
    );

    await db.update(
      'correo_pendientes',
      {'estado': 'abierto', 'updated_at': DateTime.now().toIso8601String()},
      where: 'registro_id = ? AND modulo_key = ?',
      whereArgs: [registroId, moduleKey],
    );

    if (row.isNotEmpty) {
      final current = row.first;
      final templateMeta = await _getDispatchMetaByConfigId(
        db,
        current['config_id']?.toString(),
      );
      final payload = parsePayload(current['payload_json']?.toString());
      if (templateMeta != null) {
        final modulo = (templateMeta['modulo']?.toString() ?? '').trim();
        await _logEvent(
          db,
          inspeccionId: registroId,
          empresaId: current['empresa_id']?.toString(),
          usuarioId: current['usuario_id']?.toString(),
          eventType: 'CORREO_ABIERTO_PREVIEW',
          resultado: 'abierto',
          canal: _buildCanalLabel(current['modulo_key']?.toString() ?? ''),
          configId: templateMeta['config_id'].toString(),
          listaId: templateMeta['lista_id']?.toString(),
          listaNombre: templateMeta['lista_nombre']?.toString(),
          templateId: templateMeta['template_id'].toString(),
          templateNombre: templateMeta['template_nombre']?.toString(),
          templateVersion: templateMeta['template_version'] as int?,
          reglaEnvioNombre: modulo.isEmpty
              ? (current['modulo_key']?.toString() ?? '')
              : modulo,
          asunto: payload['subject']?.toString(),
          adjuntoNombre: _attachmentNameFromPath(
            payload['attachment_path']?.toString(),
          ),
        );
      }
    }
  }

  Future<void> markPreparedExternally({
    required String registroId,
    required String moduleKey,
    required Map<String, dynamic> result,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final row = await db.query(
      'correo_pendientes',
      where: 'registro_id = ? AND modulo_key = ?',
      whereArgs: [registroId, moduleKey],
      limit: 1,
    );
    if (row.isEmpty) return;
    final current = row.first;
    final templateMeta = await _getDispatchMetaByConfigId(
      db,
      current['config_id']?.toString(),
    );
    if (templateMeta == null) return;
    final modulo = (templateMeta['modulo']?.toString() ?? '').trim();
    final recipients = (result['recipients'] as List?)
        ?.map((value) => value.toString())
        .toList();
    await _logEvent(
      db,
      inspeccionId: registroId,
      empresaId: current['empresa_id']?.toString(),
      usuarioId: current['usuario_id']?.toString(),
      eventType: 'CORREO_PREPARADO_EXTERNO',
      resultado: 'abierto_externo',
      canal: _buildCanalLabel(moduleKey),
      configId: templateMeta['config_id'].toString(),
      listaId: templateMeta['lista_id']?.toString(),
      listaNombre: templateMeta['lista_nombre']?.toString(),
      templateId: templateMeta['template_id'].toString(),
      templateNombre: templateMeta['template_nombre']?.toString(),
      templateVersion: templateMeta['template_version'] as int?,
      reglaEnvioNombre: modulo.isEmpty ? moduleKey : modulo,
      asunto: result['subject']?.toString(),
      adjuntoNombre: _attachmentNameFromPath(
        result['attachment_path']?.toString(),
      ),
      destinatarios: recipients,
    );
  }

  Future<void> deleteById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final row = await _getPendingById(db, id);
    await db.delete('correo_pendientes', where: 'id = ?', whereArgs: [id]);

    if (row != null) {
      final templateMeta = await _getDispatchMetaByConfigId(
        db,
        row['config_id']?.toString(),
      );
      final payload = parsePayload(row['payload_json']?.toString());
      if (templateMeta != null) {
        final modulo = (templateMeta['modulo']?.toString() ?? '').trim();
        await _logEvent(
          db,
          inspeccionId: row['registro_id']?.toString() ?? '',
          empresaId: row['empresa_id']?.toString(),
          usuarioId: row['usuario_id']?.toString(),
          eventType: 'PENDIENTE_ELIMINADO',
          resultado: 'eliminado',
          canal: _buildCanalLabel(row['modulo_key']?.toString() ?? ''),
          configId: templateMeta['config_id'].toString(),
          listaId: templateMeta['lista_id']?.toString(),
          listaNombre: templateMeta['lista_nombre']?.toString(),
          templateId: templateMeta['template_id'].toString(),
          templateNombre: templateMeta['template_nombre']?.toString(),
          templateVersion: templateMeta['template_version'] as int?,
          reglaEnvioNombre: modulo.isEmpty
              ? (row['modulo_key']?.toString() ?? '')
              : modulo,
          asunto: payload['subject']?.toString(),
          adjuntoNombre: _attachmentNameFromPath(
            payload['attachment_path']?.toString(),
          ),
        );
      }
    }
  }

  Future<void> deleteByRegistro({
    required String registroId,
    required String moduleKey,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final row = await db.query(
      'correo_pendientes',
      where: 'registro_id = ? AND modulo_key = ?',
      whereArgs: [registroId, moduleKey],
      limit: 1,
    );

    await db.delete(
      'correo_pendientes',
      where: 'registro_id = ? AND modulo_key = ?',
      whereArgs: [registroId, moduleKey],
    );

    if (row.isNotEmpty) {
      final current = row.first;
      final templateMeta = await _getDispatchMetaByConfigId(
        db,
        current['config_id']?.toString(),
      );
      final payload = parsePayload(current['payload_json']?.toString());
      if (templateMeta != null) {
        final modulo = (templateMeta['modulo']?.toString() ?? '').trim();
        await _logEvent(
          db,
          inspeccionId: registroId,
          empresaId: current['empresa_id']?.toString(),
          usuarioId: current['usuario_id']?.toString(),
          eventType: 'PENDIENTE_ELIMINADO',
          resultado: 'eliminado',
          canal: _buildCanalLabel(moduleKey),
          configId: templateMeta['config_id'].toString(),
          listaId: templateMeta['lista_id']?.toString(),
          listaNombre: templateMeta['lista_nombre']?.toString(),
          templateId: templateMeta['template_id'].toString(),
          templateNombre: templateMeta['template_nombre']?.toString(),
          templateVersion: templateMeta['template_version'] as int?,
          reglaEnvioNombre: modulo.isEmpty ? moduleKey : modulo,
          asunto: payload['subject']?.toString(),
          adjuntoNombre: _attachmentNameFromPath(
            payload['attachment_path']?.toString(),
          ),
        );
      }
    }
  }

  Future<void> markStatusById({
    required String id,
    required String status,
    String? lastError,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final row = await _getPendingById(db, id);

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

    if (row != null) {
      final templateMeta = await _getDispatchMetaByConfigId(
        db,
        row['config_id']?.toString(),
      );
      final payload = parsePayload(row['payload_json']?.toString());
      if (templateMeta != null) {
        final modulo = (templateMeta['modulo']?.toString() ?? '').trim();
        await _logEvent(
          db,
          inspeccionId: row['registro_id']?.toString() ?? '',
          empresaId: row['empresa_id']?.toString(),
          usuarioId: row['usuario_id']?.toString(),
          eventType: 'PENDIENTE_ESTADO',
          resultado: status,
          canal: _buildCanalLabel(row['modulo_key']?.toString() ?? ''),
          configId: templateMeta['config_id'].toString(),
          listaId: templateMeta['lista_id']?.toString(),
          listaNombre: templateMeta['lista_nombre']?.toString(),
          templateId: templateMeta['template_id'].toString(),
          templateNombre: templateMeta['template_nombre']?.toString(),
          templateVersion: templateMeta['template_version'] as int?,
          reglaEnvioNombre: modulo.isEmpty
              ? (row['modulo_key']?.toString() ?? '')
              : modulo,
          asunto: payload['subject']?.toString(),
          adjuntoNombre: _attachmentNameFromPath(
            payload['attachment_path']?.toString(),
          ),
          errorCode: lastError == null ? null : 'PENDING_STATUS_ERROR',
          errorMessage: lastError,
        );
      }
    }
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
    final row = await _getPendingById(db, id);
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

    if (row != null) {
      final templateMeta = await _getDispatchMetaByConfigId(
        db,
        row['config_id']?.toString(),
      );
      if (templateMeta != null) {
        final modulo = (templateMeta['modulo']?.toString() ?? '').trim();
        await _logEvent(
          db,
          inspeccionId: row['registro_id']?.toString() ?? '',
          empresaId: row['empresa_id']?.toString(),
          usuarioId: row['usuario_id']?.toString(),
          eventType: 'PENDIENTE_ACTUALIZADO',
          resultado: status,
          canal: _buildCanalLabel(row['modulo_key']?.toString() ?? ''),
          configId: templateMeta['config_id'].toString(),
          listaId: templateMeta['lista_id']?.toString(),
          listaNombre: templateMeta['lista_nombre']?.toString(),
          templateId: templateMeta['template_id'].toString(),
          templateNombre: templateMeta['template_nombre']?.toString(),
          templateVersion: templateMeta['template_version'] as int?,
          reglaEnvioNombre: modulo.isEmpty
              ? (row['modulo_key']?.toString() ?? '')
              : modulo,
          asunto: subject,
          adjuntoNombre: _attachmentNameFromPath(attachmentPath),
        );
      }
    }
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

      final templateMeta = await _getDispatchMetaByConfigId(
        db,
        row['config_id']?.toString(),
      );
      if (templateMeta != null) {
        final payloadMap = parsePayload(row['payload_json']?.toString());
        final modulo = (templateMeta['modulo']?.toString() ?? '').trim();
        await _logEvent(
          db,
          inspeccionId: registroId,
          empresaId: row['empresa_id']?.toString(),
          usuarioId: row['usuario_id']?.toString(),
          eventType: 'PENDIENTE_PROMOVIDO',
          resultado: 'pendiente',
          canal: _buildCanalLabel(moduloKey),
          configId: templateMeta['config_id'].toString(),
          listaId: templateMeta['lista_id']?.toString(),
          listaNombre: templateMeta['lista_nombre']?.toString(),
          templateId: templateMeta['template_id'].toString(),
          templateNombre: templateMeta['template_nombre']?.toString(),
          templateVersion: templateMeta['template_version'] as int?,
          reglaEnvioNombre: modulo.isEmpty ? moduloKey : modulo,
          asunto: payloadMap['subject']?.toString(),
          adjuntoNombre: _attachmentNameFromPath(
            payloadMap['attachment_path']?.toString(),
          ),
        );
      }
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
