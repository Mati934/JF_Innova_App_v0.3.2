import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/user_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/rut_utils.dart';
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
    final isSuperAdmin = UserSession().esSuperAdmin;
    // Admin Maestro: Datos Maestros, Modulos, Usuarios (solo super admin)
    return DefaultTabController(
      length: isSuperAdmin ? 3 : 2,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Administracion'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: isSuperAdmin,
            tabs: [
              const Tab(icon: Icon(Icons.dataset), text: 'Datos Maestros'),
              const Tab(icon: Icon(Icons.toggle_on), text: 'Modulos'),
              if (isSuperAdmin)
                const Tab(icon: Icon(Icons.people), text: 'Usuarios'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SafeArea(child: _DatosMaestrosTab(controller: _controller)),
            SafeArea(child: const EmpresaModulosScreen(embedded: true)),
            if (isSuperAdmin)
              SafeArea(child: _UsuariosTab(controller: _controller)),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 1: Datos Maestros ──────────────────────────────────────────────────

class _DatosMaestrosTab extends StatelessWidget {
  final AdminCrudController controller;
  const _DatosMaestrosTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner de error de sync
            if (controller.lastSyncError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.lastSyncError!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    controller.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: controller.retrySyncMaestros,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Reintentar',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                  ],
                ),
              ),
            _CategoriaCard(
              titulo: 'Centros',
              icono: Icons.location_city,
              cantidad: controller.centros.length,
              onTap: () => _mostrarOpciones(context, 'centros'),
            ),
            const SizedBox(height: 12),
            _CategoriaCard(
              titulo: 'Contratistas',
              icono: Icons.engineering,
              cantidad: controller.contratistas.length,
              onTap: () => _mostrarOpciones(context, 'contratistas'),
            ),
            const SizedBox(height: 12),
            _CategoriaCard(
              titulo: 'Embarcaciones',
              icono: Icons.directions_boat,
              cantidad: controller.embarcaciones.length,
              onTap: () => _mostrarOpciones(context, 'embarcaciones'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarOpciones(BuildContext context, String tabla) {
    final config = _getTablaConfig(tabla);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                config.titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Agregar nuevo
              _OpcionTile(
                icono: Icons.add_circle_outline,
                color: Colors.green.shade700,
                titulo: 'Agregar nuevo',
                subtitulo: 'Crear un nuevo registro',
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirFormulario(context, tabla, null);
                },
              ),
              const SizedBox(height: 8),
              // Modificar existente
              _OpcionTile(
                icono: Icons.edit_outlined,
                color: AppTheme.primaryBlue,
                titulo: 'Modificar existente',
                subtitulo: 'Buscar y editar un registro',
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirBuscador(context, tabla);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TablaConfig _getTablaConfig(String tabla) {
    switch (tabla) {
      case 'centros':
        return _TablaConfig(
          titulo: 'Centros',
          icono: Icons.location_city,
          items: controller.centros,
          getNombre: (item) => item['nombre'] as String? ?? '',
          getSubtitulo: (item) =>
              controller.getAreaNombre(item['area_id'] as String? ?? '') ??
              'Sin area',
        );
      case 'contratistas':
        return _TablaConfig(
          titulo: 'Contratistas',
          icono: Icons.engineering,
          items: controller.contratistas,
          getNombre: (item) => item['nombre'] as String? ?? '',
          getSubtitulo: null,
        );
      case 'embarcaciones':
        return _TablaConfig(
          titulo: 'Embarcaciones',
          icono: Icons.directions_boat,
          items: controller.embarcaciones,
          getNombre: (item) => item['nombre'] as String? ?? '',
          getSubtitulo: (item) {
            final contratista =
                controller.getContratistaNombre(
                  item['contratista_id'] as String? ?? '',
                ) ??
                'Sin contratista';
            final mat = item['matricula'] as String?;
            return mat != null && mat.isNotEmpty
                ? '$contratista  |  $mat'
                : contratista;
          },
        );
      default:
        throw ArgumentError('Tabla no soportada: $tabla');
    }
  }

  void _abrirFormulario(
    BuildContext context,
    String tabla,
    Map<String, dynamic>? itemEditar,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: _FormularioSheet(
          controller: controller,
          tabla: tabla,
          itemEditar: itemEditar,
        ),
      ),
    );
  }

  void _abrirBuscador(BuildContext context, String tabla) {
    final config = _getTablaConfig(tabla);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: _BuscadorSheet(
          config: config,
          controller: controller,
          tabla: tabla,
          onItemSelected: (item) {
            Navigator.pop(ctx);
            _abrirFormulario(context, tabla, item);
          },
        ),
      ),
    );
  }
}

// ─── Categoria Card (reemplaza los acordeones) ──────────────────────────────

class _CategoriaCard extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final int cantidad;
  final VoidCallback onTap;

  const _CategoriaCard({
    required this.titulo,
    required this.icono,
    required this.cantidad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Icon(icono, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 16),
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
                  horizontal: 10,
                  vertical: 4,
                ),
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
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Opcion Tile (para el bottom sheet de Agregar/Modificar) ────────────────

class _OpcionTile extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _OpcionTile({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icono, color: color),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─── Config helper ──────────────────────────────────────────────────────────

class _TablaConfig {
  final String titulo;
  final IconData icono;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) getNombre;
  final String Function(Map<String, dynamic>)? getSubtitulo;

  _TablaConfig({
    required this.titulo,
    required this.icono,
    required this.items,
    required this.getNombre,
    required this.getSubtitulo,
  });
}

// ─── Buscador Sheet (lista con busqueda para Modificar) ─────────────────────

class _BuscadorSheet extends StatefulWidget {
  final _TablaConfig config;
  final AdminCrudController controller;
  final String tabla;
  final void Function(Map<String, dynamic> item) onItemSelected;

  const _BuscadorSheet({
    required this.config,
    required this.controller,
    required this.tabla,
    required this.onItemSelected,
  });

  @override
  State<_BuscadorSheet> createState() => _BuscadorSheetState();
}

class _BuscadorSheetState extends State<_BuscadorSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtrados = [];

  @override
  void initState() {
    super.initState();
    _filtrados = widget.config.items;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filtrar(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtrados = widget.config.items;
      } else {
        _filtrados = widget.config.items.where((item) {
          final nombre = widget.config.getNombre(item).toLowerCase();
          final sub =
              widget.config.getSubtitulo?.call(item).toLowerCase() ?? '';
          return nombre.contains(q) || sub.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle + titulo
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Modificar ${widget.config.titulo.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Barra de busqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filtrar('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: _filtrar,
              ),
            ),
            // Contador de resultados
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtrados.length} resultado${_filtrados.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Lista virtualizada
            Flexible(
              child: _filtrados.isEmpty
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 150),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No se encontraron coincidencias',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Intenta con otro término de búsqueda',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filtrados.length,
                      itemBuilder: (context, index) {
                        final item = _filtrados[index];
                        final nombre = widget.config.getNombre(item);
                        final sub = widget.config.getSubtitulo?.call(item);
                        final pendiente = (item['subido'] as int? ?? 1) == 0;

                        return ListTile(
                          leading: Icon(
                            widget.config.icono,
                            size: 20,
                            color: Colors.grey,
                          ),
                          title: Text(nombre),
                          subtitle: sub != null
                              ? Text(sub, style: const TextStyle(fontSize: 12))
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pendiente)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Pendiente',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                            ],
                          ),
                          onTap: () => widget.onItemSelected(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Formulario Sheet (Agregar o Editar) ────────────────────────────────────

class _FormularioSheet extends StatefulWidget {
  final AdminCrudController controller;
  final String tabla;
  final Map<String, dynamic>? itemEditar;

  const _FormularioSheet({
    required this.controller,
    required this.tabla,
    this.itemEditar,
  });

  @override
  State<_FormularioSheet> createState() => _FormularioSheetState();
}

class _FormularioSheetState extends State<_FormularioSheet> {
  final _nombreCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();
  final _rutCtrl = TextEditingController();
  late final FocusNode _nombreFocusNode;
  final ValueNotifier<String?> _areaNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _contratistaNotifier = ValueNotifier(null);
  bool _saving = false;

  bool get isEditing => widget.itemEditar != null;
  AdminCrudController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _nombreFocusNode = FocusNode();
    if (isEditing) {
      final item = widget.itemEditar!;
      _nombreCtrl.text = item['nombre'] as String? ?? '';

      if (widget.tabla == 'centros') {
        _areaNotifier.value = ctrl.getAreaNombre(
          item['area_id'] as String? ?? '',
        );
      } else if (widget.tabla == 'contratistas') {
        final rut = item['rut'] as String? ?? '';
        if (!rut.startsWith('PENDIENTE-')) {
          _rutCtrl.text = rut;
        }
      } else if (widget.tabla == 'embarcaciones') {
        _contratistaNotifier.value = ctrl.getContratistaNombre(
          item['contratista_id'] as String? ?? '',
        );
        _matriculaCtrl.text = item['matricula'] as String? ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nombreFocusNode.dispose();
    _nombreCtrl.dispose();
    _matriculaCtrl.dispose();
    _rutCtrl.dispose();
    _areaNotifier.dispose();
    _contratistaNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = isEditing
        ? 'Editar ${_tituloSingular(widget.tabla)}'
        : 'Agregar ${_tituloSingular(widget.tabla)}';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Campos vinculados primero (area, contratista, etc.)
            ..._buildCamposExtraAntes(),
            // Campo nombre con autocomplete para detectar duplicados
            _buildNombreField(),
            // Campos extras después del nombre (matrícula, etc.)
            ..._buildCamposDespues(),
            const SizedBox(height: 16),
            // Botones
            if (isEditing) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _eliminar,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _guardar,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(isEditing ? Icons.save : Icons.add, size: 18),
                    label: Text(
                      _saving
                          ? 'Guardando...'
                          : isEditing
                          ? 'Guardar'
                          : 'Agregar',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNombreField() {
    final suggestions = _getSuggestions();

    return RawAutocomplete<String>(
      textEditingController: _nombreCtrl,
      focusNode: _nombreFocusNode,
      optionsBuilder: (textEditingValue) {
        final text = textEditingValue.text.trim().toLowerCase();
        if (text.isEmpty) return const Iterable<String>.empty();
        return suggestions.where((s) => s.toLowerCase().contains(text));
      },
      fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (context, value, _) {
            return TextField(
              controller: ctrl,
              focusNode: focusNode,
              autofocus: !isEditing,
              decoration: InputDecoration(
                labelText: 'Nombre',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => ctrl.clear(),
                      )
                    : null,
              ),
            );
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                    title: Text(option, style: const TextStyle(fontSize: 13)),
                    subtitle: const Text(
                      'Ya existe',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
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

  List<String> _getSuggestions() {
    switch (widget.tabla) {
      case 'centros':
        return ctrl.centros.map((c) => c['nombre'] as String).toList();
      case 'contratistas':
        return ctrl.contratistas.map((c) => c['nombre'] as String).toList();
      case 'embarcaciones':
        return ctrl.embarcaciones.map((e) => e['nombre'] as String).toList();
      default:
        return [];
    }
  }

  /// Campos que van ANTES del nombre (dropdowns de vinculación)
  List<Widget> _buildCamposExtraAntes() {
    switch (widget.tabla) {
      case 'centros':
        final areaNombres = ctrl.areas
            .map((a) => a['nombre'] as String)
            .toList();
        return [
          ValueListenableBuilder<String?>(
            valueListenable: _areaNotifier,
            builder: (context, areaValue, _) => CustomDropdown(
              key: const ValueKey('area-dropdown'),
              items: areaNombres,
              value: areaValue,
              label: 'Area',
              enableSearch: areaNombres.length > 5,
              onChanged: (val) => _areaNotifier.value = val,
            ),
          ),
          const SizedBox(height: 12),
        ];
      case 'embarcaciones':
        final contratistaNombres = ctrl.contratistas
            .map((c) => c['nombre'] as String)
            .toList();
        return [
          ValueListenableBuilder<String?>(
            valueListenable: _contratistaNotifier,
            builder: (context, contratistaValue, _) => CustomDropdown(
              key: const ValueKey('contratista-dropdown'),
              items: contratistaNombres,
              value: contratistaValue,
              label: 'Contratista',
              enableSearch: contratistaNombres.length > 5,
              onChanged: (val) => _contratistaNotifier.value = val,
            ),
          ),
          const SizedBox(height: 12),
        ];
      default:
        return [];
    }
  }

  /// Campos que van DESPUÉS del nombre (matrícula, etc.)
  List<Widget> _buildCamposDespues() {
    switch (widget.tabla) {
      case 'contratistas':
        return [
          const SizedBox(height: 12),
          TextField(
            controller: _rutCtrl,
            decoration: const InputDecoration(
              labelText: 'RUT (opcional)',
              hintText: 'Ej: 12.345.678-5',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            inputFormatters: [RutInputFormatter()],
          ),
        ];
      case 'embarcaciones':
        return [
          const SizedBox(height: 12),
          TextField(
            controller: _matriculaCtrl,
            decoration: const InputDecoration(
              labelText: 'Matricula (opcional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      _mostrarError('Ingresa el nombre');
      return;
    }

    setState(() => _saving = true);

    bool ok = false;
    try {
      switch (widget.tabla) {
        case 'centros':
          ok = await _guardarCentro(nombre);
          break;
        case 'contratistas':
          ok = await _guardarContratista(nombre);
          break;
        case 'embarcaciones':
          ok = await _guardarEmbarcacion(nombre);
          break;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? '${_tituloSingular(widget.tabla)} actualizado'
                : '"$nombre" creado',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminacion'),
        content: Text(
          '¿Eliminar "${widget.itemEditar!['nombre']}"? Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _saving = true);
    final ok = await ctrl.eliminarRegistro(
      widget.tabla,
      widget.itemEditar!['id'] as String,
    );
    if (mounted) setState(() => _saving = false);

    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${widget.itemEditar!['nombre']}" eliminado'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    } else if (mounted) {
      _mostrarError('Error al eliminar');
    }
  }

  Future<bool> _guardarCentro(String nombre) async {
    if (_areaNotifier.value == null) {
      _mostrarError('Selecciona un area');
      return false;
    }
    final area = ctrl.areas.firstWhere(
      (a) => a['nombre'] == _areaNotifier.value,
      orElse: () => {},
    );
    if (area.isEmpty) {
      _mostrarError('Area no encontrada');
      return false;
    }
    final areaId = area['id'] as String;

    if (isEditing) {
      return ctrl.editarCentro(
        widget.itemEditar!['id'] as String,
        nombre,
        areaId,
      );
    }
    return ctrl.crearCentro(nombre, areaId);
  }

  Future<bool> _guardarContratista(String nombre) async {
    final rut = _rutCtrl.text.trim();
    final rutNorm = rut.isNotEmpty ? RutUtils.normalize(rut) : null;
    if (isEditing) {
      return ctrl.editarContratista(
        widget.itemEditar!['id'] as String,
        nombre,
        rut: rutNorm,
      );
    }
    return ctrl.crearContratista(nombre, rut: rutNorm);
  }

  Future<bool> _guardarEmbarcacion(String nombre) async {
    if (_contratistaNotifier.value == null) {
      _mostrarError('Selecciona un contratista');
      return false;
    }
    final contratista = ctrl.contratistas.firstWhere(
      (c) => c['nombre'] == _contratistaNotifier.value,
      orElse: () => {},
    );
    if (contratista.isEmpty) {
      _mostrarError('Contratista no encontrado');
      return false;
    }
    final contratistaId = contratista['id'] as String;
    final matricula = _matriculaCtrl.text.trim();

    if (isEditing) {
      return ctrl.editarEmbarcacion(
        widget.itemEditar!['id'] as String,
        nombre,
        contratistaId,
        matricula.isEmpty ? null : matricula,
      );
    }
    return ctrl.crearEmbarcacion(
      nombre,
      contratistaId,
      matricula.isEmpty ? null : matricula,
    );
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _tituloSingular(String tabla) {
    switch (tabla) {
      case 'centros':
        return 'Centro';
      case 'contratistas':
        return 'Contratista';
      case 'embarcaciones':
        return 'Embarcacion';
      default:
        return '';
    }
  }
}

// ─── Tab Usuarios (solo superAdmin) ─────────────────────────────────────────

class _UsuariosTab extends StatefulWidget {
  final AdminCrudController controller;
  const _UsuariosTab({required this.controller});

  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await widget.controller.getUsuarios();
      if (mounted) setState(() => _usuarios = lista);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> usuario) async {
    final nombre =
        usuario['nombre_completo'] as String? ??
        usuario['email'] as String? ??
        'Usuario';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
          '¿Seguro que deseas eliminar a "$nombre"?\n\nEsta acción es irreversible y eliminará la cuenta de Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final error = await widget.controller.deleteUser(usuario['id'] as String);

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario "$nombre" eliminado'),
          backgroundColor: Colors.green,
        ),
      );
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _usuarios.length,
        itemBuilder: (context, i) {
          final u = _usuarios[i];
          final nombre = u['nombre_completo'] as String? ?? '';
          final email = u['email'] as String? ?? '';
          final rol = u['nombre_rol'] as String? ?? '';
          final empresa = u['empresa_nombre'] as String? ?? '';
          final esMiCuenta =
              u['id'] == Supabase.instance.client.auth.currentUser?.id;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              title: Text(nombre.isNotEmpty ? nombre : email),
              subtitle: Text(
                [
                  if (email.isNotEmpty) email,
                  if (rol.isNotEmpty) rol,
                  if (empresa.isNotEmpty) empresa,
                ].join(' · '),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: esMiCuenta
                  ? const Chip(
                      label: Text('Tú', style: TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Eliminar usuario',
                      onPressed: () => _confirmarEliminar(u),
                    ),
            ),
          );
        },
      ),
    );
  }
}
