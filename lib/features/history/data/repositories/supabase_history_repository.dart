import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHistoryRepository {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getHistorialGlobal({
    required bool esAdmin,
    required bool esSuperAdmin,
    required String? empresaId,
    String? filtroCentroId,
    String? filtroUsuarioId,
    String? filtroModulo,
  }) async {
    if (_client.auth.currentUser == null) throw Exception('Sesión nula.');

    final response = await _client.rpc(
      'historial_autorizado',
      params: {
        // La RPC valida nuevamente el rol y la pertenencia a empresa. Estos
        // valores solo definen el alcance solicitado por la UI.
        'p_empresa_id': esSuperAdmin ? null : (esAdmin ? empresaId : null),
        'p_usuario_id': esAdmin ? filtroUsuarioId : null,
        'p_centro_id': filtroCentroId,
        'p_modulo': filtroModulo,
      },
    );
    final rows = List<Map<String, dynamic>>.from(response);

    return rows.map((item) {
      return {
        'id': item['id'],
        'modulo': item['modulo'],
        'tipo_registro': item['tipo_registro'],
        'estado': item['estado'],
        'ubicacion': item['ubicacion'],
        'fecha_realizacion': item['fecha_realizacion'],
        'numero_reporte': item['numero_reporte'],
        'pdf_url': item['pdf_url'],
        'pdf_certificado_url': item['pdf_certificado_url'],
        'inspector_nombre': item['inspector_nombre'],
        'numero_seguimiento': item['numero_seguimiento'] ?? 0,
        // IDs de contexto usados para pre-rellenar el formulario de tickets
        'centro_id': item['centro_id'],
        'embarcacion_id': item['embarcacion_id'],
        'subido': 1,
        if (esSuperAdmin) 'empresa_nombre': item['empresa_nombre'],
      };
    }).toList();
  }

  // --- Catálogos ---
  Future<List<Map<String, dynamic>>> getCentros() async {
    final res = await _client
        .from('centros')
        .select('id, nombre')
        .order('nombre');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getUsuarios() async {
    final res = await _client
        .from('usuarios')
        .select('id, nombre_completo')
        .order('nombre_completo');
    return List<Map<String, dynamic>>.from(res);
  }
}
