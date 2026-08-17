import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/cronograma_admin_controller.dart';

/// Administración del módulo Cronograma dentro de Admin Maestros.
/// Empresas de Cronograma y Grupos ya son funcionales; Plantillas y Planes
/// quedan como placeholder hasta cerrar las preguntas pendientes con Jorge
/// (ver docs/planificacion/02_en_progreso/PLAN_CRONOGRAMA_EMPRESAS_MVP.md).
class CronogramaAdminScreen extends StatefulWidget {
  const CronogramaAdminScreen({super.key});

  @override
  State<CronogramaAdminScreen> createState() => _CronogramaAdminScreenState();
}

class _CronogramaAdminScreenState extends State<CronogramaAdminScreen> {
  late final CronogramaAdminController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CronogramaAdminController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _controller.cargar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_controller.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    _controller.error!,
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              _buildEmpresasSection(),
              const SizedBox(height: 20),
              _buildGruposSection(),
              const SizedBox(height: 20),
              _buildPlaceholderSection(
                icono: Icons.description_outlined,
                titulo: 'Plantillas de tarea',
                subtitulo: 'Tipos de tarea, frecuencia y módulo destino',
              ),
              const SizedBox(height: 12),
              _buildPlaceholderSection(
                icono: Icons.event_note,
                titulo: 'Planes / Cronogramas',
                subtitulo: 'Creación y duplicación de cronogramas por empresa',
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Empresas de Cronograma ────────────────────────────────────────────

  Widget _buildEmpresasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Empresas de Cronograma',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: AppTheme.primaryBlue,
              tooltip: 'Agregar empresa',
              onPressed: () => _showEmpresaDialog(),
            ),
          ],
        ),
        _buildTutorialBox('Como crear una empresa de cronograma', const [
          'Es el cliente al que le harás seguimiento (ej. "Aquachile"), independiente de las empresas del sistema.',
          'Cada empresa de cronograma podrá tener varios cronogramas (planes) más adelante.',
          'Desactivarla oculta sus cronogramas sin borrar el historial.',
        ]),
        if (_controller.clientesEmpresas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aún no hay empresas de cronograma creadas.'),
          )
        else
          ..._controller.clientesEmpresas.map(
            (e) => Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.apartment,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                title: Text(e['nombre']?.toString() ?? ''),
                subtitle: Text(
                  (e['activo'] == true)
                      ? (e['rut']?.toString() ?? 'Activa')
                      : 'Inactiva',
                ),
                trailing: const Icon(Icons.edit_outlined, color: Colors.grey),
                onTap: () => _showEmpresaDialog(row: e),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showEmpresaDialog({Map<String, dynamic>? row}) async {
    final nombreCtrl = TextEditingController(
      text: row?['nombre']?.toString() ?? '',
    );
    final rutCtrl = TextEditingController(text: row?['rut']?.toString() ?? '');
    bool activo = (row?['activo'] as bool?) ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(
            row == null ? 'Nueva empresa de cronograma' : 'Editar empresa',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rutCtrl,
                decoration: const InputDecoration(labelText: 'RUT (opcional)'),
              ),
              if (row != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activa'),
                  value: activo,
                  onChanged: (v) => setLocalState(() => activo = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || nombreCtrl.text.trim().isEmpty) return;

    final success = row == null
        ? await _controller.crearClienteEmpresa(nombreCtrl.text, rutCtrl.text)
        : await _controller.editarClienteEmpresa(
            row['id'] as String,
            nombreCtrl.text,
            rutCtrl.text,
            activo,
          );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Guardado.' : 'No se pudo guardar.')),
    );
  }

  // ─── Grupos y accesos ───────────────────────────────────────────────────

  Widget _buildGruposSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Grupos y accesos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: AppTheme.primaryBlue,
              tooltip: 'Agregar grupo',
              onPressed: () => _showGrupoDialog(),
            ),
          ],
        ),
        _buildTutorialBox('Como crear un grupo de usuarios', const [
          'Un grupo agrupa usuarios que compartirán el acceso a los mismos cronogramas (ej. "Grupo Aquachile").',
          'Agrega o quita miembros individualmente sin afectar a los demás grupos del usuario.',
          'Al asignar un cronograma a un grupo, todos sus miembros activos lo verán automáticamente.',
        ]),
        if (_controller.grupos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aún no hay grupos creados.'),
          )
        else
          ..._controller.grupos.map(
            (g) => Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(Icons.groups, color: AppTheme.primaryBlue),
                ),
                title: Text(g['nombre']?.toString() ?? ''),
                subtitle: Text(
                  g['descripcion']?.toString() ?? 'Sin descripción',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.people_outline,
                        color: Colors.grey,
                      ),
                      tooltip: 'Miembros',
                      onPressed: () => _showMiembrosSheet(g),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                      tooltip: 'Editar',
                      onPressed: () => _showGrupoDialog(row: g),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showGrupoDialog({Map<String, dynamic>? row}) async {
    final nombreCtrl = TextEditingController(
      text: row?['nombre']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: row?['descripcion']?.toString() ?? '',
    );
    bool activo = (row?['activo'] as bool?) ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(row == null ? 'Nuevo grupo' : 'Editar grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              if (row != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: activo,
                  onChanged: (v) => setLocalState(() => activo = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || nombreCtrl.text.trim().isEmpty) return;

    final success = row == null
        ? await _controller.crearGrupo(nombreCtrl.text, descCtrl.text)
        : await _controller.editarGrupo(
            row['id'] as String,
            nombreCtrl.text,
            descCtrl.text,
            activo,
          );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Guardado.' : 'No se pudo guardar.')),
    );
  }

  Future<void> _showMiembrosSheet(Map<String, dynamic> grupo) async {
    final grupoId = grupo['id'] as String;
    var miembros = await _controller.getMiembrosGrupo(grupoId);

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Miembros de ${grupo['nombre']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (miembros.isEmpty)
                  const Text('Sin miembros agregados todavía.')
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView(
                      shrinkWrap: true,
                      children: miembros.map((m) {
                        final nombre =
                            (m['usuarios'] as Map?)?['nombre_completo']
                                ?.toString() ??
                            'Usuario';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline),
                          title: Text(nombre),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              await _controller.quitarMiembro(
                                m['id'] as String,
                              );
                              miembros = await _controller.getMiembrosGrupo(
                                grupoId,
                              );
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Agregar usuario'),
                  onPressed: () async {
                    final yaAgregados = miembros
                        .map((m) => m['usuario_id']?.toString())
                        .toSet();
                    final disponibles = _controller.usuarios
                        .where(
                          (u) => !yaAgregados.contains(u['id']?.toString()),
                        )
                        .toList();
                    final seleccionado = await showDialog<String>(
                      context: ctx,
                      builder: (ctx2) => SimpleDialog(
                        title: const Text('Selecciona un usuario'),
                        children: disponibles.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'Todos los usuarios ya están en el grupo.',
                                  ),
                                ),
                              ]
                            : disponibles
                                  .map(
                                    (u) => SimpleDialogOption(
                                      onPressed: () => Navigator.pop(
                                        ctx2,
                                        u['id']?.toString(),
                                      ),
                                      child: Text(
                                        u['nombre_completo']?.toString() ?? '',
                                      ),
                                    ),
                                  )
                                  .toList(),
                      ),
                    );
                    if (seleccionado != null) {
                      await _controller.agregarMiembro(grupoId, seleccionado);
                      miembros = await _controller.getMiembrosGrupo(grupoId);
                      setSheetState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Placeholders (pendientes de definiciones con Jorge) ────────────────

  Widget _buildPlaceholderSection({
    required IconData icono,
    required String titulo,
    required String subtitulo,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          child: Icon(icono, color: AppTheme.primaryBlue),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.hourglass_empty, color: Colors.grey),
        onTap: null,
      ),
    );
  }
}
