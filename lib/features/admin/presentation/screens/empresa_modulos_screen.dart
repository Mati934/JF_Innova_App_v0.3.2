import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/modules/module_registry.dart';
import '../../../../core/services/user_session.dart';
import '../../../sync/services/sync_service.dart';

class EmpresaModulosScreen extends StatefulWidget {
  final bool embedded;
  const EmpresaModulosScreen({super.key, this.embedded = false});

  @override
  State<EmpresaModulosScreen> createState() => _EmpresaModulosScreenState();
}

class _EmpresaModulosScreenState extends State<EmpresaModulosScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _empresas = [];
  String? _selectedEmpresaId;
  String _selectedEmpresaNombre = '';

  // Estado de módulos para la empresa seleccionada
  // key: modulo_key, value: {habilitado, orden, id, changed}
  Map<String, _ModuloState> _modulos = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
  }

  Future<void> _cargarEmpresas() async {
    setState(() => _isLoading = true);
    try {
      final session = UserSession();
      if (session.esSuperAdmin) {
        // Super-admin: ve todas las empresas
        final empresas = await _dbHelper.getAllEmpresas();
        setState(() {
          _empresas = empresas;
          _isLoading = false;
        });
      } else {
        // Admin normal: solo su empresa, carga módulos directo
        _selectedEmpresaId = session.empresaId;
        _selectedEmpresaNombre = session.empresaNombre ?? 'Mi empresa';
        await _cargarModulosDeEmpresa(_selectedEmpresaId!);
      }
    } catch (e) {
      debugPrint('Error cargando empresas: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarModulosDeEmpresa(String empresaId) async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'empresa_modulos',
        where: 'empresa_id = ?',
        whereArgs: [empresaId],
      );

      final existingKeys = rows.map((r) => r['modulo_key'] as String).toSet();

      _modulos = {};
      int orden = 0;

      // Primero los módulos que ya existen en la DB
      for (var row in rows) {
        final key = row['modulo_key'] as String;
        _modulos[key] = _ModuloState(
          id: row['id'] as String,
          habilitado: (row['habilitado'] as int) == 1,
          orden: row['orden'] as int? ?? orden,
          changed: false,
        );
        orden++;
      }

      // Agregar módulos del registry que no existen en la DB
      for (var mod in ModuleRegistry.all) {
        if (!existingKeys.contains(mod.moduleKey)) {
          _modulos[mod.moduleKey] = _ModuloState(
            id: const Uuid().v4(),
            habilitado: false,
            orden: orden,
            changed: false,
          );
          orden++;
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando módulos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (_selectedEmpresaId == null) return;

    setState(() => _isSaving = true);
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();

      for (var entry in _modulos.entries) {
        final key = entry.key;
        final state = entry.value;

        batch.insert('empresa_modulos', {
          'id': state.id,
          'empresa_id': _selectedEmpresaId!,
          'modulo_key': key,
          'habilitado': state.habilitado ? 1 : 0,
          'orden': state.orden,
          'subido': 0, // Marcado para sincronizar
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);

      // Sincronizar inmediatamente a Supabase
      try {
        await SyncService().sincronizarEmpresaModulos();
      } catch (e) {
        debugPrint('⚠️ Error sincronizando módulos: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Módulos actualizados para $_selectedEmpresaNombre'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando módulos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _selectedEmpresaId == null
        ? _buildEmpresaList()
        : _buildModulosList();

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
                    onPressed: _isSaving ? null : _guardarCambios,
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
                      backgroundColor: Colors.deepPurple,
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
        title: const Text('Módulos por Empresa'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedEmpresaId == null
          ? _buildEmpresaList()
          : _buildModulosList(),
      floatingActionButton: _selectedEmpresaId != null
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _guardarCambios,
              backgroundColor: Colors.deepPurple,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'Guardando...' : 'Guardar Cambios',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildEmpresaList() {
    if (_empresas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay empresas registradas',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _empresas.length,
      itemBuilder: (context, index) {
        final empresa = _empresas[index];
        final esEmpresaActual = empresa['id'] == UserSession().empresaId;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
              child: const Icon(Icons.business, color: Colors.deepPurple),
            ),
            title: Text(
              empresa['nombre'] ?? 'Sin nombre',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: esEmpresaActual
                ? const Text(
                    'Empresa activa',
                    style: TextStyle(color: Colors.deepPurple, fontSize: 12),
                  )
                : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _selectedEmpresaId = empresa['id'] as String;
              _selectedEmpresaNombre =
                  empresa['nombre'] as String? ?? 'Sin nombre';
              _cargarModulosDeEmpresa(_selectedEmpresaId!);
            },
          ),
        );
      },
    );
  }

  Widget _buildModulosList() {
    final moduleDefs = ModuleRegistry.all;
    final isSuperAdmin = UserSession().esSuperAdmin;

    return Column(
      children: [
        // Header con nombre de empresa y botón volver
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.deepPurple.withValues(alpha: 0.05),
          child: Row(
            children: [
              if (isSuperAdmin)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedEmpresaId = null;
                      _modulos = {};
                    });
                  },
                ),
              if (isSuperAdmin) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedEmpresaNombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Lista de módulos con switches
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: moduleDefs.length,
            itemBuilder: (context, index) {
              final mod = moduleDefs[index];
              final state = _modulos[mod.moduleKey];
              if (state == null) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: mod.color.withValues(alpha: 0.1),
                    child: Icon(mod.icon, color: mod.color, size: 20),
                  ),
                  title: Text(
                    mod.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(mod.subtitle),
                  value: state.habilitado,
                  activeThumbColor: Colors.deepPurple,
                  onChanged: (value) {
                    setState(() {
                      _modulos[mod.moduleKey] = _ModuloState(
                        id: state.id,
                        habilitado: value,
                        orden: state.orden,
                        changed: true,
                      );
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ModuloState {
  final String id;
  final bool habilitado;
  final int orden;
  final bool changed;

  _ModuloState({
    required this.id,
    required this.habilitado,
    required this.orden,
    required this.changed,
  });
}
