import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/safe_area_utils.dart';
import '../../services/email_admin_service.dart';

class EmailAdminScreen extends StatefulWidget {
  const EmailAdminScreen({super.key});

  @override
  State<EmailAdminScreen> createState() => _EmailAdminScreenState();
}

class _EmailAdminScreenState extends State<EmailAdminScreen>
    with SingleTickerProviderStateMixin {
  final _service = EmailAdminService();

  static const _titles = [
    'Modelos de correo',
    'Listas de destinatarios',
    'Reglas de envio',
    'Permisos',
  ];

  static const _helpTexts = [
    'Aqui creas los mensajes que se enviaran automaticamente. Cada modelo tiene asunto y mensaje, y puedes incluir datos como fecha o tecnico para completarlos solos.',
    'Aqui defines quien recibe los correos. Puedes agregar personas como destinatario principal, en copia o copia oculta.',
    'Aqui conectas todo: eliges proceso, modelo de correo y lista de personas que se usa, y tambien la prioridad del envio.',
    'Aqui decides que usuarios pueden usar cada regla de correo, para controlar quien puede enviar cada tipo de mensaje.',
  ];

  late final TabController _tabController;
  int _activeTabIndex = 0;
  bool _loading = true;

  List<Map<String, dynamic>> _templates = const [];
  List<Map<String, dynamic>> _lists = const [];
  List<Map<String, dynamic>> _configs = const [];
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _assignments = const [];

  final Map<String, List<Map<String, dynamic>>> _recipientsCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (!mounted) return;
      setState(() => _activeTabIndex = _tabController.index);
    });
    _reloadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildResponsiveDialogBody(
    BuildContext context, {
    required List<Widget> children,
    double maxWidth = 620,
  }) {
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.72;
    return SizedBox(
      width: maxWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Future<void> _reloadAll() async {
    setState(() => _loading = true);
    try {
      final templates = await _service.getTemplates();
      final lists = await _service.getLists();
      final configs = await _service.getConfigs();
      final users = await _service.getUsers();
      final assignments = await _service.getAssignments();

      if (!mounted) return;
      setState(() {
        _templates = templates;
        _lists = lists;
        _configs = configs;
        _users = users;
        _assignments = assignments;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRecipients(String listaId) async {
    final recipients = await _service.getRecipientsByList(listaId);
    if (!mounted) return;
    setState(() => _recipientsCache[listaId] = recipients);
  }

  Future<void> _showTemplateDialog({Map<String, dynamic>? row}) async {
    final nombreCtrl = TextEditingController(
      text: row?['nombre']?.toString() ?? '',
    );
    final moduloCtrl = TextEditingController(
      text: row?['modulo']?.toString() ?? '',
    );
    final asuntoCtrl = TextEditingController(
      text: row?['asunto_template']?.toString() ?? '',
    );
    final cuerpoCtrl = TextEditingController(
      text: row?['cuerpo_template']?.toString() ?? '',
    );
    final varsCtrl = TextEditingController(
      text: row?['variables_permitidas']?.toString() ?? '',
    );
    bool activo = (row?['activo'] as int? ?? 1) == 1;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            row == null ? 'Nuevo modelo de correo' : 'Editar modelo de correo',
          ),
          content: _buildResponsiveDialogBody(
            ctx,
            maxWidth: 620,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: moduloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Proceso o formulario (ej: hidroser)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: asuntoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Asunto del correo',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cuerpoCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Mensaje del correo',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: varsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Campos disponibles (separados por coma)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                title: const Text('Activa'),
                onChanged: (v) => setLocalState(() => activo = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;

    await _service.upsertTemplate(
      id: row?['id']?.toString(),
      nombre: nombreCtrl.text,
      asuntoTemplate: asuntoCtrl.text,
      cuerpoTemplate: cuerpoCtrl.text,
      modulo: moduloCtrl.text,
      variablesPermitidas: varsCtrl.text,
      activo: activo,
    );

    await _reloadAll();
  }

  Future<void> _showListDialog({Map<String, dynamic>? row}) async {
    final nombreCtrl = TextEditingController(
      text: row?['nombre']?.toString() ?? '',
    );
    final propositoCtrl = TextEditingController(
      text: row?['proposito']?.toString() ?? '',
    );
    bool activo = (row?['activo'] as int? ?? 1) == 1;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(row == null ? 'Nueva lista' : 'Editar lista'),
          content: _buildResponsiveDialogBody(
            ctx,
            maxWidth: 560,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: propositoCtrl,
                decoration: const InputDecoration(labelText: 'Proposito'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                title: const Text('Activa'),
                onChanged: (v) => setLocalState(() => activo = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;

    await _service.upsertList(
      id: row?['id']?.toString(),
      nombre: nombreCtrl.text,
      proposito: propositoCtrl.text,
      activo: activo,
    );

    await _reloadAll();
  }

  Future<void> _showRecipientDialog(
    String listaId, {
    Map<String, dynamic>? row,
  }) async {
    final nombreCtrl = TextEditingController(
      text: row?['nombre']?.toString() ?? '',
    );
    final correoCtrl = TextEditingController(
      text: row?['correo']?.toString() ?? '',
    );
    String tipo = row?['tipo_sugerido']?.toString() ?? 'to';
    bool activo = (row?['activo'] as int? ?? 1) == 1;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            row == null ? 'Nuevo destinatario' : 'Editar destinatario',
          ),
          content: _buildResponsiveDialogBody(
            ctx,
            maxWidth: 560,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: correoCtrl,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'to', child: Text('TO')),
                  DropdownMenuItem(value: 'cc', child: Text('CC')),
                  DropdownMenuItem(value: 'cco', child: Text('CCO')),
                ],
                onChanged: (v) => setLocalState(() => tipo = v ?? 'to'),
                decoration: const InputDecoration(
                  labelText: 'Tipo de envio sugerido',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                title: const Text('Activo'),
                onChanged: (v) => setLocalState(() => activo = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;

    await _service.upsertRecipient(
      id: row?['id']?.toString(),
      listaId: listaId,
      nombre: nombreCtrl.text,
      correo: correoCtrl.text,
      tipoSugerido: tipo,
      activo: activo,
    );

    await _loadRecipients(listaId);
  }

  Future<void> _showConfigDialog({Map<String, dynamic>? row}) async {
    final moduloCtrl = TextEditingController(
      text: row?['modulo']?.toString() ?? '',
    );
    final empresaCtrl = TextEditingController(
      text: row?['empresa_id']?.toString() ?? '',
    );
    final prioridadCtrl = TextEditingController(
      text: (row?['prioridad'] ?? 0).toString(),
    );
    String? plantillaId = row?['plantilla_id']?.toString();
    String? listaId = row?['lista_id']?.toString();
    bool activo = (row?['activo'] as int? ?? 1) == 1;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            row == null ? 'Nueva regla de envio' : 'Editar regla de envio',
          ),
          content: _buildResponsiveDialogBody(
            ctx,
            maxWidth: 620,
            children: [
              TextField(
                controller: moduloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Proceso o formulario',
                  helperText:
                      'Ej: hidroser, hidroser_grua_horquilla, visita_r003',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: plantillaId,
                isExpanded: true,
                items: _templates
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: t['id'].toString(),
                        child: Text(
                          t['nombre']?.toString() ?? 'Modelo de correo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => _templates
                    .map(
                      (t) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t['nombre']?.toString() ?? 'Modelo de correo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocalState(() => plantillaId = v),
                decoration: const InputDecoration(
                  labelText: 'Modelo de correo',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: listaId,
                isExpanded: true,
                items: _lists
                    .map(
                      (l) => DropdownMenuItem<String>(
                        value: l['id'].toString(),
                        child: Text(
                          l['nombre']?.toString() ?? 'Lista',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => _lists
                    .map(
                      (l) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l['nombre']?.toString() ?? 'Lista',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocalState(() => listaId = v),
                decoration: const InputDecoration(
                  labelText: 'Lista de destinatarios',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: empresaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Empresa (ID opcional)',
                  helperText: 'Vacio = aplica a todas',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prioridadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prioridad (0 primero)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                title: const Text('Activa'),
                onChanged: (v) => setLocalState(() => activo = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true || plantillaId == null || listaId == null) return;

    await _service.upsertConfig(
      id: row?['id']?.toString(),
      modulo: moduloCtrl.text,
      plantillaId: plantillaId!,
      listaId: listaId!,
      empresaId: empresaCtrl.text,
      prioridad: int.tryParse(prioridadCtrl.text) ?? 0,
      activo: activo,
    );

    await _reloadAll();
  }

  Future<void> _showAssignmentDialog({Map<String, dynamic>? row}) async {
    String? usuarioId = row?['usuario_id']?.toString();
    String? configId = row?['config_id']?.toString();
    String? listaId = row?['lista_id']?.toString();
    bool activo = (row?['activo'] as int? ?? 1) == 1;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            row == null
                ? 'Nuevo permiso por usuario'
                : 'Editar permiso por usuario',
          ),
          content: _buildResponsiveDialogBody(
            ctx,
            maxWidth: 620,
            children: [
              DropdownButtonFormField<String>(
                initialValue: usuarioId,
                isExpanded: true,
                items: _users
                    .map(
                      (u) => DropdownMenuItem<String>(
                        value: u['id'].toString(),
                        child: Text(
                          ((u['nombre_completo'] ?? '').toString().isNotEmpty)
                              ? (u['nombre_completo'] ?? '').toString()
                              : (u['email']?.toString() ?? 'Usuario'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => _users
                    .map(
                      (u) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          ((u['nombre_completo'] ?? '').toString().isNotEmpty)
                              ? (u['nombre_completo'] ?? '').toString()
                              : (u['email']?.toString() ?? 'Usuario'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocalState(() => usuarioId = v),
                decoration: const InputDecoration(labelText: 'Usuario'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: configId ?? '',
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Sin regla'),
                  ),
                  ..._configs.map(
                    (c) => DropdownMenuItem<String>(
                      value: c['id'].toString(),
                      child: Text(
                        '${c['modulo']} · ${c['template_nombre'] ?? 'Modelo de correo'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                selectedItemBuilder: (context) => [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sin regla',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ..._configs.map(
                    (c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${c['modulo']} · ${c['template_nombre'] ?? 'Modelo de correo'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setLocalState(
                  () => configId = (v == null || v.isEmpty) ? null : v,
                ),
                decoration: const InputDecoration(
                  labelText: 'Regla de envio (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: listaId ?? '',
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Sin lista'),
                  ),
                  ..._lists.map(
                    (l) => DropdownMenuItem<String>(
                      value: l['id'].toString(),
                      child: Text(
                        l['nombre']?.toString() ?? 'Lista',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                selectedItemBuilder: (context) => [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sin lista',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ..._lists.map(
                    (l) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l['nombre']?.toString() ?? 'Lista',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setLocalState(
                  () => listaId = (v == null || v.isEmpty) ? null : v,
                ),
                decoration: const InputDecoration(
                  labelText: 'Lista (opcional)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                title: const Text('Activa'),
                onChanged: (v) => setLocalState(() => activo = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    final usuarioIdSafe = usuarioId ?? '';
    if (save != true || usuarioIdSafe.isEmpty) return;

    await _service.upsertAssignment(
      id: row?['id']?.toString(),
      usuarioId: usuarioIdSafe,
      configId: configId,
      listaId: listaId,
      activo: activo,
    );

    await _reloadAll();
  }

  Future<void> _deleteRow(String table, String id) async {
    await _service.deleteById(table, id);
    await _reloadAll();
  }

  void _showTabHelp() {
    final idx = _activeTabIndex;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: SafeAreaUtils.bottomSheetPadding(ctx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _titles[idx],
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_helpTexts[idx], style: Theme.of(ctx).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Correos automaticos'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Ayuda',
            onPressed: _showTabHelp,
            icon: const Icon(Icons.help_outline),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          tabs: _titles.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTemplatesTab(),
                _buildListsTab(),
                _buildConfigsTab(),
                _buildAssignmentsTab(),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                switch (_tabController.index) {
                  case 0:
                    _showTemplateDialog();
                    break;
                  case 1:
                    _showListDialog();
                    break;
                  case 2:
                    _showConfigDialog();
                    break;
                  case 3:
                    _showAssignmentDialog();
                    break;
                }
              },
              icon: const Icon(Icons.add),
              label: Text(switch (_activeTabIndex) {
                0 => 'Agregar modelo',
                1 => 'Agregar lista',
                2 => 'Agregar regla',
                3 => 'Agregar permiso',
                _ => 'Agregar',
              }),
            ),
    );
  }

  Widget _buildTemplatesTab() {
    if (_templates.isEmpty) {
      return const _EmptyState(
        icon: Icons.mail_outline_rounded,
        title: 'Todavia no hay modelos de correo',
        message: 'Crea el primer modelo para poder enviar correos automaticos.',
      );
    }

    return ListView.separated(
      itemCount: _templates.length,
      separatorBuilder: (_, idx) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = _templates[index];
        final id = row['id'].toString();
        final activo = (row['activo'] as int? ?? 1) == 1;
        return _EntityCard(
          title: row['nombre']?.toString() ?? 'Modelo de correo',
          statusLabel: activo ? 'Activa' : 'Inactiva',
          statusActive: activo,
          tags: [
            _InfoTag(
              icon: Icons.work_outline_rounded,
              label: row['modulo']?.toString() ?? '-',
            ),
          ],
          onEdit: () => _showTemplateDialog(row: row),
          onDelete: () => _deleteRow('correo_plantillas', id),
        );
      },
    );
  }

  Widget _buildListsTab() {
    if (_lists.isEmpty) {
      return const _EmptyState(
        icon: Icons.groups_outlined,
        title: 'Todavia no hay listas de destinatarios',
        message: 'Crea una lista para agrupar personas que recibiran correos.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _lists.length,
      itemBuilder: (context, index) {
        final row = _lists[index];
        final listId = row['id'].toString();
        final recipients =
            _recipientsCache[listId] ?? const <Map<String, dynamic>>[];

        return ExpansionTile(
          title: Text(row['nombre']?.toString() ?? 'Lista'),
          subtitle: Text(row['proposito']?.toString() ?? ''),
          onExpansionChanged: (expanded) {
            if (expanded && !_recipientsCache.containsKey(listId)) {
              _loadRecipients(listId);
            }
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRecipientDialog(listId),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Agregar destinatario'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showListDialog(row: row),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar lista'),
                  ),
                ],
              ),
            ),
            if (recipients.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Sin destinatarios.'),
              )
            else
              ...recipients.map(
                (r) => ListTile(
                  dense: true,
                  title: Text(r['correo']?.toString() ?? ''),
                  subtitle: Text(
                    '${r['nombre'] ?? '-'} · ${r['tipo_sugerido'] ?? 'to'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showRecipientDialog(listId, row: r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () async {
                          await _service.deleteRecipient(r['id'].toString());
                          await _loadRecipients(listId);
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildConfigsTab() {
    if (_configs.isEmpty) {
      return const _EmptyState(
        icon: Icons.alt_route_rounded,
        title: 'Todavia no hay reglas de envio',
        message:
            'Une un proceso, un modelo y una lista para automatizar envios.',
      );
    }

    return ListView.separated(
      itemCount: _configs.length,
      separatorBuilder: (_, idx) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = _configs[index];
        final id = row['id'].toString();
        return _EntityCard(
          title: 'Proceso: ${row['modulo'] ?? '-'}',
          tags: [
            _InfoTag(
              icon: Icons.description_outlined,
              label: 'Modelo: ${row['template_nombre'] ?? 'Sin modelo'}',
            ),
            _InfoTag(
              icon: Icons.groups_outlined,
              label: 'Lista: ${row['lista_nombre'] ?? '-'}',
            ),
            _InfoTag(
              icon: Icons.flag_outlined,
              label: 'Prioridad ${row['prioridad'] ?? 0}',
            ),
          ],
          onEdit: () => _showConfigDialog(row: row),
          onDelete: () => _deleteRow('correo_configuracion', id),
        );
      },
    );
  }

  Widget _buildAssignmentsTab() {
    if (_assignments.isEmpty) {
      return const _EmptyState(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Todavia no hay permisos asignados',
        message: 'Define que usuarios pueden usar cada regla de correo.',
      );
    }

    return ListView.separated(
      itemCount: _assignments.length,
      separatorBuilder: (_, idx) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = _assignments[index];
        final id = row['id'].toString();
        final userName =
            (row['nombre_completo']?.toString().isNotEmpty ?? false)
            ? row['nombre_completo'].toString()
            : (row['email']?.toString() ?? 'Usuario');

        return _EntityCard(
          title: userName,
          tags: [
            _InfoTag(
              icon: Icons.work_outline_rounded,
              label: 'Proceso: ${row['modulo'] ?? '-'}',
            ),
            _InfoTag(
              icon: Icons.rule_folder_outlined,
              label: 'Lista: ${row['lista_nombre'] ?? '-'}',
            ),
          ],
          onEdit: () => _showAssignmentDialog(row: row),
          onDelete: () => _deleteRow('correo_usuario_asignacion', id),
        );
      },
    );
  }
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.title,
    required this.onEdit,
    required this.onDelete,
    this.tags = const [],
    this.statusLabel,
    this.statusActive = true,
  });

  final String title;
  final List<Widget> tags;
  final String? statusLabel;
  final bool statusActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: tags),
                ],
                if (statusLabel != null) ...[
                  const SizedBox(height: 8),
                  _StatusPill(label: statusLabel!, active: statusActive),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  double _adaptiveMaxTagWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ratio = width < 390 ? 0.56 : 0.66;
    return width * ratio;
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _adaptiveMaxTagWidth(context)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFE6F4EA) : const Color(0xFFFBE9E9);
    final fg = active ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
