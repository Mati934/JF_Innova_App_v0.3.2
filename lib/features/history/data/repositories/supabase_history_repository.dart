import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHistoryRepository {
  final _client = Supabase.instance.client;

  // ⚠️ DEUDA TÉCNICA CRÍTICA: Este UUID hardcodeado debe moverse a variables de entorno
  // o resolverse mediante Custom Claims en el JWT. Si borras la tabla roles en tu BD, la app crasheará.
  static const String ADMIN_ROLE_ID = '17fdb25f-aff2-49e4-95cf-157b041bfe1d';

  Future<bool> soyAdmin() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final data = await _client
          .from('usuarios')
          .select('rol_id')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return false;
      return data['rol_id'] == ADMIN_ROLE_ID;
    } catch (e) {
      debugPrint("⚠️ Error verificando admin: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHistorialGlobal({
    required bool esAdmin,
    String? filtroCentroId,
    String? filtroUsuarioId,
    String? filtroModulo,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception("Sesión nula.");

    // 🔥 1. Consulta plana y limpia. Cero joins en Dart.
    var query = _client.from('historial_unificado').select('*');

    if (!esAdmin) {
      query = query.eq('usuario_id', userId);
    } else if (filtroUsuarioId != null) {
      query = query.eq('usuario_id', filtroUsuarioId);
    }

    if (filtroCentroId != null) {
      query = query.eq('centro_id', filtroCentroId);
    }
    if (filtroModulo != null) {
      query = query.eq('modulo', filtroModulo);
    }

    final response = await query.order('fecha_realizacion', ascending: false);

    return List<Map<String, dynamic>>.from(response).map((item) {
      return {
        'id': item['id'],
        'modulo': item['modulo'],
        'tipo_registro': item['tipo_registro'],
        'estado': item['estado'],
        'ubicacion': item['ubicacion'],
        'fecha_realizacion': item['fecha_realizacion'],
        'numero_reporte': item['numero_reporte'],
        'pdf_url': item['pdf_url'],
        'inspector_nombre': item['inspector_nombre'] ?? 'Desconocido',
        'numero_seguimiento': item['numero_seguimiento'] ?? 0,
        // IDs de contexto usados para pre-rellenar el formulario de tickets
        'centro_id': item['centro_id'],
        'embarcacion_id': item['embarcacion_id'],
        'subido': 1,
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
