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
        debugPrint("🚀 Iniciando Sync de Actividad: $activityId");

        // 1. Preparamos datos limpios para la nube
        final datosParaNube = Map<String, dynamic>.from(row);

        // Conversión de tipos
        datosParaNube['puerto_abierto'] = (row['puerto_abierto'] == 1);
        datosParaNube['numero_seguimiento'] = row['numero_seguimiento'] ?? 0;

        // LIMPIEZA CRÍTICA: Quitamos columnas que solo existen en SQLite
        // Si mandamos 'numero_reporte' o 'subido' a Supabase, fallará.
        datosParaNube.remove('numero_reporte');
        datosParaNube.remove('subido');

        // --- LÓGICA INTELIGENTE (Insert vs Update) ---

        final numeroLocal = row['numero_reporte'];
        // Verificamos si ya tiene un número real (no null, no vacío, no "null")
        final yaTieneNumero =
            numeroLocal != null &&
            numeroLocal.toString().isNotEmpty &&
            numeroLocal.toString() != "null";

        if (yaTieneNumero) {
          // CASO A: ACTUALIZACIÓN (UPDATE)
          // Ya tiene folio, así que solo actualizamos el resto de datos.
          // NO usamos upsert para no quemar la secuencia.

          // Quitamos 'numero_informe' del mapa para no tocarlo en la nube
          datosParaNube.remove('numero_informe');

          await _supabase
              .from('actividades')
              .update(datosParaNube)
              .eq('id', activityId);

          debugPrint(
            "🔄 Actividad actualizada (Folio existente: $numeroLocal).",
          );
        } else {
          // CASO B: CREACIÓN (UPSERT/INSERT)
          // No tiene folio, es nueva. Dejamos que Supabase asigne uno.

          // Aseguramos que NO vaya el campo numero_informe para que se active el IDENTITY
          datosParaNube.remove('numero_informe');

          final response = await _supabase
              .from('actividades')
              .upsert(datosParaNube)
              .select('numero_informe') // <--- PEDIMOS EL NUEVO NÚMERO
              .single();

          final nuevoNumero = response['numero_informe'];
          debugPrint("✨ ASIGNADO EN NUBE: #$nuevoNumero");

          // GUARDAMOS EL NÚMERO EN EL CELULAR
          await db.update(
            'actividades_pendientes',
            {'numero_reporte': nuevoNumero.toString()},
            where: 'id = ?',
            whereArgs: [activityId],
          );
          debugPrint("💾 Guardado en SQLite correctamente.");
        }

        // --- SUBIDA DE HIJOS ---
        if (tipoActividad == 'INSPECCION_BUCEO') {
          await _sincronizarVerificaciones(db, activityId);
          await _sincronizarParticipantes(db, activityId);
        }

        // MARCAR COMO SUBIDO LOCALMENTE
        await db.update(
          'actividades_pendientes',
          {'subido': 1},
          where: 'id = ?',
          whereArgs: [activityId],
        );

        count++;
        debugPrint("✅ Sincronización finalizada para $activityId");
      } catch (e) {
        debugPrint("🔥 ERROR CRÍTICO subiendo actividad $activityId: $e");
      }
    }
    return count;
  }
  // --- MÉTODOS AUXILIARES NUEVOS ---

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
      final itemId =
          row['item_id'] as String?; // Puede ser null si es foto general
      final descripcion = row['descripcion'] as String?;

      final file = File(localPath);
      if (!file.existsSync()) {
        // Limpieza de basura: Si el archivo no existe, borramos el registro
        await db.delete(
          'fotos_pendientes',
          where: 'id = ?',
          whereArgs: [localId],
        );
        continue;
      }

      try {
        // 1. BUSQUEDA DE ID PADRE (CRÍTICO)
        // Si la foto pertenece a un item, necesitamos el ID de la respuesta en Supabase (FK)
        int?
        respuestaIdNube; // Supabase usa int8 (int) o uuid (String) según tu diseño. Asumo int o String.

        if (itemId != null) {
          final respuestaData = await _supabase
              .from('inspeccion_respuestas')
              .select('id')
              .eq('actividad_id', actividadId)
              .eq('item_id', itemId)
              .maybeSingle(); // maybeSingle no lanza error si no encuentra nada

          if (respuestaData != null) {
            respuestaIdNube = respuestaData['id'];
          } else {
            // WARN: Tenemos foto para un item, pero la respuesta no subió aún.
            // Opcion A: Saltamos esta foto hasta la próxima sync.
            // Opcion B: La subimos sin vínculo (no recomendado).
            debugPrint(
              "⚠️ Foto huérfana para item $itemId. Saltando hasta sync de respuestas.",
            );
            continue;
          }
        }

        // 2. SUBIDA AL STORAGE
        final nombreArchivoReal = file.uri.pathSegments.last;
        final pathStorage = '$actividadId/$nombreArchivoReal';

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

        // 3. INSERT EN BASE DE DATOS (CON VÍNCULO)
        // Usamos upsert para evitar duplicados si se corta internet a mitad de camino
        final datosFoto = {
          'actividad_id': actividadId,
          'foto_url': publicUrl,
          'descripcion': descripcion ?? '',
          // AQUÍ ESTÁ LA MAGIA: Vinculamos con la respuesta real
          'inspeccion_respuesta_id': respuestaIdNube,
        };

        // Limpiamos nulos si tu tabla no los acepta, o déjalos si son nullable
        if (respuestaIdNube == null)
          datosFoto.remove('inspeccion_respuesta_id');

        await _supabase
            .from('registro_fotografico') // Asegúrate que la tabla se llama así
            .upsert(
              datosFoto,
              onConflict: 'foto_url',
            ); // O tu constraint unique

        // 4. ACTUALIZAR LOCALMENTE
        await db.update(
          'fotos_pendientes',
          {'subido': 1},
          where: 'id = ?',
          whereArgs: [localId],
        );

        fotosSubidas++;
      } catch (e) {
        debugPrint("❌ Error subiendo foto $localId: $e");
      }
    }
    return fotosSubidas;
  }
}
