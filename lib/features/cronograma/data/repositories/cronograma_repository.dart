import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio 100% online del módulo Cronograma (ver
/// docs/planificacion/02_en_progreso/PLAN_CRONOGRAMA_EMPRESAS_MVP.md).
/// Sin tablas `_pendientes` en SQLite, igual que Tickets.
class CronogramaRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------------------
  // Empresas de Cronograma
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getClientesEmpresas() async {
    final rows = await _client
        .from('cronograma_clientes_empresas')
        .select()
        .order('nombre');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> crearClienteEmpresa(String nombre, String? rut) async {
    await _client.from('cronograma_clientes_empresas').insert({
      'nombre': nombre.trim(),
      'rut': (rut == null || rut.trim().isEmpty) ? null : rut.trim(),
    });
  }

  Future<void> editarClienteEmpresa(
    String id,
    String nombre,
    String? rut,
    bool activo,
  ) async {
    await _client
        .from('cronograma_clientes_empresas')
        .update({
          'nombre': nombre.trim(),
          'rut': (rut == null || rut.trim().isEmpty) ? null : rut.trim(),
          'activo': activo,
        })
        .eq('id', id);
  }

  // ---------------------------------------------------------------------
  // Grupos de usuarios
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getGrupos() async {
    final rows = await _client
        .from('cronograma_grupos_usuarios')
        .select()
        .order('nombre');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> crearGrupo(String nombre, String? descripcion) async {
    await _client.from('cronograma_grupos_usuarios').insert({
      'nombre': nombre.trim(),
      'descripcion': (descripcion == null || descripcion.trim().isEmpty)
          ? null
          : descripcion.trim(),
    });
  }

  Future<void> editarGrupo(
    String id,
    String nombre,
    String? descripcion,
    bool activo,
  ) async {
    await _client
        .from('cronograma_grupos_usuarios')
        .update({
          'nombre': nombre.trim(),
          'descripcion': (descripcion == null || descripcion.trim().isEmpty)
              ? null
              : descripcion.trim(),
          'activo': activo,
        })
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getMiembrosGrupo(String grupoId) async {
    final rows = await _client
        .from('cronograma_grupo_usuarios')
        .select('id, usuario_id, activo, usuarios:usuario_id(nombre_completo)')
        .eq('grupo_id', grupoId)
        .eq('activo', true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> agregarMiembro(String grupoId, String usuarioId) async {
    await _client.from('cronograma_grupo_usuarios').upsert({
      'grupo_id': grupoId,
      'usuario_id': usuarioId,
      'activo': true,
    }, onConflict: 'grupo_id,usuario_id');
  }

  Future<void> quitarMiembro(String membresiaId) async {
    await _client
        .from('cronograma_grupo_usuarios')
        .update({'activo': false})
        .eq('id', membresiaId);
  }

  Future<List<Map<String, dynamic>>> getUsuarios() async {
    final rows = await _client
        .from('usuarios')
        .select('id, nombre_completo')
        .order('nombre_completo');
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
