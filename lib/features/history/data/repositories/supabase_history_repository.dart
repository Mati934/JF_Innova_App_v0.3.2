import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHistoryRepository {
  final _client = Supabase.instance.client;

  // ⚠️ DEUDA TÉCNICA CRÍTICA: Este UUID hardcodeado debe moverse a variables de entorno
  // o resolverse mediante Custom Claims en el JWT. Si borras la tabla roles en tu BD, la app crasheará.
  static const String adminRoleId = '17fdb25f-aff2-49e4-95cf-157b041bfe1d';

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
      return data['rol_id'] == adminRoleId;
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

    // Excluir borradores y eliminados
    query = query
        .not('estado', 'eq', 'Eliminada')
        .not('estado', 'eq', 'En Progreso')
        .not('estado', 'eq', 'Borrador');

    final response = await query.order('fecha_realizacion', ascending: false);
    final rows = List<Map<String, dynamic>>.from(response);

    // Solo los admins ven la empresa de cada registro (resto solo ve los suyos).
    final Map<String, String> empresaPorUsuario = esAdmin
        ? await _getEmpresaPorUsuarioMap(
            rows
                .map((r) => r['usuario_id'] as String?)
                .whereType<String>()
                .toSet(),
          )
        : const {};

    return rows.map((item) {
      final usuarioId = item['usuario_id'] as String?;
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
        // Solo presente cuando el usuario actual es admin (resolución vía join en cliente).
        if (esAdmin && usuarioId != null)
          'empresa_nombre': empresaPorUsuario[usuarioId],
      };
    }).toList();
  }

  /// Devuelve un mapa `usuario_id -> nombre_empresa` para los IDs solicitados.
  /// Usado solo en vista de admin para etiquetar cada registro con su empresa.
  ///
  /// Fuente de verdad: tabla N:N `usuario_empresas` (consistente con
  /// `UserSession`). El campo legacy `usuarios.empresa_id` se ignora.
  /// Si un usuario tiene >1 empresa asociada, se toma la primera por nombre.
  Future<Map<String, String>> _getEmpresaPorUsuarioMap(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};
    try {
      final relaciones = await _client
          .from('usuario_empresas')
          .select('usuario_id, empresa_id')
          .inFilter('usuario_id', userIds.toList());

      final empresaIds = <String>{
        for (final r in relaciones)
          if (r['empresa_id'] != null) r['empresa_id'] as String,
      };

      if (empresaIds.isEmpty) return const {};

      final empresas = await _client
          .from('empresas')
          .select('id, nombre')
          .inFilter('id', empresaIds.toList())
          .order('nombre');

      final nombrePorEmpresa = <String, String>{
        for (final e in empresas)
          if (e['id'] != null && e['nombre'] != null)
            e['id'] as String: e['nombre'] as String,
      };

      // Para cada usuario, recoge sus empresas y elige la primera por nombre.
      final empresasPorUsuario = <String, List<String>>{};
      for (final r in relaciones) {
        final uid = r['usuario_id'] as String?;
        final eid = r['empresa_id'] as String?;
        if (uid == null || eid == null) continue;
        final nombre = nombrePorEmpresa[eid];
        if (nombre == null) continue;
        empresasPorUsuario.putIfAbsent(uid, () => []).add(nombre);
      }

      return <String, String>{
        for (final entry in empresasPorUsuario.entries)
          if (entry.value.isNotEmpty) entry.key: (entry.value..sort()).first,
      };
    } catch (e) {
      debugPrint('⚠️ No se pudo resolver empresa por usuario: $e');
      return const {};
    }
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
