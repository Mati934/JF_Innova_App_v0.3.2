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

        // --- 🟢 NUEVO: ASEGURAR NÚMERO DE SEGUIMIENTO ---
        // Nos aseguramos que nunca vaya null, si es null mandamos 0 (Inicial)
        datosParaNube['numero_seguimiento'] = row['numero_seguimiento'] ?? 0;
        // ------------------------------------------------

        // --- 1. TRADUCCIÓN DE NOMBRES ---
        // Sacamos el valor local
        final reporteLocal = row['numero_reporte'];

        // Lo asignamos a la columna de Supabase
        datosParaNube['numero_informe'] = reporteLocal;

        // Borramos la clave local para que no de error de "columna no existe"
        datosParaNube.remove('numero_reporte');
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

  // En SyncService.dart

  Future<void> _sincronizarVerificaciones(
    DatabaseExecutor db,
    String activityId,
  ) async {
    // 1. Buscamos el registro en SQLite
    final results = await db.query(
      'verificaciones_buceo',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    if (results.isNotEmpty) {
      try {
        // 2. Limpieza de datos (Importante)
        // Creamos una copia editable del mapa
        final data = Map<String, dynamic>.from(results.first);

        // Eliminamos columnas que sean SOLO locales (si tienes alguna como 'id_sqlite')
        // Si no tienes columnas extra locales, esto igual asegura que sea un mapa limpio

        // 3. Upsert a Supabase
        // Usamos upsert para que sirva tanto para guardar borrador (insert)
        // como para actualizar cambios finales (update)
        await _supabase
            .from('verificaciones_buceo')
            .upsert(
              data,
              onConflict: 'actividad_id',
            ); // Asegúrate que la PK sea actividad_id o la que definiste

        debugPrint("✅ Verificaciones de buceo sincronizadas para $activityId");
      } catch (e) {
        debugPrint("⚠️ Error subiendo verificaciones buceo: $e");
      }
    }
  }

  // En SyncService.dart

  Future<void> _sincronizarParticipantes(
    DatabaseExecutor db,
    String activityId,
  ) async {
    // 1. Obtener la lista de relaciones locales
    final relaciones = await db.query(
      'actividad_participantes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    // --- LIMPIEZA DE HUÉRFANOS (Sin cambios, tu lógica estaba bien) ---
    try {
      final idsVigentes = relaciones.map((r) => r['personal_id']).toList();
      if (idsVigentes.isNotEmpty) {
        await _supabase
            .from('actividad_participantes')
            .delete()
            .eq('actividad_id', activityId)
            .filter('personal_id', 'not.in', '(${idsVigentes.join(',')})');
      } else {
        await _supabase
            .from('actividad_participantes')
            .delete()
            .eq('actividad_id', activityId);
      }
    } catch (e) {
      debugPrint("⚠️ Error limpiando participantes antiguos: $e");
    }
    // ----------------------------------------------------------------

    if (relaciones.isEmpty) return;

    for (var rel in relaciones) {
      final personalId = rel['personal_id'] as String;

      // --- PASO A: Asegurar que la PERSONA exista en Supabase ---
      final personaData = await db.query(
        'personal_externo',
        where: 'id = ?',
        whereArgs: [personalId],
      );

      if (personaData.isNotEmpty) {
        final raw = personaData.first;

        // 1. CREAMOS EL PAQUETE COMPLETO (Incluyendo contratista_id)
        final datosLimpios = {
          'id': raw['id'],
          'rut': raw['rut'],
          'nombre_completo': raw['nombre_completo'],
          'cargo': raw['cargo'],
          'activo': (raw['activo'] == 1),
          'matricula': raw['matricula'],
          // ✅ FIX CRÍTICO: Enviamos el ID del contratista padre
          'contratista_id': raw['contratista_id'],
        };

        try {
          await _supabase.from('personal_externo').upsert(datosLimpios);
          // Si pasa aquí, la persona existe en la nube.
        } catch (e) {
          // 🛑 SI FALLA LA PERSONA, ABORTAMOS EL VÍNCULO
          debugPrint(
            "🔥 Error CRÍTICO subiendo persona (${raw['nombre_completo']}): $e",
          );
          debugPrint("Saltando vínculo para evitar crash FK...");
          continue; // Pasamos al siguiente del bucle, no intentamos vincular
        }
      } else {
        debugPrint(
          "⚠️ ALERTA: ID $personalId en relación pero no en tabla personal local.",
        );
        continue;
      }

      // --- PASO B: Subir la RELACIÓN (Solo llegamos aquí si el PASO A funcionó) ---
      try {
        final datosRelacion = Map<String, dynamic>.from(rel);
        if (rel['condiciones_optimas'] is int) {
          datosRelacion['condiciones_optimas'] =
              (rel['condiciones_optimas'] == 1);
        }
        await _supabase.from('actividad_participantes').upsert(datosRelacion);
      } catch (e) {
        debugPrint("❌ Error vinculando participante: $e");
      }
    }
    debugPrint("✅ Cuadrilla sincronizada.");
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

    await _supabase
        .from('inspeccion_respuestas')
        .upsert(
          batchParaNube,
          onConflict:
              'actividad_id, item_id', // Asegúrate de tener este constraint en Supabase
        );

    // 2. ACTUALIZAR LOCALMENTE (NO BORRAR)
    for (var id in idsLocales) {
      await db.update(
        'inspeccion_respuestas_pendientes',
        {'subido': 1}, // ✅ MARCAMOS COMO SUBIDO
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    debugPrint(
      "✅ Respuestas sincronizadas y marcadas localmente (${batchParaNube.length})",
    );
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
        // Si el archivo físico no está, borramos el registro huérfano para limpiar
        await db.delete(
          'fotos_pendientes',
          where: 'id = ?',
          whereArgs: [localId],
        );
        continue;
      }

      try {
        // --- 1. NOMBRE DETERMINISTA ---
        // NO generamos uno nuevo con DateTime. Usamos el que ya tiene el archivo.
        // Esto evita duplicados si se resube la misma foto.
        final nombreArchivoReal = file.uri.pathSegments.last;

        // Estructura: ID_ACTIVIDAD / NOMBRE_ARCHIVO
        final pathStorage = '$actividadId/$nombreArchivoReal';

        // --- 2. SUBIDA OPTIMIZADA ---
        // upsert: true hace que si ya existe, la sobrescriba (ahorra errores)
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

        // --- 3. EVITAR DUPLICADOS EN TABLA SQL DE SUPABASE ---
        // Verificamos si esta URL ya está registrada para esta actividad
        final existe = await _supabase
            .from('registro_fotografico')
            .select('id')
            .eq('actividad_id', actividadId)
            .eq('foto_url', publicUrl)
            .maybeSingle();

        if (existe == null) {
          await _supabase.from('registro_fotografico').insert({
            'actividad_id': actividadId,
            'inspeccion_respuesta_id': null, // O vincular si tienes la lógica
            'foto_url': publicUrl,
            'descripcion': descripcion ?? '',
            // 'item_id': itemId // SUGERENCIA: Deberías guardar el item_id en Supabase si puedes
          });
        } else {
          // Opcional: Actualizar descripción si cambió
          debugPrint(
            "📸 La foto ya estaba registrada en nube, saltando insert.",
          );
        }

        // --- 4. ACTUALIZAR LOCALMENTE (NO BORRAR) ---
        // CRÍTICO: No borres el registro, solo márcalo como subido.
        // Así el Controller lo sigue encontrando.
        await db.update(
          'fotos_pendientes',
          {'subido': 1},
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
