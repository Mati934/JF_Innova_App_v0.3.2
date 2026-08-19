import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/help_button_appbar.dart';
import '../controllers/cronograma_templates_controller.dart';

/// Pantalla de administración de PLANTILLAS de cronograma (módulo independiente).
/// Solo visible para: Servimaf (empresa administradora) y usuarios con CRONOGRAMA_ADMIN.
///
/// Funcionalidad:
/// - CRUD de Tipos de Tarea
/// - CRUD de Plantillas de tarea
/// - CRUD de Asignaciones a empresas cliente
class CronogramaTemplatesAdminScreen extends StatefulWidget {
  const CronogramaTemplatesAdminScreen({super.key});

  @override
  State<CronogramaTemplatesAdminScreen> createState() =>
      _CronogramaTemplatesAdminScreenState();
}

class _CronogramaTemplatesAdminScreenState
    extends State<CronogramaTemplatesAdminScreen>
    with TickerProviderStateMixin {
  late final CronogramaTemplatesController _controller;
  late final TabController _tabController;

  static const _titles = ['Tipos de Tarea', 'Plantillas', 'Asignaciones'];

  static const _helpTexts = [
    'Aquí defines los tipos de tareas que se pueden crear (ej. "Inspección", "Mantenimiento"). Cada tipo puede estar vinculado a un módulo específico (inspección, tickets, etc.).',
    'Las plantillas agrupan tareas relacionadas con una frecuencia. Por ejemplo, una plantilla de "Mantenimiento Mensual" contiene varias tareas que se repiten cada mes.',
    'Asigna las plantillas a las empresas cliente. Cuando actives una plantilla para una empresa, se generarán automáticamente los cronogramas según la frecuencia definida.',
  ];

  @override
  void initState() {
    super.initState();
    _controller = CronogramaTemplatesController();
    _tabController = TabController(length: _titles.length, vsync: this);
    _controller.cargar();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Plantillas de Cronograma'),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Ayuda',
                onPressed: () => showHelpBottomSheet(
                  context: context,
                  titles: _titles,
                  helpTexts: _helpTexts,
                  activeTabIndex: _tabController.index,
                ),
                icon: const Icon(Icons.help_outline),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
              tabs: _titles.map((t) => Tab(text: t)).toList(),
            ),
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTiposTab(),
                    _buildPlantillasTab(),
                    _buildAsignacionesTab(),
                  ],
                ),
          floatingActionButton: _controller.isLoading
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    switch (_tabController.index) {
                      case 0:
                        _showTipoDialog();
                        break;
                      case 1:
                        _showPlantillaDialog();
                        break;
                      case 2:
                        _showAsignacionDialog();
                        break;
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text(switch (_tabController.index) {
                    0 => 'Agregar tipo',
                    1 => 'Agregar plantilla',
                    2 => 'Agregar asignación',
                    _ => 'Agregar',
                  }),
                ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: TIPOS DE TAREA
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTiposTab() {
    final tipos = _controller.tiposTarea;

    return RefreshIndicator(
      onRefresh: _controller.cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTutorialBox('Cómo crear un tipo de tarea', const [
            'Cada tipo tiene un código único (ej. "INSP_BASICA").',
            'Opcionalmente vincula a un módulo destino (inspección, tickets, etc.).',
            'Los tipos inactivos no se pueden usar en nuevas plantillas.',
          ]),
          const SizedBox(height: 12),
          if (tipos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Sin tipos de tarea creados aún'),
              ),
            )
          else
            ...tipos.map((tipo) {
              final id = tipo['id']?.toString() ?? '';
              final codigo = tipo['codigo']?.toString() ?? '';
              final nombre = tipo['nombre']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  title: Text(nombre),
                  subtitle: Text(codigo),
                  trailing: PopupMenuButton(
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        onTap: () => _showTipoDialog(row: tipo),
                        child: const Text('Editar'),
                      ),
                      PopupMenuItem(
                        onTap: () => _eliminarTipo(id),
                        child: const Text('Desactivar'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: PLANTILLAS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPlantillasTab() {
    final plantillas = _controller.plantillas;

    return RefreshIndicator(
      onRefresh: _controller.cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTutorialBox('Cómo crear una plantilla', const [
            'Una plantilla agrupa tareas relacionadas (ej. "Mantenimiento Mensual").',
            'Define la frecuencia de repetición para cada tarea.',
            'Las plantillas se asignan luego a empresas cliente.',
          ]),
          const SizedBox(height: 12),
          if (plantillas.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Sin plantillas creadas aún'),
              ),
            )
          else
            ...plantillas.map((plantilla) {
              final id = plantilla['id']?.toString() ?? '';
              final nombre = plantilla['nombre']?.toString() ?? '';
              final descripcion = plantilla['descripcion']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  title: Text(nombre),
                  subtitle: Text(
                    descripcion.isNotEmpty ? descripcion : '(Sin descripción)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        onTap: () => _showPlantillaDialog(row: plantilla),
                        child: const Text('Editar'),
                      ),
                      PopupMenuItem(
                        onTap: () => _mostrarTareasPlantilla(id),
                        child: const Text('Ver tareas'),
                      ),
                      PopupMenuItem(
                        onTap: () => _eliminarPlantilla(id),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: ASIGNACIONES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAsignacionesTab() {
    final asignaciones = _controller.asignaciones;

    return RefreshIndicator(
      onRefresh: _controller.cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTutorialBox('Cómo asignar una plantilla', const [
            'Selecciona la plantilla y la empresa cliente destino.',
            'Opcionalmente define período de vigencia (desde/hasta).',
            'Al activar, se generan automáticamente los cronogramas.',
            'Los usuarios de esa empresa verán las tareas en su módulo Cronograma.',
          ]),
          const SizedBox(height: 12),
          if (asignaciones.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Sin asignaciones creadas aún'),
              ),
            )
          else
            ...asignaciones.map((asignacion) {
              final id = asignacion['id']?.toString() ?? '';
              final plantilla =
                  asignacion['cronograma_plantillas'] as Map<String, dynamic>?;
              final empresa =
                  asignacion['cronograma_clientes_empresas']
                      as Map<String, dynamic>?;

              final plantillaNombre = plantilla?['nombre']?.toString() ?? '';
              final empresaNombre = empresa?['nombre']?.toString() ?? '';
              final empresaRut = empresa?['rut']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(plantillaNombre),
                  subtitle: Text(
                    '$empresaNombre${empresaRut.isNotEmpty ? " ($empresaRut)" : ""}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'generar') _showGenerarDialog(id);
                      if (value == 'desactivar') _desactivarAsignacion(id);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'generar',
                        child: Text('Generar cronograma'),
                      ),
                      PopupMenuItem(
                        value: 'desactivar',
                        child: Text('Desactivar asignación'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showTipoDialog({Map<String, dynamic>? row}) async {
    final codigoCtrl = TextEditingController(
      text: row?['codigo']?.toString() ?? '',
    );
    final nombreCtrl = TextEditingController(
      text: row?['nombre']?.toString() ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          row == null ? 'Nuevo tipo de tarea' : 'Editar tipo de tarea',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codigoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código (ej: INSP_BASICA)',
                ),
                enabled: row == null,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      if (row == null) {
        await _controller.crearTipoTarea(
          codigo: codigoCtrl.text,
          nombre: nombreCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Tipo de tarea creado')));
        }
      } else {
        await _controller.actualizarTipoTarea(
          id: row['id']?.toString() ?? '',
          nombre: nombreCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tipo de tarea actualizado')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showPlantillaDialog({Map<String, dynamic>? row}) async {
    final nombreCtrl = TextEditingController(
      text: row?['nombre']?.toString() ?? '',
    );
    final descripcionCtrl = TextEditingController(
      text: row?['descripcion']?.toString() ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row == null ? 'Nueva plantilla' : 'Editar plantilla'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      if (row == null) {
        await _controller.crearPlantilla(
          nombre: nombreCtrl.text,
          descripcion: descripcionCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Plantilla creada')));
        }
      } else {
        await _controller.actualizarPlantilla(
          id: row['id']?.toString() ?? '',
          nombre: nombreCtrl.text,
          descripcion: descripcionCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plantilla actualizada')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showAsignacionDialog() async {
    final plantillas = _controller.plantillas;
    final empresas = _controller.clientesEmpresas;
    String? selectedPlantilla = plantillas.isEmpty
        ? null
        : plantillas.first['id']?.toString();
    String? selectedEmpresa = empresas.isEmpty
        ? null
        : empresas.first['id']?.toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva asignación'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Selecciona una plantilla'),
                value: selectedPlantilla,
                items: plantillas
                    .map(
                      (p) => DropdownMenuItem(
                        value: p['id']?.toString(),
                        child: Text(p['nombre']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  selectedPlantilla = val;
                },
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Selecciona una empresa cliente'),
                value: selectedEmpresa,
                items: empresas
                    .map(
                      (empresa) => DropdownMenuItem(
                        value: empresa['id']?.toString(),
                        child: Text(empresa['nombre']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  selectedEmpresa = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (ok != true || selectedPlantilla == null || selectedEmpresa == null) {
      if (ok == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona una plantilla y una empresa cliente'),
          ),
        );
      }
      return;
    }

    try {
      await _controller.crearAsignacion(
        plantillaId: selectedPlantilla!,
        clienteEmpresaId: selectedEmpresa!,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Asignación creada')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showGenerarDialog(String asignacionId) async {
    final now = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar cronograma'),
        content: const Text(
          'Se creará un plan y sus tareas programadas para el año actual. '
          'Las instancias existentes no se duplicarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _controller.generarCronogramaDesdeAsignacion(
        asignacionId: asignacionId,
        desde: DateTime(now.year, 1, 1),
        hasta: DateTime(now.year, 12, 31),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cronograma generado correctamente')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCIONES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _eliminarTipo(String tipoId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar tipo de tarea'),
        content: const Text(
          '¿Desactivar este tipo? No se podrá usar en nuevas plantillas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _controller.actualizarTipoTarea(id: tipoId, activo: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tipo desactivado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _eliminarPlantilla(String plantillaId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: const Text('¿Eliminar esta plantilla?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _controller.eliminarPlantilla(plantillaId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Plantilla eliminada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _desactivarAsignacion(String asignacionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar asignación'),
        content: const Text('¿Desactivar esta asignación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _controller.desactivarAsignacion(asignacionId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Asignación desactivada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _mostrarTareasPlantilla(String plantillaId) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ver tareas - en desarrollo')));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

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
}
