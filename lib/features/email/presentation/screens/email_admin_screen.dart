import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/safe_area_utils.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
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
  List<Map<String, dynamic>> _empresas = const [];
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
      final empresas = await _service.getEmpresas();
      final assignments = await _service.getAssignments();

      if (!mounted) return;
      setState(() {
        _templates = templates;
        _lists = lists;
        _configs = configs;
        _users = users;
        _empresas = empresas;
        _assignments = assignments;
        _recipientsCache.clear();
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

  String _empresaLabel(Map<String, dynamic> empresa) {
    final nombre = empresa['nombre']?.toString().trim() ?? '';
    final rut = empresa['rut']?.toString().trim() ?? '';
    if (nombre.isEmpty && rut.isEmpty) return 'Empresa';
    if (rut.isEmpty) return nombre;
    if (nombre.isEmpty) return rut;
    return '$nombre ($rut)';
  }

  String _empresaDisplayFromId(dynamic empresaId) {
    final id = empresaId?.toString() ?? '';
    if (id.isEmpty) return 'Todas las empresas';
    for (final empresa in _empresas) {
      if (empresa['id']?.toString() == id) {
        return _empresaLabel(empresa);
      }
    }
    return 'ID $id';
  }

  List<String> _buildModuloOptions() {
    final base = <String>{
      'inspeccion',
      'inspeccion_buceo',
      'inspeccion_embarcacion',
      'visita_r003',
      'visita_r004',
      'extintores',
      'mantencion_prosesso',
      'prosesso',
      'hidroser',
      'hidroser_grua_horquilla',
      'hidroser_soldadora',
      'ast',
      'buceo_equipamiento',
      'tickets',
      'buceo',
      'merieux_visitas',
      'merieux_extintores',
    };

    for (final t in _templates) {
      final m = t['modulo']?.toString().trim() ?? '';
      if (m.isNotEmpty) base.add(m);
    }
    for (final c in _configs) {
      final m = c['modulo']?.toString().trim() ?? '';
      if (m.isNotEmpty) base.add(m);
    }

    final list = base.toList()..sort();
    return list;
  }

  List<String> _parseTemplateVariables(String raw) {
    if (raw.trim().isEmpty) return const [];

    final unique = <String>{};
    final tokens = raw.split(RegExp(r'[,;\n\r\t ]+'));
    for (final token in tokens) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) continue;

      final withoutBraces = trimmed.replaceAll('{', '').replaceAll('}', '');
      final cleaned = withoutBraces.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      if (cleaned.isEmpty) continue;
      unique.add(cleaned);
    }

    return unique.toList()..sort();
  }

  List<String> _defaultTemplateVariablesForModule(String modulo) {
    const common = [
      'fecha_inspeccion',
      'hora_inspeccion',
      'supervisor_nombre',
      'tecnico_nombre',
      'empresa_nombre',
      'numero_informe',
      'modulo',
      'observaciones',
    ];

    const inspectionExtended = [
      'area_nombre',
      'centro_nombre',
      'numero_informe',
      'empresa_contratista',
      'embarcacion_nombre',
      'actividad_planificada',
      'estado_faena',
      'motivo_suspension',
      'fecha_inspeccion',
      'hora_inspeccion',
      'empresa_nombre',
      'tecnico_nombre',
      'supervisor_nombre',
    ];

    final byModule = <String, List<String>>{
      'inspeccion': inspectionExtended,
      'inspeccion_buceo': inspectionExtended,
      'inspeccion_embarcacion': inspectionExtended,
      'hidroser': ['fecha_inspeccion', 'hora_inspeccion', 'supervisor_nombre'],
      'hidroser_grua_horquilla': [
        'fecha_inspeccion',
        'hora_inspeccion',
        'supervisor_nombre',
      ],
      'hidroser_soldadora': ['fecha_inspeccion', 'hora_inspeccion'],
      'visita_r003': ['fecha_visita', 'tecnico_nombre', 'empresa_nombre'],
      'visita_r004': ['fecha_visita', 'tecnico_nombre', 'empresa_nombre'],
      'extintores': ['fecha_visita', 'tecnico_nombre', 'empresa_nombre'],
      'ast': ['fecha_inspeccion', 'supervisor_nombre', 'empresa_nombre'],
      'tickets': ['numero_ticket', 'empresa_nombre', 'tecnico_nombre'],
      'buceo_equipamiento': [
        'fecha_inspeccion',
        'empresa_nombre',
        'supervisor_nombre',
      ],
      'merieux_visitas': ['fecha_visita', 'empresa_nombre', 'tecnico_nombre'],
      'merieux_extintores': [
        'fecha_visita',
        'empresa_nombre',
        'tecnico_nombre',
      ],
    };

    final key = modulo.trim().toLowerCase();
    return byModule[key] ?? common;
  }

  List<String> _buildSuggestedTemplateVariables({
    required String modulo,
    required String customRaw,
  }) {
    final merged = <String>{
      ..._defaultTemplateVariablesForModule(modulo),
      ..._parseTemplateVariables(customRaw),
    };
    final list = merged.toList()..sort();
    return list;
  }

  void _insertTemplateToken(TextEditingController controller, String variable) {
    final token = '{{$variable}}';
    final currentText = controller.text;

    var start = controller.selection.start;
    var end = controller.selection.end;
    if (start < 0 || end < 0) {
      start = currentText.length;
      end = currentText.length;
    }
    if (start > end) {
      final swap = start;
      start = end;
      end = swap;
    }

    final updatedText = currentText.replaceRange(start, end, token);
    controller.value = controller.value.copyWith(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + token.length),
      composing: TextRange.empty,
    );
  }

  Widget _buildTutorialBox(String title, List<String> tips) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $tip', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTemplateDialog({Map<String, dynamic>? row}) async {
    final nombreCtrl = TextEditingController(
      text: row?['nombre']?.toString() ?? '',
    );
    String modulo = row?['modulo']?.toString() ?? '';
    final moduloOptions = _buildModuloOptions();
    final asuntoCtrl = TextEditingController(
      text: row?['asunto_template']?.toString() ?? '',
    );
    final cuerpoCtrl = TextEditingController(
      text: row?['cuerpo_template']?.toString() ?? '',
    );
    final varsCtrl = TextEditingController(
      text: row?['variables_permitidas']?.toString() ?? '',
    );
    String insertTarget = 'cuerpo';
    bool activo = (row?['activo'] as int? ?? 1) == 1;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final availableVariables = _buildSuggestedTemplateVariables(
            modulo: modulo,
            customRaw: varsCtrl.text,
          );

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: Text(
              row == null
                  ? 'Nuevo modelo de correo'
                  : 'Editar modelo de correo',
            ),
            content: _buildResponsiveDialogBody(
              ctx,
              maxWidth: 620,
              children: [
                _buildTutorialBox('Como crear un modelo', const [
                  'Nombre: usa algo claro, por ejemplo "Hidroser - Informe final".',
                  'Modulo: define en que proceso se aplica este correo.',
                  'Puedes usar variables en asunto y cuerpo para completar datos automaticamente.',
                ]),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                CustomDropdown(
                  label: 'Proceso o formulario',
                  icon: Icons.work_outline_rounded,
                  items: moduloOptions,
                  value: modulo.isEmpty ? null : modulo,
                  hintText: 'Selecciona o agrega un modulo',
                  onChanged: (v) => setLocalState(() => modulo = v ?? ''),
                  onAddNew: (text) => setLocalState(() => modulo = text),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: asuntoCtrl,
                  onTap: () => setLocalState(() => insertTarget = 'asunto'),
                  decoration: const InputDecoration(
                    labelText: 'Asunto del correo',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cuerpoCtrl,
                  onTap: () => setLocalState(() => insertTarget = 'cuerpo'),
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje del correo',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: varsCtrl,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Campos disponibles (separados por coma)',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Insertar variable en',
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Asunto'),
                      selected: insertTarget == 'asunto',
                      onSelected: (_) =>
                          setLocalState(() => insertTarget = 'asunto'),
                    ),
                    ChoiceChip(
                      label: const Text('Mensaje'),
                      selected: insertTarget == 'cuerpo',
                      onSelected: (_) =>
                          setLocalState(() => insertTarget = 'cuerpo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (availableVariables.isEmpty)
                  const Text(
                    'No hay variables detectadas todavia.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableVariables
                        .map(
                          (variable) => ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: Text('{{$variable}}'),
                            onPressed: () {
                              final target = insertTarget == 'asunto'
                                  ? asuntoCtrl
                                  : cuerpoCtrl;
                              _insertTemplateToken(target, variable);
                            },
                          ),
                        )
                        .toList(),
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
          );
        },
      ),
    );

    if (save != true) return;

    await _service.upsertTemplate(
      id: row?['id']?.toString(),
      nombre: nombreCtrl.text,
      asuntoTemplate: asuntoCtrl.text,
      cuerpoTemplate: cuerpoCtrl.text,
      modulo: modulo,
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
              _buildTutorialBox('Como crear una lista', const [
                'Agrupa correos por objetivo: operacion, cliente o respaldo.',
                'Usa nombres cortos y un proposito entendible para todo el equipo.',
              ]),
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
    const tipoOptions = ['TO', 'CC', 'CCO'];
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
              _buildTutorialBox('Como agregar destinatarios', const [
                'TO: receptor principal. CC: copia visible. CCO: copia oculta.',
                'Puedes crear listas por cliente o por tipo de proceso.',
              ]),
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
              CustomDropdown(
                label: 'Tipo de envio sugerido',
                items: tipoOptions,
                value: tipo.toUpperCase(),
                enableSearch: false,
                onChanged: (v) =>
                    setLocalState(() => tipo = (v ?? 'TO').toLowerCase()),
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
    String modulo = row?['modulo']?.toString() ?? '';
    final moduloOptions = _buildModuloOptions();

    final templateNameById = {
      for (final t in _templates)
        t['id'].toString(): (t['nombre']?.toString() ?? 'Modelo de correo'),
    };
    final listNameById = {
      for (final l in _lists)
        l['id'].toString(): (l['nombre']?.toString() ?? 'Lista'),
    };

    final templateOptions = _templates
        .map((t) => t['nombre']?.toString() ?? 'Modelo de correo')
        .toList();
    final listOptions = _lists
        .map((l) => l['nombre']?.toString() ?? 'Lista')
        .toList();

    final empresaLabelById = <String, String>{};
    final empresaIdByLabel = <String, String>{};
    for (final e in _empresas) {
      final id = e['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final label = _empresaLabel(e);
      empresaLabelById[id] = label;
      empresaIdByLabel[label] = id;
    }

    const todasEmpresasLabel = 'Todas las empresas';
    final empresaOptions = <String>[
      todasEmpresasLabel,
      ...empresaIdByLabel.keys,
    ];

    final prioridadCtrl = TextEditingController(
      text: (row?['prioridad'] ?? 0).toString(),
    );
    String? plantillaId = row?['plantilla_id']?.toString();
    String? listaId = row?['lista_id']?.toString();
    String selectedTemplate = plantillaId == null
        ? ''
        : (templateNameById[plantillaId] ?? '');
    String selectedList = listaId == null ? '' : (listNameById[listaId] ?? '');

    final currentEmpresaId = row?['empresa_id']?.toString() ?? '';
    String selectedEmpresa = currentEmpresaId.isEmpty
        ? todasEmpresasLabel
        : (empresaLabelById[currentEmpresaId] ?? 'ID $currentEmpresaId');
    if (!empresaOptions.contains(selectedEmpresa)) {
      empresaOptions.add(selectedEmpresa);
    }

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
              _buildTutorialBox('Como crear una regla', const [
                'Selecciona modulo, modelo y lista para definir que se enviara.',
                'Empresa es opcional: "Todas las empresas" aplica como regla general.',
                'Prioridad menor gana primero: 0 se evalua antes que 1.',
              ]),
              CustomDropdown(
                label: 'Proceso o formulario',
                icon: Icons.work_outline_rounded,
                items: moduloOptions,
                value: modulo.isEmpty ? null : modulo,
                hintText: 'Ej: hidroser, ast, tickets',
                onChanged: (v) => setLocalState(() => modulo = v ?? ''),
                onAddNew: (text) => setLocalState(() => modulo = text),
              ),
              const SizedBox(height: 12),
              CustomDropdown(
                label: 'Modelo de correo',
                icon: Icons.description_outlined,
                items: templateOptions,
                value: selectedTemplate.isEmpty ? null : selectedTemplate,
                onChanged: (name) => setLocalState(() {
                  selectedTemplate = name ?? '';
                  plantillaId = templateNameById.entries
                      .firstWhere(
                        (entry) => entry.value == selectedTemplate,
                        orElse: () => const MapEntry('', ''),
                      )
                      .key;
                }),
              ),
              const SizedBox(height: 12),
              CustomDropdown(
                label: 'Lista de destinatarios',
                icon: Icons.groups_outlined,
                items: listOptions,
                value: selectedList.isEmpty ? null : selectedList,
                onChanged: (name) => setLocalState(() {
                  selectedList = name ?? '';
                  listaId = listNameById.entries
                      .firstWhere(
                        (entry) => entry.value == selectedList,
                        orElse: () => const MapEntry('', ''),
                      )
                      .key;
                }),
              ),
              const SizedBox(height: 12),
              CustomDropdown(
                label: 'Empresa',
                icon: Icons.business_outlined,
                items: empresaOptions,
                value: selectedEmpresa,
                onChanged: (v) => setLocalState(
                  () => selectedEmpresa = v ?? todasEmpresasLabel,
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

    if (save != true ||
        plantillaId == null ||
        listaId == null ||
        plantillaId!.isEmpty ||
        listaId!.isEmpty) {
      return;
    }

    await _service.upsertConfig(
      id: row?['id']?.toString(),
      modulo: modulo,
      plantillaId: plantillaId!,
      listaId: listaId!,
      empresaId: selectedEmpresa == todasEmpresasLabel
          ? ''
          : (empresaIdByLabel[selectedEmpresa] ?? ''),
      prioridad: int.tryParse(prioridadCtrl.text) ?? 0,
      activo: activo,
    );

    await _reloadAll();
  }

  Future<void> _showAssignmentDialog({Map<String, dynamic>? row}) async {
    String? usuarioId = row?['usuario_id']?.toString();
    String? configId = row?['config_id']?.toString();
    String? listaId = row?['lista_id']?.toString();

    final userNameById = {
      for (final u in _users)
        u['id'].toString(): ((u['nombre_completo'] ?? '').toString().isNotEmpty)
            ? (u['nombre_completo'] ?? '').toString()
            : (u['email']?.toString() ?? 'Usuario'),
    };
    final configNameById = {
      for (final c in _configs)
        c['id'].toString():
            '${c['modulo']} · ${c['template_nombre'] ?? 'Modelo de correo'}',
    };
    final listNameById = {
      for (final l in _lists)
        l['id'].toString(): (l['nombre']?.toString() ?? 'Lista'),
    };

    const sinRegla = 'Sin regla';
    const sinLista = 'Sin lista';

    String selectedUser = usuarioId == null
        ? ''
        : (userNameById[usuarioId] ?? '');
    String selectedRule = configId == null
        ? sinRegla
        : (configNameById[configId] ?? sinRegla);
    String selectedList = listaId == null
        ? sinLista
        : (listNameById[listaId] ?? sinLista);

    final userOptions = _users
        .map(
          (u) => ((u['nombre_completo'] ?? '').toString().isNotEmpty)
              ? (u['nombre_completo'] ?? '').toString()
              : (u['email']?.toString() ?? 'Usuario'),
        )
        .toList();
    final ruleOptions = <String>[sinRegla, ...configNameById.values];
    final listOptions = <String>[sinLista, ...listNameById.values];

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
              _buildTutorialBox('Como funciona permisos', const [
                'Usuario es obligatorio para definir a quien aplica.',
                'Regla y lista son opcionales: si no defines una, se usa la configuracion general.',
                'Activa/desactiva sin borrar para cambios temporales.',
              ]),
              CustomDropdown(
                label: 'Usuario',
                icon: Icons.person_outline,
                items: userOptions,
                value: selectedUser.isEmpty ? null : selectedUser,
                onChanged: (name) => setLocalState(() {
                  selectedUser = name ?? '';
                  usuarioId = userNameById.entries
                      .firstWhere(
                        (entry) => entry.value == selectedUser,
                        orElse: () => const MapEntry('', ''),
                      )
                      .key;
                }),
              ),
              const SizedBox(height: 12),
              CustomDropdown(
                label: 'Regla de envio (opcional)',
                icon: Icons.alt_route_rounded,
                items: ruleOptions,
                value: selectedRule,
                onChanged: (name) => setLocalState(() {
                  selectedRule = name ?? sinRegla;
                  configId = selectedRule == sinRegla
                      ? null
                      : configNameById.entries
                            .firstWhere(
                              (entry) => entry.value == selectedRule,
                              orElse: () => const MapEntry('', ''),
                            )
                            .key;
                  if (configId != null && configId!.isEmpty) {
                    configId = null;
                  }
                }),
              ),
              const SizedBox(height: 12),
              CustomDropdown(
                label: 'Lista (opcional)',
                icon: Icons.rule_folder_outlined,
                items: listOptions,
                value: selectedList,
                onChanged: (name) => setLocalState(() {
                  selectedList = name ?? sinLista;
                  listaId = selectedList == sinLista
                      ? null
                      : listNameById.entries
                            .firstWhere(
                              (entry) => entry.value == selectedList,
                              orElse: () => const MapEntry('', ''),
                            )
                            .key;
                  if (listaId != null && listaId!.isEmpty) {
                    listaId = null;
                  }
                }),
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

  Future<void> _deleteList(String listId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lista de destinatarios'),
        content: const Text(
          'Se eliminaran tambien sus destinatarios, reglas asociadas y permisos relacionados. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _service.deleteById('correo_listas', listId);
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
                  OutlinedButton.icon(
                    onPressed: () => _deleteList(listId),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar lista'),
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
              icon: Icons.business_outlined,
              label: 'Empresa: ${_empresaDisplayFromId(row['empresa_id'])}',
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
