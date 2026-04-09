import 'package:flutter/material.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../controllers/admin_crud_controller.dart';
import 'empresa_modulos_screen.dart';

class MasterDataAdminScreen extends StatefulWidget {
  const MasterDataAdminScreen({super.key});

  @override
  State<MasterDataAdminScreen> createState() => _MasterDataAdminScreenState();
}

class _MasterDataAdminScreenState extends State<MasterDataAdminScreen> {
  late final AdminCrudController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminCrudController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Administración'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.dataset), text: 'Datos Maestros'),
              Tab(icon: Icon(Icons.toggle_on), text: 'Módulos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DatosMaestrosTab(controller: _controller),
            const EmpresaModulosScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 1: Datos Maestros CRUD ─────────────────────────────────────────────

class _DatosMaestrosTab extends StatefulWidget {
  final AdminCrudController controller;
  const _DatosMaestrosTab({required this.controller});

  @override
  State<_DatosMaestrosTab> createState() => _DatosMaestrosTabState();
}

class _DatosMaestrosTabState extends State<_DatosMaestrosTab> {
  // Form controllers
  final _centroNombreCtrl = TextEditingController();
  String? _centroAreaSeleccionada;

  final _contratistaNombreCtrl = TextEditingController();

  final _embarcacionNombreCtrl = TextEditingController();
  final _embarcacionMatriculaCtrl = TextEditingController();
  String? _embarcacionContratistaSeleccionado;

  // Accordion: track which section is open (null = none)
  int? _expandedIndex;

  // Edit mode
  String? _editingId;
  String? _editingTable;

  AdminCrudController get ctrl => widget.controller;

  @override
  void dispose() {
    _centroNombreCtrl.dispose();
    _contratistaNombreCtrl.dispose();
    _embarcacionNombreCtrl.dispose();
    _embarcacionMatriculaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        if (ctrl.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCentrosSection(0),
            const SizedBox(height: 12),
            _buildContratistasSection(1),
            const SizedBox(height: 12),
            _buildEmbarcacionesSection(2),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  void _toggleSection(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
      _cancelEdit();
    });
  }

  void _startEdit(String table, String id, String nombre,
      {String? extraField, String? extraValue}) {
    setState(() {
      _editingId = id;
      _editingTable = table;
      switch (table) {
        case 'centros':
          _centroNombreCtrl.text = nombre;
          _centroAreaSeleccionada = extraValue;
          break;
        case 'contratistas':
          _contratistaNombreCtrl.text = nombre;
          break;
        case 'embarcaciones':
          _embarcacionNombreCtrl.text = nombre;
          _embarcacionContratistaSeleccionado = extraValue;
          _embarcacionMatriculaCtrl.text = extraField ?? '';
          break;
      }
    });
  }

  void _cancelEdit() {
    _editingId = null;
    _editingTable = null;
    _centroNombreCtrl.clear();
    _centroAreaSeleccionada = null;
    _contratistaNombreCtrl.clear();
    _embarcacionNombreCtrl.clear();
    _embarcacionMatriculaCtrl.clear();
    _embarcacionContratistaSeleccionado = null;
  }

  // ─── Centros ────────────────────────────────────────────────────────────

  Widget _buildCentrosSection(int index) {
    final isExpanded = _expandedIndex == index;
    final areaNombres = ctrl.areas.map((a) => a['nombre'] as String).toList();
    final isEditing = _editingTable == 'centros';

    return _SeccionCard(
      titulo: 'Centros',
      icono: Icons.location_city,
      cantidad: ctrl.centros.length,
      isExpanded: isExpanded,
      onToggle: () => _toggleSection(index),
      children: isExpanded
          ? [
              // Form
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildAutocompleteField(
                      controller: _centroNombreCtrl,
                      label: isEditing ? 'Editar centro' : 'Nombre del centro',
                      suggestions: ctrl.centros
                          .map((c) => c['nombre'] as String)
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    CustomDropdown(
                      items: areaNombres,
                      value: _centroAreaSeleccionada,
                      label: 'Área',
                      enableSearch: areaNombres.length > 5,
                      onChanged: (val) =>
                          setState(() => _centroAreaSeleccionada = val),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isEditing) ...[
                          TextButton(
                            onPressed: () => setState(() => _cancelEdit()),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        FilledButton.icon(
                          onPressed: _guardarCentro,
                          icon: Icon(
                              isEditing ? Icons.save : Icons.add, size: 18),
                          label: Text(
                              isEditing ? 'Guardar' : 'Agregar Centro'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Lista existentes
              if (ctrl.centros.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay centros registrados',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...ctrl.centros.map((c) {
                  final areaNombre =
                      ctrl.getAreaNombre(c['area_id'] as String? ?? '') ??
                          'Sin área';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_city,
                        size: 20, color: Colors.grey),
                    title: Text(c['nombre'] as String? ?? ''),
                    subtitle: Text(areaNombre,
                        style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((c['subido'] as int? ?? 1) == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Pendiente',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _startEdit(
                            'centros',
                            c['id'] as String,
                            c['nombre'] as String? ?? '',
                            extraValue: areaNombre,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ]
          : [],
    );
  }

  Future<void> _guardarCentro() async {
    final nombre = _centroNombreCtrl.text.trim();
    if (nombre.isEmpty) {
      _mostrarError('Ingresa el nombre del centro');
      return;
    }
    if (_centroAreaSeleccionada == null) {
      _mostrarError('Selecciona un área');
      return;
    }

    final area = ctrl.areas.firstWhere(
      (a) => a['nombre'] == _centroAreaSeleccionada,
      orElse: () => {},
    );
    if (area.isEmpty) {
      _mostrarError('Área no encontrada');
      return;
    }

    bool ok;
    if (_editingId != null && _editingTable == 'centros') {
      ok = await ctrl.editarCentro(
          _editingId!, nombre, area['id'] as String);
    } else {
      ok = await ctrl.crearCentro(nombre, area['id'] as String);
    }

    if (ok && mounted) {
      setState(() => _cancelEdit());
      _mostrarExito(_editingId != null
          ? 'Centro actualizado'
          : 'Centro "$nombre" creado');
    }
  }

  // ─── Contratistas ──────────────────────────────────────────────────────

  Widget _buildContratistasSection(int index) {
    final isExpanded = _expandedIndex == index;
    final isEditing = _editingTable == 'contratistas';

    return _SeccionCard(
      titulo: 'Contratistas',
      icono: Icons.engineering,
      cantidad: ctrl.contratistas.length,
      isExpanded: isExpanded,
      onToggle: () => _toggleSection(index),
      children: isExpanded
          ? [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildAutocompleteField(
                      controller: _contratistaNombreCtrl,
                      label: isEditing
                          ? 'Editar contratista'
                          : 'Nombre del contratista',
                      suggestions: ctrl.contratistas
                          .map((c) => c['nombre'] as String)
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isEditing) ...[
                          TextButton(
                            onPressed: () => setState(() => _cancelEdit()),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        FilledButton.icon(
                          onPressed: _guardarContratista,
                          icon: Icon(
                              isEditing ? Icons.save : Icons.add, size: 18),
                          label: Text(isEditing
                              ? 'Guardar'
                              : 'Agregar Contratista'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (ctrl.contratistas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay contratistas registrados',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...ctrl.contratistas.map((c) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.engineering,
                          size: 20, color: Colors.grey),
                      title: Text(c['nombre'] as String? ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((c['subido'] as int? ?? 1) == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Pendiente',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.white)),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _startEdit(
                              'contratistas',
                              c['id'] as String,
                              c['nombre'] as String? ?? '',
                            ),
                          ),
                        ],
                      ),
                    )),
            ]
          : [],
    );
  }

  Future<void> _guardarContratista() async {
    final nombre = _contratistaNombreCtrl.text.trim();
    if (nombre.isEmpty) {
      _mostrarError('Ingresa el nombre del contratista');
      return;
    }

    bool ok;
    if (_editingId != null && _editingTable == 'contratistas') {
      ok = await ctrl.editarContratista(_editingId!, nombre);
    } else {
      ok = await ctrl.crearContratista(nombre);
    }

    if (ok && mounted) {
      setState(() => _cancelEdit());
      _mostrarExito(_editingId != null
          ? 'Contratista actualizado'
          : 'Contratista "$nombre" creado');
    }
  }

  // ─── Embarcaciones ─────────────────────────────────────────────────────

  Widget _buildEmbarcacionesSection(int index) {
    final isExpanded = _expandedIndex == index;
    final isEditing = _editingTable == 'embarcaciones';
    final contratistaNombres =
        ctrl.contratistas.map((c) => c['nombre'] as String).toList();

    return _SeccionCard(
      titulo: 'Embarcaciones',
      icono: Icons.directions_boat,
      cantidad: ctrl.embarcaciones.length,
      isExpanded: isExpanded,
      onToggle: () => _toggleSection(index),
      children: isExpanded
          ? [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildAutocompleteField(
                      controller: _embarcacionNombreCtrl,
                      label: isEditing
                          ? 'Editar embarcación'
                          : 'Nombre de la embarcación',
                      suggestions: ctrl.embarcaciones
                          .map((e) => e['nombre'] as String)
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    CustomDropdown(
                      items: contratistaNombres,
                      value: _embarcacionContratistaSeleccionado,
                      label: 'Contratista',
                      enableSearch: contratistaNombres.length > 5,
                      onChanged: (val) => setState(
                          () => _embarcacionContratistaSeleccionado = val),
                    ),
                    TextField(
                      controller: _embarcacionMatriculaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Matrícula (opcional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isEditing) ...[
                          TextButton(
                            onPressed: () => setState(() => _cancelEdit()),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        FilledButton.icon(
                          onPressed: _guardarEmbarcacion,
                          icon: Icon(
                              isEditing ? Icons.save : Icons.add, size: 18),
                          label: Text(isEditing
                              ? 'Guardar'
                              : 'Agregar Embarcación'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (ctrl.embarcaciones.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay embarcaciones registradas',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...ctrl.embarcaciones.map((e) {
                  final contratistaNombre = ctrl.getContratistaNombre(
                          e['contratista_id'] as String? ?? '') ??
                      'Sin contratista';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.directions_boat,
                        size: 20, color: Colors.grey),
                    title: Text(e['nombre'] as String? ?? ''),
                    subtitle: Text(
                      '$contratistaNombre${e['matricula'] != null ? ' • ${e['matricula']}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((e['subido'] as int? ?? 1) == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Pendiente',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _startEdit(
                            'embarcaciones',
                            e['id'] as String,
                            e['nombre'] as String? ?? '',
                            extraValue: contratistaNombre,
                            extraField: e['matricula'] as String? ?? '',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ]
          : [],
    );
  }

  Future<void> _guardarEmbarcacion() async {
    final nombre = _embarcacionNombreCtrl.text.trim();
    if (nombre.isEmpty) {
      _mostrarError('Ingresa el nombre de la embarcación');
      return;
    }
    if (_embarcacionContratistaSeleccionado == null) {
      _mostrarError('Selecciona un contratista');
      return;
    }

    final contratista = ctrl.contratistas.firstWhere(
      (c) => c['nombre'] == _embarcacionContratistaSeleccionado,
      orElse: () => {},
    );
    if (contratista.isEmpty) {
      _mostrarError('Contratista no encontrado');
      return;
    }

    final matricula = _embarcacionMatriculaCtrl.text.trim();

    bool ok;
    if (_editingId != null && _editingTable == 'embarcaciones') {
      ok = await ctrl.editarEmbarcacion(
        _editingId!,
        nombre,
        contratista['id'] as String,
        matricula.isEmpty ? null : matricula,
      );
    } else {
      ok = await ctrl.crearEmbarcacion(
        nombre,
        contratista['id'] as String,
        matricula.isEmpty ? null : matricula,
      );
    }

    if (ok && mounted) {
      setState(() => _cancelEdit());
      _mostrarExito(_editingId != null
          ? 'Embarcación actualizada'
          : 'Embarcación "$nombre" creada');
    }
  }

  // ─── Autocomplete field ────────────────────────────────────────────────

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required List<String> suggestions,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (textEditingValue) {
        final text = textEditingValue.text.trim().toLowerCase();
        if (text.isEmpty) return const Iterable<String>.empty();
        return suggestions.where(
          (s) => s.toLowerCase().contains(text),
        );
      },
      fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => ctrl.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.info_outline,
                        size: 16, color: Colors.orange),
                    title: Text(option, style: const TextStyle(fontSize: 13)),
                    subtitle: const Text('Ya existe',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), backgroundColor: Colors.green.shade700),
    );
  }
}

// ─── Sección Card (manual accordion) ────────────────────────────────────────

class _SeccionCard extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final int cantidad;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _SeccionCard({
    required this.titulo,
    required this.icono,
    required this.cantidad,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icono, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$cantidad',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(children: children),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
