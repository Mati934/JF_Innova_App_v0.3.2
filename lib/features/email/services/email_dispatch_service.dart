import '../../../core/database/database_helper.dart';
import '../../email/services/email_template_service.dart';

class EmailDispatchData {
  final String configId;
  final String? listaId;
  final String moduleKey;
  final String subject;
  final String body;
  final List<String> suggestedRecipients;

  const EmailDispatchData({
    required this.configId,
    required this.moduleKey,
    this.listaId,
    required this.subject,
    required this.body,
    required this.suggestedRecipients,
  });
}

class EmailDispatchService {
  Future<EmailDispatchData?> resolveForModules({
    required List<String> moduleKeys,
    required Map<String, String> templateValues,
    String? empresaId,
    String? usuarioId,
  }) async {
    final db = await DatabaseHelper.instance.database;

    for (final moduleKey in moduleKeys) {
      // Prioridad 1: configuración explícitamente asignada al usuario.
      // Si existe, se usa por sobre cualquier otra (empresa/global).
      if (usuarioId != null && usuarioId.isNotEmpty) {
        final cfgRowsForUser = await db.rawQuery(
          '''
          SELECT c.id as config_id, c.plantilla_id, c.lista_id, p.asunto_template, p.cuerpo_template
          FROM correo_configuracion c
          INNER JOIN correo_plantillas p ON p.id = c.plantilla_id
          INNER JOIN correo_usuario_asignacion a
            ON a.activo = 1
           AND a.usuario_id = ?
           AND (a.config_id = c.id OR (a.lista_id IS NOT NULL AND a.lista_id = c.lista_id))
          WHERE c.activo = 1
            AND p.activo = 1
            AND lower(c.modulo) = lower(?)
            AND (c.empresa_id = ? OR c.empresa_id IS NULL)
          ORDER BY CASE WHEN c.empresa_id = ? THEN 0 ELSE 1 END, c.prioridad ASC
          LIMIT 1
          ''',
          [usuarioId, moduleKey, empresaId, empresaId],
        );

        final dispatch = await _buildDispatchFromConfigRow(
          db: db,
          cfgRows: cfgRowsForUser,
          templateValues: templateValues,
        );
        if (dispatch != null) return dispatch;
      }

      final cfgRows = await db.rawQuery(
        '''
        SELECT c.id as config_id, c.plantilla_id, c.lista_id, p.asunto_template, p.cuerpo_template
        FROM correo_configuracion c
        INNER JOIN correo_plantillas p ON p.id = c.plantilla_id
        WHERE c.activo = 1
          AND p.activo = 1
          AND lower(c.modulo) = lower(?)
          AND (c.empresa_id = ? OR c.empresa_id IS NULL)
        ORDER BY CASE WHEN c.empresa_id = ? THEN 0 ELSE 1 END, c.prioridad ASC
        LIMIT 1
        ''',
        [moduleKey, empresaId, empresaId],
      );

      final dispatch = await _buildDispatchFromConfigRow(
        db: db,
        cfgRows: cfgRows,
        templateValues: templateValues,
        usuarioId: usuarioId,
      );
      if (dispatch == null) continue;

      return EmailDispatchData(
        configId: dispatch.configId,
        listaId: dispatch.listaId,
        moduleKey: moduleKey,
        subject: dispatch.subject,
        body: dispatch.body,
        suggestedRecipients: dispatch.suggestedRecipients,
      );
    }

    return null;
  }

  Future<EmailDispatchData?> _buildDispatchFromConfigRow({
    required dynamic db,
    required List<Map<String, Object?>> cfgRows,
    required Map<String, String> templateValues,
    String? usuarioId,
  }) async {
    if (cfgRows.isEmpty) return null;

    final cfg = cfgRows.first;
    final configId = (cfg['config_id'] ?? '').toString();
    final listaId = (cfg['lista_id'] ?? '').toString();
    if (configId.isEmpty || listaId.isEmpty) return null;

    // Si existen asignaciones para esta configuración/lista, sólo pasa
    // usuarios explícitamente asignados.
    if (usuarioId != null && usuarioId.isNotEmpty) {
      final assignmentCount = await db.rawQuery(
        '''
        SELECT COUNT(*) AS total
        FROM correo_usuario_asignacion
        WHERE activo = 1 AND (config_id = ? OR lista_id = ?)
        ''',
        [configId, listaId],
      );
      final hasAssignments = (assignmentCount.first['total'] as int? ?? 0) > 0;

      if (hasAssignments) {
        final userAssignments = await db.rawQuery(
          '''
          SELECT COUNT(*) AS total
          FROM correo_usuario_asignacion
          WHERE activo = 1 AND usuario_id = ? AND (config_id = ? OR lista_id = ?)
          ''',
          [usuarioId, configId, listaId],
        );
        final isAssigned = (userAssignments.first['total'] as int? ?? 0) > 0;
        if (!isAssigned) return null;
      }
    }

    final destinatarios = await db.query(
      'correo_lista_destinatarios',
      columns: ['correo'],
      where: 'lista_id = ? AND activo = 1',
      whereArgs: [listaId],
    );

    final emails = destinatarios
        .map((r) => (r['correo'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (emails.isEmpty) return null;

    final asuntoTemplate = (cfg['asunto_template'] ?? '').toString();
    final cuerpoTemplate = (cfg['cuerpo_template'] ?? '').toString();

    final subject = EmailTemplateService.renderTemplate(
      asuntoTemplate,
      templateValues,
    );
    final body = EmailTemplateService.renderTemplate(
      cuerpoTemplate,
      templateValues,
    );

    return EmailDispatchData(
      configId: configId,
      listaId: listaId,
      moduleKey: '',
      subject: subject.trim(),
      body: body.trim(),
      suggestedRecipients: emails,
    );
  }
}
