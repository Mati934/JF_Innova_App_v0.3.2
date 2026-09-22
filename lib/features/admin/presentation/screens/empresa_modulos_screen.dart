import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/modules/module_registry.dart';
import '../../../../core/services/connectivity_service.dart';
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
        // Super-admin: ve todas las empresas
        final empresas = await _dbHelper.getAllEmpresas();
        _setStateSafe(() {
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
      _setStateSafe(() => _isLoading = false);
    }
  }

  Future<void> _cargarModulosDeEmpresa(String empresaId) async {
    _setStateSafe(() => _isLoading = true);
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('📂 CARGANDO MÓDULOS para empresa: $empresaId');

      // Si hay conexión, descargar módulos de esta empresa desde Supabase
      if (ConnectivityService().isOnline) {
        debugPrint('☁️ Online — descargando de Supabase primero...');
        await _descargarModulosDeSupabase(empresaId);
      } else {
        debugPrint('📴 Offline — usando datos locales');
      }

      final db = await _dbHelper.database;
      final rows = await db.query(
        'empresa_modulos',
        where: 'empresa_id = ?',
        whereArgs: [empresaId],
      );

      debugPrint('📦 SQLite tiene ${rows.length} filas para esta empresa');

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

      debugPrint('📋 Estado final de módulos:');
      for (var entry in _modulos.entries) {
        debugPrint('  ${entry.value.habilitado ? "✅" : "❌"} ${entry.key}');
      }
      debugPrint('═══════════════════════════════════════');

      _setStateSafe(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando módulos: $e');
      _setStateSafe(() => _isLoading = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (_selectedEmpresaId == null) return;

    _setStateSafe(() => _isSaving = true);
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();

      debugPrint('═══════════════════════════════════════');
      debugPrint(
        '📝 GUARDANDO MÓDULOS para empresa: $_selectedEmpresaNombre ($_selectedEmpresaId)',
      );

      for (var entry in _modulos.entries) {
        final key = entry.key;
        final state = entry.value;
        debugPrint(
          '  ${state.habilitado ? "✅" : "❌"} $key (orden: ${state.orden})',
        );

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
      debugPrint(
        '💾 SQLite OK — ${_modulos.length} módulos guardados (subido=0)',
      );

      // Verificar lo que quedó en SQLite
      final verificacion = await db.query(
        'empresa_modulos',
        where: 'empresa_id = ?',
        whereArgs: [_selectedEmpresaId],
      );
      debugPrint(
        '🔍 Verificación SQLite: ${verificacion.length} filas para esta empresa',
      );
      for (var row in verificacion) {
        debugPrint(
          '  → ${row['modulo_key']}: habilitado=${row['habilitado']}, subido=${row['subido']}',
        );
      }

      // Sincronizar inmediatamente a Supabase
      try {
        debugPrint('☁️ Subiendo a Supabase...');
        await SyncService().sincronizarEmpresaModulos();
        debugPrint('☁️ Supabase OK');

        // Verificar subido después del sync
        final postSync = await db.query(
          'empresa_modulos',
          where: 'empresa_id = ? AND subido = 0',
          whereArgs: [_selectedEmpresaId],
        );
        if (postSync.isEmpty) {
          debugPrint('✅ Todos los módulos sincronizados (subido=1)');
        } else {
          debugPrint(
            '⚠️ ${postSync.length} módulos aún pendientes (subido=0):',
          );
          for (var row in postSync) {
            debugPrint('  → ${row['modulo_key']}');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error sincronizando módulos a Supabase: $e');
      }
      debugPrint('═══════════════════════════════════════');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Módulos actualizados para $_selectedEmpresaNombre'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error guardando módulos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _setStateSafe(() => _isSaving = false);
    }
  }

  /// Descarga módulos de una empresa específica desde Supabase y los guarda en SQLite.
  Future<void> _descargarModulosDeSupabase(String empresaId) async {
    try {
      final data = await Supabase.instance.client
          .from('empresa_modulos')
          .select('id, empresa_id, modulo_key, habilitado, orden')
          .eq('empresa_id', empresaId);

      debugPrint(
        '☁️ Supabase retornó ${data.length} módulos para empresa $empresaId',
      );
      for (var row in data) {
        debugPrint('  → ${row['modulo_key']}: habilitado=${row['habilitado']}');
      }

      if (data.isNotEmpty) {
        await _dbHelper.guardarMaestros(
          'empresa_modulos',
          List<Map<String, dynamic>>.from(data),
          scopeWhere: 'empresa_id = ?',
          scopeArgs: [empresaId],
        );
        debugPrint('💾 Módulos de Supabase guardados en SQLite');
      } else {
        debugPrint(
          '⚠️ Supabase no tiene módulos para esta empresa (tabla vacía o no configurada)',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error descargando módulos de empresa $empresaId: $e');
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
