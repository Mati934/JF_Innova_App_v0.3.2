import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHistoryRepository {
  final _client = Supabase.instance.client;

  // ⚠️ IMPORTANTE: Este UUID debe coincidir EXACTAMENTE con el de tu tabla 'roles' en Supabase
  // Según tu imagen era: 17fdb25f-aff2-49e4-95cf-157b041bfe1d
  static const String ADMIN_ROLE_ID = '17fdb25f-aff2-49e4-95cf-157b041bfe1d';

  /// Verifica si el usuario actual tiene el rol de ADMINISTRADOR
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

      final rolIdUsuario = data['rol_id'] as String?;
      return rolIdUsuario == ADMIN_ROLE_ID;
    } catch (e) {
      debugPrint("⚠️ Error verificando admin: $e");
      return false;
    }
  }

  /// Trae el historial filtrado desde la NUBE
  Future<List<Map<String, dynamic>>> getHistorialGlobal({
    required bool esAdmin,
    String? filtroCentroId,
    String? filtroUsuarioId,
  }) async {
    final userId = _client.auth.currentUser?.id;

    // Seleccionamos todo y hacemos JOINs para traer nombres
    // OJO: La sintaxis de Supabase para joins anidados es específica
    var query = _client
        .from('actividades')
        .select('''
      *,
      centro:centros(nombre),
      usuario:usuarios(nombre_completo),
      contratista:contratistas(nombre),
      embarcacion:embarcaciones(nombre)
    ''')
        .eq('estado_final', 'En Seguimiento');

    // --- APLICAR SEGURIDAD ---
    if (!esAdmin) {
      // Si NO es admin, forzamos que solo vea lo suyo
      query = query.eq('usuario_id', userId!);
    } else if (filtroUsuarioId != null) {
      // Si ES admin y eligió un usuario en el filtro
      query = query.eq('usuario_id', filtroUsuarioId);
    }

    // --- APLICAR FILTROS COMUNES ---
    if (filtroCentroId != null) {
      query = query.eq('centro_id', filtroCentroId);
    }

    // Ordenar por fecha
    final response = await query.order('fecha_realizacion', ascending: false);

    // Mapeo para aplanar la estructura y que se parezca a lo que devuelve SQLite
    // SQLite devuelve 'centro_nombre', Supabase devuelve {centro: {nombre: ...}}
    return List<Map<String, dynamic>>.from(response).map((item) {
      final mutableItem = Map<String, dynamic>.from(item);

      // Aplanamos los datos para que la UI no se rompa
      if (item['centro'] != null)
        mutableItem['centro_nombre'] = item['centro']['nombre'];
      if (item['usuario'] != null)
        mutableItem['inspector_nombre'] = item['usuario']['nombre_completo'];
      if (item['contratista'] != null)
        mutableItem['contratista_nombre'] = item['contratista']['nombre'];
      if (item['embarcacion'] != null)
        mutableItem['embarcacion_nombre'] = item['embarcacion']['nombre'];

      if (item['numero_informe'] != null) {
        mutableItem['numero_reporte'] = item['numero_informe'];
      }

      // Normalizamos el subido (Supabase no tiene esta columna, pero si viene de nube es true)
      mutableItem['subido'] = 1;

      return mutableItem;
    }).toList();
  }

  // Listas para los filtros
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
