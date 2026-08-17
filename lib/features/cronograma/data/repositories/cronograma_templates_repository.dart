import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Repository 100% online para administración de Plantillas de Cronograma.
/// Maneja: Tipos de Tarea, Plantillas, Asignaciones a Empresas Cliente.
class CronogramaTemplatesRepository {
  final _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  // TIPOS DE TAREA
  // ─────────────────────────────────────────────────────────────────────────

  /// Obtiene todos los tipos de tarea activos
  Future<List<Map<String, dynamic>>> getTiposTarea() async {
    final response = await _supabase
        .from('cronograma_tipos_tarea')
        .select()
        .eq('activo', true)
        .order('nombre');
    return response as List<Map<String, dynamic>>;
  }

  /// Crea un nuevo tipo de tarea
  Future<Map<String, dynamic>> crearTipoTarea({
    required String codigo,
    required String nombre,
    String? targetModuleKey,
    bool usaPantallaGenerica = false,
    Map<String, dynamic>? evidenciaConfigJson,
  }) async {
    final response = await _supabase
        .from('cronograma_tipos_tarea')
        .insert({
          'codigo': codigo,
          'nombre': nombre,
          'target_module_key': targetModuleKey,
          'usa_pantalla_generica': usaPantallaGenerica,
          'evidencia_config_json': evidenciaConfigJson ?? {},
          'activo': true,
        })
        .select()
        .single();
    return response as Map<String, dynamic>;
  }

  /// Actualiza un tipo de tarea
  Future<Map<String, dynamic>> actualizarTipoTarea({
    required String id,
    String? nombre,
    String? targetModuleKey,
    bool? usaPantallaGenerica,
    Map<String, dynamic>? evidenciaConfigJson,
    bool? activo,
  }) async {
    final update = <String, dynamic>{};
    if (nombre != null) update['nombre'] = nombre;
    if (targetModuleKey != null) update['target_module_key'] = targetModuleKey;
    if (usaPantallaGenerica != null)
      update['usa_pantalla_generica'] = usaPantallaGenerica;
    if (evidenciaConfigJson != null)
      update['evidencia_config_json'] = evidenciaConfigJson;
    if (activo != null) update['activo'] = activo;

    final response = await _supabase
        .from('cronograma_tipos_tarea')
        .update(update)
        .eq('id', id)
        .select()
        .single();
    return response as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PLANTILLAS
  // ─────────────────────────────────────────────────────────────────────────

  /// Obtiene todas las plantillas activas
  Future<List<Map<String, dynamic>>> getPlantillas() async {
    final response = await _supabase
        .from('cronograma_plantillas')
        .select()
        .eq('activo', true)
        .order('nombre');
    return response as List<Map<String, dynamic>>;
  }

  /// Obtiene una plantilla con sus tareas
  Future<Map<String, dynamic>> getPlantillaConTareas(String plantillaId) async {
    final plantilla = await _supabase
        .from('cronograma_plantillas')
        .select()
        .eq('id', plantillaId)
        .single();

    final tareas = await _supabase
        .from('cronograma_plantilla_tareas')
        .select('''
          id, nombre, frecuencia, orden, config_periodo_json, parametros_json,
          cronograma_tipos_tarea:tipo_tarea_id(id, codigo, nombre, target_module_key)
          ''')
        .eq('plantilla_id', plantillaId)
        .order('orden');

    return {
      ...plantilla as Map<String, dynamic>,
      'tareas': tareas as List<dynamic>,
    };
  }

  /// Crea una nueva plantilla
  Future<Map<String, dynamic>> crearPlantilla({
    required String nombre,
    String? descripcion,
  }) async {
    final response = await _supabase
        .from('cronograma_plantillas')
        .insert({'nombre': nombre, 'descripcion': descripcion, 'activo': true})
        .select()
        .single();
    return response as Map<String, dynamic>;
  }

  /// Actualiza una plantilla
  Future<Map<String, dynamic>> actualizarPlantilla({
    required String id,
    String? nombre,
    String? descripcion,
    bool? activo,
  }) async {
    final update = <String, dynamic>{};
    if (nombre != null) update['nombre'] = nombre;
    if (descripcion != null) update['descripcion'] = descripcion;
    if (activo != null) update['activo'] = activo;

    final response = await _supabase
        .from('cronograma_plantillas')
        .update(update)
        .eq('id', id)
        .select()
        .single();
    return response as Map<String, dynamic>;
  }

  /// Elimina una plantilla (soft delete)
  Future<void> eliminarPlantilla(String plantillaId) async {
    await _supabase
        .from('cronograma_plantillas')
        .update({'activo': false})
        .eq('id', plantillaId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAREAS DE PLANTILLA
  // ─────────────────────────────────────────────────────────────────────────

  /// Agrega una tarea a una plantilla
  Future<Map<String, dynamic>> agregarTareaAPlantilla({
    required String plantillaId,
    required String tipoTareaId,
    required String nombre,
    required String frecuencia,
    int orden = 0,
    Map<String, dynamic>? configPeriodoJson,
    Map<String, dynamic>? parametrosJson,
  }) async {
    final response = await _supabase
        .from('cronograma_plantilla_tareas')
        .insert({
          'plantilla_id': plantillaId,
          'tipo_tarea_id': tipoTareaId,
          'nombre': nombre,
          'frecuencia': frecuencia,
          'orden': orden,
          'config_periodo_json': configPeriodoJson ?? {},
          'parametros_json': parametrosJson ?? {},
        })
        .select()
        .single();
    return response as Map<String, dynamic>;
  }

  /// Actualiza una tarea de plantilla
  Future<Map<String, dynamic>> actualizarTareaPlantilla({
    required String id,
    String? nombre,
    String? frecuencia,
    int? orden,
    Map<String, dynamic>? configPeriodoJson,
    Map<String, dynamic>? parametrosJson,
  }) async {
    final update = <String, dynamic>{};
    if (nombre != null) update['nombre'] = nombre;
    if (frecuencia != null) update['frecuencia'] = frecuencia;
    if (orden != null) update['orden'] = orden;
    if (configPeriodoJson != null)
      update['config_periodo_json'] = configPeriodoJson;
    if (parametrosJson != null) update['parametros_json'] = parametrosJson;

    final response = await _supabase
        .from('cronograma_plantilla_tareas')
        .update(update)
        .eq('id', id)
        .select()
        .single();
    return response as Map<String, dynamic>;
  }

  /// Elimina una tarea de plantilla
  Future<void> eliminarTareaPlantilla(String tareaId) async {
    await _supabase
        .from('cronograma_plantilla_tareas')
        .delete()
        .eq('id', tareaId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ASIGNACIONES A EMPRESAS CLIENTE
  // ─────────────────────────────────────────────────────────────────────────

  /// Obtiene asignaciones de plantillas (con relaciones)
  Future<List<Map<String, dynamic>>> getAsignaciones() async {
    final response = await _supabase
        .from('cronograma_plantilla_asignaciones')
        .select('''
          id, activa, vigente_desde, vigente_hasta, auto_generar_plan,
          cronograma_plantillas:plantilla_id(id, nombre, descripcion),
          cronograma_clientes_empresas:cliente_empresa_id(id, nombre, rut)
          ''')
        .eq('activa', true)
        .order('created_at', ascending: false);
    return response as List<Map<String, dynamic>>;
  }

  /// Crea una asignación de plantilla a empresa cliente
  Future<Map<String, dynamic>> crearAsignacion({
    required String plantillaId,
    required String clienteEmpresaId,
    DateTime? vigenteDesde,
    DateTime? vigentaHasta,
    bool autoGenerarPlan = true,
  }) async {
    final response = await _supabase
        .from('cronograma_plantilla_asignaciones')
        .insert({
          'plantilla_id': plantillaId,
          'cliente_empresa_id': clienteEmpresaId,
          'vigente_desde': vigenteDesde?.toIso8601String().split('T')[0],
          'vigente_hasta': vigentaHasta?.toIso8601String().split('T')[0],
          'auto_generar_plan': autoGenerarPlan,
          'activa': true,
        })
        .select()
        .single();
    return response as Map<String, dynamic>;
  }

  /// Desactiva una asignación
  Future<void> desactivarAsignacion(String asignacionId) async {
    await _supabase
        .from('cronograma_plantilla_asignaciones')
        .update({'activa': false})
        .eq('id', asignacionId);
  }
}
