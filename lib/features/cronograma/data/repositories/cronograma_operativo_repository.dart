import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceso online al cronograma que ejecuta el usuario final.
class CronogramaOperativoRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String get _usuarioId => _client.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> getTareasDelPeriodo({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final rows = await _client
        .from('cronograma_tareas_programadas')
        .select('''
          id, cliente_empresa_id, fecha_programada, estado,
          tomada_por_id, tomada_at, completada_por_id, completada_at,
          completada_fuera_de_plazo, motivo_regularizacion, resultado_json,
          cronograma_plan_tareas!inner(
            id, nombre, frecuencia, tipo_tarea_id, plan_id,
            cronograma_tipos_tarea(id, nombre, target_module_key, usa_pantalla_generica),
            cronograma_planes!inner(id, nombre, cliente_empresa_id,
              cronograma_clientes_empresas(id, nombre, rut))
          )
        ''')
        .gte('fecha_programada', _date(desde))
        .lte('fecha_programada', _date(hasta))
        .order('fecha_programada');

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<bool> tomarTarea(String tareaId) async {
    final rows = await _client
        .from('cronograma_tareas_programadas')
        .update({
          'estado': 'TOMADA',
          'tomada_por_id': _usuarioId,
          'tomada_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tareaId)
        .inFilter('estado', ['PROGRAMADA', 'VENCIDA'])
        .isFilter('tomada_por_id', null)
        .select('id');

    if ((rows as List).isEmpty) return false;
    await _registrar(tareaId, 'TOMADA');
    return true;
  }

  Future<bool> soltarTarea(String tareaId) async {
    final rows = await _client
        .from('cronograma_tareas_programadas')
        .update({
          'estado': 'PROGRAMADA',
          'tomada_por_id': null,
          'tomada_at': null,
        })
        .eq('id', tareaId)
        .eq('tomada_por_id', _usuarioId)
        .inFilter('estado', ['TOMADA', 'EN_PROGRESO'])
        .select('id');

    if ((rows as List).isEmpty) return false;
    await _registrar(tareaId, 'SOLTADA');
    return true;
  }

  Future<bool> iniciarTarea(String tareaId) async {
    final rows = await _client
        .from('cronograma_tareas_programadas')
        .update({'estado': 'EN_PROGRESO'})
        .eq('id', tareaId)
        .eq('tomada_por_id', _usuarioId)
        .eq('estado', 'TOMADA')
        .select('id');

    if ((rows as List).isEmpty) return false;
    await _registrar(tareaId, 'INICIADA');
    return true;
  }

  Future<bool> completarTarea({
    required String tareaId,
    required String comentario,
  }) async {
    final rows = await _client
        .from('cronograma_tareas_programadas')
        .update({
          'estado': 'COMPLETADA',
          'completada_por_id': _usuarioId,
          'completada_at': DateTime.now().toUtc().toIso8601String(),
          'completada_fuera_de_plazo': false,
          'resultado_json': {'comentario': comentario.trim()},
        })
        .eq('id', tareaId)
        .eq('tomada_por_id', _usuarioId)
        .inFilter('estado', ['TOMADA', 'EN_PROGRESO'])
        .select('id');

    if ((rows as List).isEmpty) return false;
    await _registrar(tareaId, 'COMPLETADA', comentario: comentario.trim());
    return true;
  }

  Future<List<Map<String, dynamic>>> getHistorial(String tareaId) async {
    final rows = await _client
        .from('cronograma_tareas_historial')
        .select('id, accion, comentario, created_at, usuario_id')
        .eq('tarea_programada_id', tareaId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _registrar(
    String tareaId,
    String accion, {
    String? comentario,
  }) async {
    await _client.from('cronograma_tareas_historial').insert({
      'tarea_programada_id': tareaId,
      'accion': accion,
      'usuario_id': _usuarioId,
      'comentario': comentario,
    });
  }

  String _date(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }
}
