import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/database_helper.dart';

class SyncService {
  final _supabase = Supabase.instance.client;
  final _dbHelper = DatabaseHelper.instance;

  // --- 1. DESCARGAR DATOS MAESTROS (Down-Sync) ---
  Future<void> descargarDatosMaestros() async {
    try {
      final results = await Future.wait([
        _supabase.from('areas').select('id, nombre'),
        _supabase.from('centros').select('id, nombre, area_id'),
        _supabase.from('contratistas').select('id, nombre'),
        _supabase.from('embarcaciones').select('id, nombre, contratista_id'),
        _supabase.from('formulario_items').select().eq('activo', true),
        // IMPORTANTE: También descargamos el personal externo existente para tener el dropdown lleno
        _supabase.from('personal_externo').select(),
      ]);

      await _dbHelper.guardarMaestros(
        'areas',
        List<Map<String, dynamic>>.from(results[0]),
      );
      await _dbHelper.guardarMaestros(
        'centros',
        List<Map<String, dynamic>>.from(results[1]),
      );
      await _dbHelper.guardarMaestros(
        'contratistas',
        List<Map<String, dynamic>>.from(results[2]),
      );
      await _dbHelper.guardarMaestros(
        'embarcaciones',
        List<Map<String, dynamic>>.from(results[3]),
      );
      await _dbHelper.guardarItemsOffline(
        List<Map<String, dynamic>>.from(results[4]),
      );

      // Guardamos el personal externo en SQLite para tenerlo offline
      await _dbHelper.guardarMaestros(
        'personal_externo',
        List<Map<String, dynamic>>.from(results[5]),
      );

      debugPrint("✅ Datos maestros actualizados offline.");
    } catch (e) {
      debugPrint("⚠️ No se pudieron actualizar maestros (Sin internet): $e");
    }
  }

  // --- 2. SUBIDA DE DATOS (Up-Sync) ---
  Future<int> sincronizarTodo() async {
    try {
      // 1. Subir Actividades (Y ahora sus datos hijos: Verificaciones y Participantes)
      int inspeccionesSubidas = await _sincronizarActividades();

      // 2. Subir el resto
      await _sincronizarRespuestas();
      await _sincronizarFotos();

      return inspeccionesSubidas;
    } catch (e) {
      debugPrint("❌ Error en sincronización: $e");
      rethrow;
    }
  }

  Future<int> _sincronizarActividades() async {
    final db = await _dbHelper.database;
    // Buscamos solo las que no han sido subidas
    final pendientes = await db.query(
      'actividades_pendientes',
      where: 'subido = 0',
    );

    if (pendientes.isEmpty) return 0;

    int count = 0;
    for (var row in pendientes) {
      final activityId = row['id'] as String;
      final tipoActividad = row['tipo_actividad'] as String;

      try {
        // A) Mapeo y Limpieza para la Nube
        // Creamos una copia para no modificar el objeto original de la fila
        // Dentro de _sincronizarActividades
        final datosParaNube = Map<String, dynamic>.from(row);

        // Mantenemos el estado que viene de SQLite (que debe ser 'En Progreso')
        // Solo si quieres que al FINALIZAR cambie, podrías agregar una lógica aquí
        // o manejarlo directamente desde el objeto que guardas.
        datosParaNube['puerto_abierto'] = (row['puerto_abierto'] == 1);
        datosParaNube.remove('subido');

        await _supabase.from('actividades').upsert(datosParaNube);

        // C) Subir Datos Relacionados (Hijos)
        if (tipoActividad == 'INSPECCION_BUCEO') {
          await _sincronizarVerificaciones(db, activityId);
          await _sincronizarParticipantes(db, activityId);
        }

        // D) Actualizar estado local
        // En lugar de borrar (para mantener historial offline), marcamos como subido = 1
        // O si prefieres borrar como tenías antes, descomenta la línea de abajo:
        // await db.delete('actividades_pendientes', where: 'id = ?', whereArgs: [activityId]);

        await db.update(
          'actividades_pendientes',
          {'subido': 1},
          where: 'id = ?',
          whereArgs: [activityId],
        );

        debugPrint("✅ Actividad $activityId sincronizada completa.");
        count++;
      } catch (e) {
        debugPrint("⚠️ Error subiendo actividad $activityId: $e");
        // Si falla, no actualizamos 'subido', así reintentará en la próxima sync
      }
    }
    return count;
  }

  // --- MÉTODOS AUXILIARES NUEVOS ---

  Future<void> _sincronizarVerificaciones(
    DatabaseExecutor db,
    String activityId,
  ) async {
    final results = await db.query(
      'verificaciones_buceo',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    if (results.isNotEmpty) {
      // Upsert directo a Supabase
      await _supabase.from('verificaciones_buceo').upsert(results.first);
    }
  }

  Future<void> _sincronizarParticipantes(
    DatabaseExecutor db,
    String activityId,
  ) async {
    // 1. Obtenemos la relación local
    final relaciones = await db.query(
      'actividad_participantes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    if (relaciones.isEmpty) return;

    for (var rel in relaciones) {
      final personalId = rel['personal_id'] as String;

      // 2. Buscamos los datos de la persona en SQLite para asegurarnos de subirla primero
      // (Por si creaste un buzo nuevo offline que no existe en la nube)
      final personaData = await db.query(
        'personal_externo',
        where: 'id = ?',
        whereArgs: [personalId],
      );

      if (personaData.isNotEmpty) {
        // Upsert de la Persona (Tabla Maestra)
        await _supabase.from('personal_externo').upsert(personaData.first);
      }

      // 3. Upsert de la Relación (Tabla Intermedia)
      final datosRelacion = Map<String, dynamic>.from(rel);
      datosRelacion['condiciones_optimas'] = (rel['condiciones_optimas'] == 1);

      await _supabase.from('actividad_participantes').upsert(datosRelacion);
    }
  }

  // --- MÉTODOS EXISTENTES (Sin cambios mayores) ---

  Future<int> _sincronizarRespuestas() async {
    final db = await _dbHelper.database;
    final pendientes = await db.query(
      'inspeccion_respuestas_pendientes',
      where: 'subido = 0',
    );
    if (pendientes.isEmpty) return 0;

    List<Map<String, dynamic>> batchParaNube = [];
    List<int> idsLocales = [];

    for (var row in pendientes) {
      idsLocales.add(row['id'] as int);
      batchParaNube.add({
        'actividad_id': row['actividad_id'],
        'item_id': row['item_id'],
        'estado': row['estado'],
        'observacion': row['observacion'],
        'criticidad_registrada': row['criticidad_registrada'],
      });
    }

    await _supabase.from('inspeccion_respuestas').insert(batchParaNube);

    for (var id in idsLocales) {
      await db.delete(
        'inspeccion_respuestas_pendientes',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return batchParaNube.length;
  }

  Future<int> _sincronizarFotos() async {
    final db = await _dbHelper.database;
    final fotosPendientes = await db.query(
      'fotos_pendientes',
      where: 'subido = 0',
    );
    if (fotosPendientes.isEmpty) return 0;

    int fotosSubidas = 0;

    for (var row in fotosPendientes) {
      final localId = row['id'] as int;
      final localPath = row['local_path'] as String;
      final actividadId = row['actividad_id'] as String;
      final itemId = row['item_id'] as String?;
      final descripcion = row['descripcion'] as String?;

      final file = File(localPath);
      if (!file.existsSync()) {
        await db.delete(
          'fotos_pendientes',
          where: 'id = ?',
          whereArgs: [localId],
        );
        continue;
      }

      try {
        final nombreArchivo = itemId != null
            ? '$itemId.jpg'
            : 'general/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final pathStorage = '$actividadId/$nombreArchivo';

        await _supabase.storage
            .from('evidencias')
            .upload(
              pathStorage,
              file,
              fileOptions: const FileOptions(upsert: true),
            );

        final publicUrl = _supabase.storage
            .from('evidencias')
            .getPublicUrl(pathStorage);

        await _supabase.from('registro_fotografico').insert({
          'actividad_id': actividadId,
          'inspeccion_respuesta_id': null,
          'foto_url': publicUrl,
          'descripcion': descripcion ?? '',
        });

        await db.delete(
          'fotos_pendientes',
          where: 'id = ?',
          whereArgs: [localId],
        );
        fotosSubidas++;
      } catch (e) {
        debugPrint("Error subiendo foto $localId: $e");
      }
    }
    return fotosSubidas;
  }
}
