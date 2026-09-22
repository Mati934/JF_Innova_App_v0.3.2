import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/user_session.dart';
import '../../../configurable_checklists/domain/checklist_admin_state.dart';
import '../../../configurable_checklists/domain/checklist_catalog_seed.dart';
import '../../../configurable_checklists/domain/models/configurable_checklist.dart';
import '../../../configurable_checklists/presentation/checklist_icons.dart';

/// Administra la visibilidad de los nodos del motor de checklists
/// configurables (grupos y checklists sueltos) por empresa.
///
/// A diferencia de [EmpresaModulosScreen], esta pantalla escribe directo a
/// Supabase (requiere conexion): checklist_navigation_nodes aun no tiene una
/// cola de sincronizacion local tipo "subido".
class ChecklistNodesAdminScreen extends StatefulWidget {
  final bool embedded;
  const ChecklistNodesAdminScreen({super.key, this.embedded = false});

  @override
  State<ChecklistNodesAdminScreen> createState() =>
      _ChecklistNodesAdminScreenState();
}

class _ChecklistNodesAdminScreenState extends State<ChecklistNodesAdminScreen> {
  final _dbHelper = DatabaseHelper.instance;

  List<Map<String, dynamic>> _empresas = [];
  String? _selectedEmpresaId;
  String _selectedEmpresaNombre = '';

  List<ChecklistNavigationNode> _nodes = [];
  List<ChecklistAdminFamily> _families = [];
  // Estado editable por carpeta: family.id -> estado.
  final Map<String, ChecklistAdminFamilyState> _familyStates = {};
  bool _hayCambios = false;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isOnboarding = false;

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
  }

  Future<void> _cargarEmpresas() async {
    _setStateSafe(() => _isLoading = true);
    try {
      final session = UserSession();
      if (session.esSuperAdmin) {
        final empresas = await _dbHelper.getAllEmpresas();
        _setStateSafe(() {
          _empresas = empresas;
          _isLoading = false;
        });
      } else {
        _selectedEmpresaId = session.empresaId;
        _selectedEmpresaNombre = session.empresaNombre ?? 'Mi empresa';
        await _cargarNodosDeEmpresa(_selectedEmpresaId!);
      }
    } catch (e) {
      debugPrint('Error cargando empresas (checklists admin): $e');
      _setStateSafe(() => _isLoading = false);
    }
  }

  Future<void> _cargarNodosDeEmpresa(String empresaId) async {
    _setStateSafe(() => _isLoading = true);
    try {
      // Se lee siempre desde Supabase: guardarMaestros() esta hardcodeado
      // por tabla con clave 'id' y checklist_navigation_nodes usa node_key,
      // asi que esta pantalla no cachea en SQLite (requiere conexion).
      final data = await Supabase.instance.client
          .from('checklist_navigation_nodes')
          .select()
          .eq('empresa_id', empresaId)
          .order('orden');
      final rows = List<Map<String, dynamic>>.from(data);
      final tieneHerramientas = rows.any(
        (row) => herramientasChecklistCatalog.any(
          (def) => def.checklistKey == row['checklist_key'],
        ),
      );
      if (tieneHerramientas) {
        try {
          await _asegurarPermisosHerramientas(empresaId);
        } catch (e) {
          debugPrint('Error CHECKLIST_GRANTS_SYNC: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error CHECKLIST_GRANTS_SYNC: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      _nodes = rows.map(ChecklistNavigationNode.fromMap).toList();
      _families = buildChecklistAdminFamilies(_nodes);
      _familyStates
        ..clear()
        ..addEntries(
          _families.map(
            (f) => MapEntry(f.id, ChecklistAdminFamilyState.fromFamily(f)),
          ),
        );
      _hayCambios = false;
      // El espejo local manda en Inicio: sin esto habia que entrar y salir
      // dos veces para ver el cambio (Inicio lee SQLite, no Supabase).
      await _dbHelper.reemplazarNavigationNodesEmpresa(empresaId, rows);
      _setStateSafe(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando nodos de checklists: $e');
      _setStateSafe(() => _isLoading = false);
    }
  }

  ChecklistAdminFamilyState _estadoDe(ChecklistAdminFamily family) =>
      _familyStates[family.id] ?? ChecklistAdminFamilyState.fromFamily(family);

  void _actualizarEstado(
    ChecklistAdminFamily family,
    ChecklistAdminFamilyState nuevo,
  ) {
    setState(() {
      _familyStates[family.id] = nuevo;
      _hayCambios = true;
    });
  }

  Future<List<String>> _cargarUsuarioIdsEmpresa(String empresaId) async {
    final responses = await Future.wait([
      Supabase.instance.client
          .from('usuarios')
          .select('id, empresa_id')
          .eq('empresa_id', empresaId),
      Supabase.instance.client
          .from('usuario_empresas')
          .select('usuario_id, empresa_id')
          .eq('empresa_id', empresaId),
    ]);
    return resolveEmpresaUserIds(
      empresaId: empresaId,
      legacyUsers: List<Map<String, dynamic>>.from(responses[0]),
      empresaLinks: List<Map<String, dynamic>>.from(responses[1]),
    );
  }

  Future<int> _asegurarPermisosHerramientas(String empresaId) async {
    final usuarioIds = await _cargarUsuarioIdsEmpresa(empresaId);
    if (usuarioIds.isEmpty) return 0;

    final candidatos = buildHerramientasPermissionGrantRows(
      empresaId: empresaId,
      usuarioIds: usuarioIds,
    );
    final existentes = await Supabase.instance.client
        .from('checklist_permission_grants')
        .select('checklist_key, usuario_id, capacidad')
        .eq('empresa_id', empresaId)
        .inFilter(
          'checklist_key',
          herramientasChecklistCatalog.map((d) => d.checklistKey).toList(),
        );
    final yaExiste = List<Map<String, dynamic>>.from(existentes)
        .map(
          (row) =>
              '${row['checklist_key']}|${row['usuario_id']}|${row['capacidad']}',
        )
        .toSet();
    final nuevos = candidatos
        .where(
          (row) => !yaExiste.contains(
            '${row['checklist_key']}|${row['usuario_id']}|${row['capacidad']}',
          ),
        )
        .toList();
    if (nuevos.isNotEmpty) {
      await Supabase.instance.client
          .from('checklist_permission_grants')
          .insert(nuevos);
    }
    return nuevos.length;
  }

  /// Crea, para la empresa seleccionada, el catalogo de Herramientas y
  /// Equipos (1 grupo + 5 hijos agrupados + 5 sueltos, mas los permisos de
  /// sus usuarios actuales). Es seguro reintentar: usa upsert con
  /// ignoreDuplicates, asi que no duplica filas si ya existian.
  Future<void> _habilitarCatalogoHerramientas() async {
    if (_selectedEmpresaId == null) return;
    _setStateSafe(() => _isOnboarding = true);
    try {
      final empresaId = _selectedEmpresaId!;
      final nodos = buildHerramientasNavigationRows(empresaId);
      await Supabase.instance.client
          .from('checklist_navigation_nodes')
          .upsert(nodos, onConflict: 'node_key', ignoreDuplicates: true);

      final usuarioIds = await _cargarUsuarioIdsEmpresa(empresaId);
      await _asegurarPermisosHerramientas(empresaId);

      await _cargarNodosDeEmpresa(empresaId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Catálogo de Herramientas y Equipos habilitado para $_selectedEmpresaNombre'
            '${usuarioIds.isEmpty ? ' (sin usuarios activos: sin permisos otorgados aún)' : ''}.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      debugPrint('Error CHECKLIST_ONBOARD_EMPRESA: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error CHECKLIST_ONBOARD_EMPRESA: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setStateSafe(() => _isOnboarding = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (_selectedEmpresaId == null) return;

    final actual = {for (final n in _nodes) n.key: n.habilitado};
    final deseado = <String, bool>{};
    for (final family in _families) {
      deseado.addAll(resolveChecklistNodeStates(family, _estadoDe(family)));
    }
    final pendientes = deseado.entries
        .where((e) => actual[e.key] != e.value)
        .toList();
    if (pendientes.isEmpty) {
      _setStateSafe(() => _hayCambios = false);
      return;
    }

    _setStateSafe(() => _isSaving = true);
    final fallidos = <String>[];
    try {
      for (final entry in pendientes) {
        try {
          // Un UPDATE bloqueado por RLS devuelve 0 filas SIN error, por eso se
          // pide el retorno y se verifica que haya afectado la fila.
          final actualizados = await Supabase.instance.client
              .from('checklist_navigation_nodes')
              .update({
                'habilitado': entry.value,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('node_key', entry.key)
              .select('node_key');
          if (List<Map<String, dynamic>>.from(actualizados).isEmpty) {
            debugPrint(
              'Error CHECKLIST_NODE_TOGGLE en ${entry.key}: 0 filas '
              'actualizadas (posible bloqueo RLS)',
            );
            fallidos.add(entry.key);
          }
        } catch (e) {
          debugPrint('Error CHECKLIST_NODE_TOGGLE en ${entry.key}: $e');
          fallidos.add(entry.key);
        }
      }
      await _cargarNodosDeEmpresa(_selectedEmpresaId!);
      if (!mounted) return;
      if (fallidos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Checklists actualizados para $_selectedEmpresaNombre',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error CHECKLIST_NODE_TOGGLE en ${fallidos.length} elementos. Revisa tu conexión o tus permisos (RLS).',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _setStateSafe(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _selectedEmpresaId == null
        ? _buildEmpresaList()
        : _buildNodosList();

    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: body),
          if (_selectedEmpresaId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_isSaving || !_hayCambios)
                        ? null
                        : _guardarCambios,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar Cambios'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklists por Empresa'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }

  Widget _buildEmpresaList() {
    if (_empresas.isEmpty) {
      return const Center(
        child: Text(
          'No hay empresas registradas',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _empresas.length,
      itemBuilder: (context, index) {
        final empresa = _empresas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withValues(alpha: 0.1),
              child: const Icon(Icons.business, color: Colors.teal),
            ),
            title: Text(empresa['nombre'] ?? 'Sin nombre'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _selectedEmpresaId = empresa['id'] as String;
              _selectedEmpresaNombre =
                  empresa['nombre'] as String? ?? 'Sin nombre';
              _cargarNodosDeEmpresa(_selectedEmpresaId!);
            },
          ),
        );
      },
    );
  }

  Widget _buildNodosList() {
    final isSuperAdmin = UserSession().esSuperAdmin;

    if (_nodes.isEmpty) {
      return Column(
        children: [
          _buildHeader(isSuperAdmin),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Esta empresa aún no tiene checklists configurados.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isOnboarding
                          ? null
                          : _habilitarCatalogoHerramientas,
                      icon: _isOnboarding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: Text(
                        _isOnboarding
                            ? 'Habilitando...'
                            : 'Habilitar Herramientas y Equipos',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildHeader(isSuperAdmin),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _families.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildFamilyCard(_families[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyCard(ChecklistAdminFamily family) {
    final estado = _estadoDe(family);
    final activos = family.items
        .where((i) => estado.checklistsActivos[i.checklistKey] ?? false)
        .length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withValues(alpha: 0.12),
              child: Icon(
                family.groupNode == null
                    ? Icons.checklist
                    : checklistIconFromName(family.icono),
                color: Colors.teal.shade700,
              ),
            ),
            title: Text(
              family.titulo,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              !estado.moduloActivo
                  ? 'Desactivado · no aparece en Inicio'
                  : family.soportaAgrupacion && estado.agrupado
                  ? '1 tarjeta con $activos checklist(s) adentro'
                  : '$activos tarjeta(s) suelta(s) en Inicio',
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.power_settings_new),
            title: const Text('Activar módulo'),
            subtitle: const Text('Muestra estos checklists en Inicio'),
            value: estado.moduloActivo,
            activeThumbColor: Colors.teal.shade700,
            onChanged: (v) =>
                _actualizarEstado(family, estado.copyWith(moduloActivo: v)),
          ),
          if (family.soportaAgrupacion)
            SwitchListTile(
              secondary: const Icon(Icons.folder_outlined),
              title: const Text('Agrupar en una carpeta'),
              subtitle: Text(
                estado.agrupado
                    ? 'Una sola tarjeta que abre el listado'
                    : 'Cada checklist como tarjeta independiente',
              ),
              value: estado.agrupado,
              activeThumbColor: Colors.teal.shade700,
              onChanged: estado.moduloActivo
                  ? (v) =>
                        _actualizarEstado(family, estado.copyWith(agrupado: v))
                  : null,
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Checklists incluidos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          for (final item in family.items)
            SwitchListTile(
              secondary: Icon(checklistIconFromName(item.icono)),
              title: Text(item.titulo),
              value: estado.checklistsActivos[item.checklistKey] ?? false,
              activeThumbColor: Colors.teal.shade700,
              onChanged: estado.moduloActivo
                  ? (v) => _actualizarEstado(
                      family,
                      estado.copyWith(
                        checklistsActivos: {
                          ...estado.checklistsActivos,
                          item.checklistKey: v,
                        },
                      ),
                    )
                  : null,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isSuperAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.teal.withValues(alpha: 0.05),
      child: Row(
        children: [
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedEmpresaId = null;
                _nodes = [];
                _families = [];
                _familyStates.clear();
                _hayCambios = false;
              }),
            ),
          if (isSuperAdmin) const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedEmpresaNombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
