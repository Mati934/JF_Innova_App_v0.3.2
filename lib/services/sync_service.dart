import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';

class SyncService {
  final _supabase = Supabase.instance.client;
  final _dbHelper = DatabaseHelper.instance;

  // --- 1. DESCARGAR DATOS MAESTROS (Para que el Setup funcione Offline) ---
  Future<void> descargarDatosMaestros() async {
    try {
      final results = await Future.wait([
        _supabase.from('areas').select('id, nombre'),
        _supabase.from('centros').select('id, nombre, area_id'),
        _supabase.from('contratistas').select('id, nombre'),
        _supabase.from('embarcaciones').select('id, nombre, contratista_id'),
        _supabase.from('formulario_items').select().eq('activo', true),
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

      debugPrint("✅ Datos maestros actualizados offline.");
    } catch (e) {
      debugPrint("⚠️ No se pudieron actualizar maestros (Sin internet): $e");
    }
  }

  // --- 2. SUBIDA DE DATOS (Up-Sync) ---
  // Modificamos para devolver cantidad de INSPECCIONES (Actividades), no items sueltos
  Future<int> sincronizarTodo() async {
    try {
      // 1. Subir Actividades y GUARDAR CUANTAS SUBIMOS
      int inspeccionesSubidas = await _sincronizarActividades();

      // 2. Subir el resto (Respuestas y Fotos)
      // Ya no sumamos esto al contador final para no confundir al usuario
      await _sincronizarRespuestas();
      await _sincronizarFotos();

      return inspeccionesSubidas;
    } catch (e) {
      debugPrint("❌ Error en sincronización: $e");
      rethrow;
    }
  }

  // Ahora devuelve int (cantidad)
  Future<int> _sincronizarActividades() async {
    final db = await _dbHelper.database;
    final pendientes = await db.query(
      'actividades_pendientes',
      where: 'subido = 0',
    );

    if (pendientes.isEmpty) return 0;

    int count = 0;
    for (var row in pendientes) {
      try {
        final datosParaNube = Map<String, dynamic>.from(row);
        datosParaNube.remove('subido');
        datosParaNube['puerto_abierto'] = (row['puerto_abierto'] == 1);

        await _supabase.from('actividades').upsert(datosParaNube);

        await db.delete(
          'actividades_pendientes',
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        debugPrint("✅ Actividad ${row['id']} sincronizada.");
        count++; // Contamos éxito
      } catch (e) {
        debugPrint("⚠️ Error subiendo actividad ${row['id']}: $e");
        throw Exception("Falló subida de actividad padre. Cancelando resto.");
      }
    }
    return count;
  }

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

    // Insertar lote
    await _supabase.from('inspeccion_respuestas').insert(batchParaNube);

    // Borrar locales
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
