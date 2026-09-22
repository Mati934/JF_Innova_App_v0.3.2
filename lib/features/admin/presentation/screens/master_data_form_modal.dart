import 'package:flutter/material.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../controllers/batch_draft_controller.dart';
import '../controllers/master_data_selector_controller.dart';
import '../../domain/models/selector_option.dart';
// =============================================================================
// Tipos de entidad que este modal puede crear
// =============================================================================

enum TipoFormulario { empresa, area, contratista, embarcacion }

// =============================================================================
// Punto de entrada — función estática para mostrar el modal
// =============================================================================

class MasterDataFormModal extends StatelessWidget {
  const MasterDataFormModal._({required this.tipo});

  final TipoFormulario tipo;

  /// Muestra el modal como un bottomSheet scrollable.
  /// Ejemplo de uso:
  ///   MasterDataFormModal.show(context, tipo: TipoFormulario.area);
  static Future<void> show(
    BuildContext context, {
    required TipoFormulario tipo,
    required BatchDraftController
    batchController, // <-- INYECCIÓN DIRECTA Y LIMPIA
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _MasterDataModalContent(
          tipo: tipo,
          selectorCtrl: MasterDataSelectorController(
            db: DatabaseHelper.instance,
            draftController: batchController, // <-- SE LO PASAMOS DIRECTO
          ),
        );
      },
    );
  }

  /// Helper para obtener el BatchDraftController del árbol.
  /// Si usas Provider: reemplaza por `Provider.of<BatchDraftController>(context, listen: false)`
  // ignore: unused_element
  static BatchDraftController _findBatchController(BuildContext context) {
    // Intento con Provider si está disponible en el árbol.
    // Si no usas Provider, pasa el controller directamente al método show().
    try {
      // ignore: invalid_use_of_protected_member
      return context
          .findAncestorStateOfType<State>()!
          .context
          .dependOnInheritedWidgetOfExactType<_BatchCtrlProvider>()!
          .controller;
    } catch (_) {
      throw FlutterError(
        'MasterDataFormModal: No se encontró BatchDraftController en el árbol.\n'
        'Asegúrate de proveerlo antes de llamar a MasterDataFormModal.show().',
      );
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// InheritedWidget mínimo para pasar el BatchDraftController si no usas Provider.
// Si ya tienes Provider configurado, puedes ignorar esta clase y usar
// Provider.of<BatchDraftController> directamente en _findBatchController.
// ---------------------------------------------------------------------------

class _BatchCtrlProvider extends InheritedWidget {
  const _BatchCtrlProvider({required this.controller, required super.child});
  final BatchDraftController controller;

  @override
  bool updateShouldNotify(_BatchCtrlProvider old) =>
      controller != old.controller;
}

// =============================================================================
// Widget principal del contenido del modal
// =============================================================================

class _MasterDataModalContent extends StatefulWidget {
  const _MasterDataModalContent({
    required this.tipo,
    required this.selectorCtrl,
  });

  final TipoFormulario tipo;
  final MasterDataSelectorController selectorCtrl;

  @override
  State<_MasterDataModalContent> createState() =>
      _MasterDataModalContentState();
}

class _MasterDataModalContentState extends State<_MasterDataModalContent> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.selectorCtrl.init();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    widget.selectorCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(theme),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Campo nombre — siempre presente
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 4),

                      // Dropdowns reactivos: se reconstruyen solo cuando cambia
                      // el MasterDataSelectorController, no todo el formulario.
                      AnimatedBuilder(
                        animation: widget.selectorCtrl,
                        builder: (context, _) => _buildDynamicFields(),
                      ),

                      const SizedBox(height: 16),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secciones de la UI
  // ---------------------------------------------------------------------------

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader(ThemeData theme) {
    final titles = {
      TipoFormulario.empresa: 'Nueva Empresa',
      TipoFormulario.area: 'Nueva Área',
      TipoFormulario.contratista: 'Nuevo Contratista',
      TipoFormulario.embarcacion: 'Nueva Embarcación',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            titles[widget.tipo] ?? 'Nuevo registro',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicFields() {
    if (widget.selectorCtrl.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (widget.selectorCtrl.error != null) {
      return _ErrorBanner(message: widget.selectorCtrl.error!);
    }

    return switch (widget.tipo) {
      TipoFormulario.empresa => _buildEmpresaFields(),
      TipoFormulario.area => _buildAreaFields(),
      TipoFormulario.contratista => _buildContratistaFields(),
      TipoFormulario.embarcacion => _buildEmbarcacionFields(),
    };
  }

  // ---------------------------------------------------------------------------
  // Formularios por tipo de entidad
  //
  // CustomDropdown requiere: items, value, label, onChanged
  //   - items : List<String>  (los displayNames)
  //   - value : String?       (el displayName actualmente seleccionado)
  //   - label : String        (etiqueta visible sobre el dropdown)
  //   - onChanged : Function(String?)
  // ---------------------------------------------------------------------------

  Widget _buildEmpresaFields() {
    // Empresa no tiene FKs externas; solo descripción libre.
    return _DescripcionField(controller: _descripcionController);
  }

  Widget _buildAreaFields() {
    final ctrl = widget.selectorCtrl;
    final empresaNames = ctrl.toDisplayNames(ctrl.empresas);
    final areaNames = ctrl.toDisplayNames(ctrl.areasFiltradas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Empresa ---
        _TempBadgeLabel(
          label: 'Empresa',
          isTemp: _isSelectedTemp(ctrl.empresas, ctrl.selectedEmpresaId),
        ),
        CustomDropdown(
          items: empresaNames,
          // value: el displayName del item actualmente seleccionado (o null)
          value: ctrl.displayNameForId(ctrl.empresas, ctrl.selectedEmpresaId),
          label: 'Empresa',
          onChanged: ctrl.selectEmpresa,
        ),

        // --- Área (filtrada por empresa) ---
        // ValueKey fuerza reconstrucción limpia del dropdown al cambiar empresa,
        // evitando que quede un valor residual inválido.
        _TempBadgeLabel(
          label: 'Área (opcional)',
          isTemp: _isSelectedTemp(ctrl.areasFiltradas, ctrl.selectedAreaId),
        ),
        CustomDropdown(
          key: ValueKey('area_${ctrl.selectedEmpresaId}'),
          items: areaNames,
          value: ctrl.displayNameForId(
            ctrl.areasFiltradas,
            ctrl.selectedAreaId,
          ),
          label: 'Área',
          onChanged: ctrl.selectArea,
        ),

        _DescripcionField(controller: _descripcionController),
      ],
    );
  }

  Widget _buildContratistaFields() {
    final ctrl = widget.selectorCtrl;
    final empresaNames = ctrl.toDisplayNames(ctrl.empresas);
    final areaNames = ctrl.toDisplayNames(ctrl.areasFiltradas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TempBadgeLabel(
          label: 'Empresa',
          isTemp: _isSelectedTemp(ctrl.empresas, ctrl.selectedEmpresaId),
        ),
        CustomDropdown(
          items: empresaNames,
          value: ctrl.displayNameForId(ctrl.empresas, ctrl.selectedEmpresaId),
          label: 'Empresa',
          onChanged: ctrl.selectEmpresa,
        ),

        _TempBadgeLabel(
          label: 'Área (opcional)',
          isTemp: _isSelectedTemp(ctrl.areasFiltradas, ctrl.selectedAreaId),
        ),
        CustomDropdown(
          key: ValueKey('area_${ctrl.selectedEmpresaId}'),
          items: areaNames,
          value: ctrl.displayNameForId(
            ctrl.areasFiltradas,
            ctrl.selectedAreaId,
          ),
          label: 'Área',
          onChanged: ctrl.selectArea,
        ),

        _DescripcionField(controller: _descripcionController),
      ],
    );
  }

  Widget _buildEmbarcacionFields() {
    final ctrl = widget.selectorCtrl;
    final empresaNames = ctrl.toDisplayNames(ctrl.empresas);
    final contratistaNames = ctrl.toDisplayNames(ctrl.contratistas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TempBadgeLabel(
          label: 'Empresa',
          isTemp: _isSelectedTemp(ctrl.empresas, ctrl.selectedEmpresaId),
        ),
        CustomDropdown(
          items: empresaNames,
          value: ctrl.displayNameForId(ctrl.empresas, ctrl.selectedEmpresaId),
          label: 'Empresa',
          onChanged: ctrl.selectEmpresa,
        ),

        _TempBadgeLabel(
          label: 'Contratista (opcional)',
          isTemp: _isSelectedTemp(
            ctrl.contratistas,
            ctrl.selectedContratistaId,
          ),
        ),
        CustomDropdown(
          items: contratistaNames,
          value: ctrl.displayNameForId(
            ctrl.contratistas,
            ctrl.selectedContratistaId,
          ),
          label: 'Contratista',
          onChanged: ctrl.selectContratista,
        ),

        _DescripcionField(controller: _descripcionController),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Botón de guardar
  // ---------------------------------------------------------------------------

  Widget _buildSubmitButton() => FilledButton(
    onPressed: _onSubmit,
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: const Text('Guardar borrador'),
  );

  // ---------------------------------------------------------------------------
  // Lógica de guardado
  // ---------------------------------------------------------------------------

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) return;

    // Buscamos el BatchDraftController en el árbol.
    // Ajusta este lookup al patrón que uses en tu app.
    final batchCtrl = context
        .findAncestorStateOfType<State>()
        ?.context
        .findAncestorWidgetOfExactType<_BatchCtrlProvider>()
        ?.controller;

    if (batchCtrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: controlador no disponible')),
      );
      return;
    }

    final ctrl = widget.selectorCtrl;

    try {
      // BatchDraftController.addEntity() genera el tempId, registra en el DAG
      // y devuelve el tempId asignado.
      await batchCtrl.addEntity(
        entityType: widget.tipo.name, // 'empresa', 'area', 'contratista', etc.
        data: _buildEntityData(nombre),
        // parentTempId solo si el padre seleccionado es un borrador temporal
        parentTempId: _resolveParentTempId(ctrl),
        parentField: _resolveParentField(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_entityLabel()} guardado como borrador'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Construye el `Map<String, dynamic>` con los campos de la entidad.
  /// Los IDs de FK se toman del MasterDataSelectorController — pueden ser
  /// UUIDs reales o IDs temporales ("temp_empresa_xxx").
  Map<String, dynamic> _buildEntityData(String nombre) {
    final base = <String, dynamic>{
      'nombre': nombre,
      'descripcion': _descripcionController.text.trim(),
    };

    final ctrl = widget.selectorCtrl;

    return switch (widget.tipo) {
      TipoFormulario.empresa => base,
      TipoFormulario.area => {...base, 'empresa_id': ctrl.selectedEmpresaId},
      TipoFormulario.contratista => {
        ...base,
        'empresa_id': ctrl.selectedEmpresaId,
        'area_id': ctrl.selectedAreaId,
      },
      TipoFormulario.embarcacion => {
        ...base,
        'empresa_id': ctrl.selectedEmpresaId,
        'contratista_id': ctrl.selectedContratistaId,
      },
    };
  }

  /// Devuelve el tempId del padre si el ID seleccionado es temporal.
  /// BatchDraftController necesita esto para registrar la dependencia en el DAG.
  String? _resolveParentTempId(MasterDataSelectorController ctrl) {
    final parentId = switch (widget.tipo) {
      TipoFormulario.empresa => null,
      TipoFormulario.area => ctrl.selectedEmpresaId,
      TipoFormulario.contratista =>
        ctrl.selectedAreaId ?? ctrl.selectedEmpresaId,
      TipoFormulario.embarcacion => ctrl.selectedContratistaId,
    };
    // Solo es un "parent draft" si el ID empieza con 'temp_'
    return (parentId != null && parentId.startsWith('temp_')) ? parentId : null;
  }

  /// Devuelve el nombre del campo FK que apunta al padre.
  String? _resolveParentField() => switch (widget.tipo) {
    TipoFormulario.empresa => null,
    TipoFormulario.area => 'empresa_id',
    TipoFormulario.contratista =>
      widget.selectorCtrl.selectedAreaId != null ? 'area_id' : 'empresa_id',
    TipoFormulario.embarcacion => 'contratista_id',
  };

  String _entityLabel() => switch (widget.tipo) {
    TipoFormulario.empresa => 'Empresa',
    TipoFormulario.area => 'Área',
    TipoFormulario.contratista => 'Contratista',
    TipoFormulario.embarcacion => 'Embarcación',
  };

  // ---------------------------------------------------------------------------
  // Helper: ¿el ID actualmente seleccionado corresponde a un borrador?
  // ---------------------------------------------------------------------------

  bool _isSelectedTemp(List<SelectorOption> options, String? selectedId) {
    if (selectedId == null) return false;
    try {
      return options.firstWhere((o) => o.id == selectedId).isTemp;
    } catch (_) {
      return false;
    }
  }
}

// =============================================================================
// Widgets de soporte — sin lógica de negocio
// =============================================================================

/// Campo de descripción reutilizable.
class _DescripcionField extends StatelessWidget {
  const _DescripcionField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: const InputDecoration(
      labelText: 'Descripción',
      border: OutlineInputBorder(),
    ),
    maxLines: 2,
  );
}

/// Etiqueta de sección con badge "borrador" si la opción seleccionada es temporal.
class _TempBadgeLabel extends StatelessWidget {
  const _TempBadgeLabel({required this.label, required this.isTemp});
  final String label;
  final bool isTemp;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 0),
    child: Row(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        if (isTemp) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'borrador',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Banner de error para fallo en la carga de maestros.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.red.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
