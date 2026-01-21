import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jf_innova_app/features/inspection/domain/models/buceo_verificacion_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/participante_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../../../core/database/database_helper.dart';

class LocalInspectionRepository implements InspectionRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>?> getActividad(String activityId) async {
    final db = await dbHelper.database;
    try {
      final result = await db.query(
        'actividades_pendientes',
        where: 'id = ?',
        whereArgs: [activityId],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint("❌ Error obteniendo actividad $activityId: $e");
      return null;
    }
  }

  Future<void> eliminarBorrador(String activityId) async {
    final db = await dbHelper.database;
    final supabase = Supabase.instance.client;

    try {
      // 1. Borrar de Supabase (Si alcanzó a subirse)
      // Gracias a 'ON DELETE CASCADE' en tu SQL, borrar la actividad borrará sus hijos
      await supabase.from('actividades').delete().eq('id', activityId);

      // 2. Borrar de SQLite
      await db.delete(
        'fotos_pendientes',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );
      await db.delete(
        'inspeccion_respuestas_pendientes',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );
      await db.delete(
        'verificaciones_buceo',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );
      await db.delete(
        'actividad_participantes',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );
      await db.delete(
        'actividades_pendientes',
        where: 'id = ?',
        whereArgs: [activityId],
      );

      debugPrint("🗑️ Inspección eliminada de local y nube: $activityId");
    } catch (e) {
      debugPrint("❌ Error eliminando: $e");
    }
  }

  Future<void> saveActividad({
    required String id,
    required String tipoActividad,
    required String? centroId,
    required DateTime fecha,
    String? usuarioId,
    String? contratistaId,
    String? embarcacionId,
    String? estado,
  }) async {
    final db = await dbHelper.database;
    try {
      // 1. Intentamos ACTUALIZAR primero (Operación Segura)
      // Esto mantiene el mismo ID y NO dispara el borrado en cascada.
      int count = await db.update(
        'actividades_pendientes',
        {
          'tipo_actividad': tipoActividad,
          'centro_id': centroId,
          'usuario_id': usuarioId,
          'contratista_id': contratistaId,
          'embarcacion_id': embarcacionId,
          'fecha_realizacion': fecha.toIso8601String(),
          'subido': 0,
          'estado_final': estado ?? 'En Progreso',
          'puerto_abierto': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // 2. Si count es 0, significa que no existe. INSERTAMOS.
      if (count == 0) {
        await db.insert('actividades_pendientes', {
          'id': id,
          'tipo_actividad': tipoActividad,
          'centro_id': centroId,
          'usuario_id': usuarioId,
          'contratista_id': contratistaId,
          'embarcacion_id': embarcacionId,
          'fecha_realizacion': fecha.toIso8601String(),
          'subido': 0,
          'estado_final': estado ?? 'En Progreso',
          'puerto_abierto': 1,
        });
        debugPrint("💾 ACTIVIDAD CREADA: $id");
      } else {
        debugPrint("💾 ACTIVIDAD ACTUALIZADA: $id");
      }
    } catch (e) {
      debugPrint("❌ ERROR AL GUARDAR ACTIVIDAD: $e");
      throw e;
    }
  }

  @override
  Future<List<FormularioItem>> getItems(String tipoActividad) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'formulario_items',
      where: 'tipo_actividad = ? AND activo = 1',
      whereArgs: [tipoActividad],
      orderBy: 'orden ASC',
    );
    return result.map((json) => FormularioItem.fromJson(json)).toList();
  }

  @override
  Future<void> saveRespuestasBatch(
    List<Map<String, dynamic>> respuestas,
  ) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    try {
      for (var resp in respuestas) {
        batch.delete(
          'inspeccion_respuestas_pendientes',
          where: 'actividad_id = ? AND item_id = ?',
          whereArgs: [resp['actividad_id'], resp['item_id']],
        );
        batch.insert('inspeccion_respuestas_pendientes', {
          'actividad_id': resp['actividad_id'],
          'item_id': resp['item_id'],
          'estado': resp['estado'],
          'observacion': resp['observacion'],
          'criticidad_registrada': resp['criticidad_registrada'],
          'subido': 0, // Marcamos como pendiente de subida
        });
      }
      await batch.commit(noResult: true);
      debugPrint("💾 Respuestas guardadas (${respuestas.length} items).");
    } catch (e) {
      debugPrint("❌ Error guardando respuestas batch: $e");
    }
  }

  @override
  Future<void> saveFoto({
    required String activityId,
    required String? itemId,
    required XFile file,
    required String descripcion,
  }) async {
    final db = await dbHelper.database;
    try {
      await db.insert('fotos_pendientes', {
        'actividad_id': activityId,
        'item_id': itemId,
        'local_path': file.path,
        'descripcion': descripcion,
        'subido': 0,
      });
      debugPrint("📸 Foto guardada localmente.");
    } catch (e) {
      debugPrint("❌ Error guardando foto: $e");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await dbHelper.database;
    try {
      // --- FIX: Quitamos el filtro 'subido = 0' ---
      // Queremos ver TODOS los borradores locales, aunque ya se hayan respaldado en la nube.
      final result = await db.rawQuery('''
        SELECT a.*, c.nombre as nombre_centro 
        FROM actividades_pendientes a
        LEFT JOIN centros c ON a.centro_id = c.id
        WHERE a.estado_final = 'En Progreso'
        ORDER BY a.fecha_realizacion DESC
      ''');

      debugPrint("📋 Borradores recuperados para la UI: ${result.length}");
      return result;
    } catch (e) {
      debugPrint("❌ ERROR LEYENDO BORRADORES: $e");
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> cargarRespuestasGuardadas(
    String activityId,
  ) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'inspeccion_respuestas_pendientes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );
    Map<String, dynamic> mapa = {};
    for (var row in result) {
      final itemId = row['item_id'] as String;
      mapa[itemId] = {
        'estado': row['estado'],
        'observacion': row['observacion'],
        'criticidad': row['criticidad_registrada'],
      };
    }
    return mapa;
  }

  Future<List<Map<String, dynamic>>> getFotosPendientes(
    String activityId,
  ) async {
    final db = await dbHelper.database;
    return await db.query(
      'fotos_pendientes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );
  }
  // --- MÉTODOS PARA BUCEO (AGREGAR ESTO A TU REPOSITORIO EXISTENTE) ---

  @override
  Future<void> guardarVerificacionesBuceo(BuceoVerificacionModel data) async {
    final db = await DatabaseHelper.instance.database; // O como accedas a tu DB
    await db.insert(
      'verificaciones_buceo',
      data.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<BuceoVerificacionModel?> getVerificacionesBuceo(
    String activityId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'verificaciones_buceo',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    if (res.isNotEmpty) {
      return BuceoVerificacionModel.fromMap(res.first);
    }
    return null;
  }

  @override
  Future<void> guardarParticipantes(
    String activityId,
    List<ParticipanteModel> participantes,
  ) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      // 1. Limpiar lista anterior
      await txn.delete(
        'actividad_participantes',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );

      // 2. Insertar nueva lista
      for (var p in participantes) {
        // Asegurar que el personal exista (si es temporal/nuevo)
        await txn.insert('personal_externo', {
          'id': p.personalId,
          'nombre_completo': p.nombreCompleto,
          'rut': p.rut,
          'cargo': p.cargo, // Guardamos el cargo por defecto
          'activo': 1,
          'matricula': p.matricula,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Crear la relación
        await txn.insert('actividad_participantes', {
          'actividad_id': activityId,
          'personal_id': p.personalId,
          'rol_en_faena': p.cargo,
          'condiciones_optimas': p.condicionesOptimas ? 1 : 0,
        });
      }
    });
  }

  @override
  Future<List<ParticipanteModel>> getParticipantes(String activityId) async {
    final db = await DatabaseHelper.instance.database;

    // Hacemos un JOIN manual o consulta anidada
    final res = await db.rawQuery(
      '''
      SELECT 
        ap.personal_id, 
        p.nombre_completo, 
        p.rut,
        p.matricula,
        ap.rol_en_faena, 
        ap.condiciones_optimas
      FROM actividad_participantes ap
      INNER JOIN personal_externo p ON ap.personal_id = p.id
      WHERE ap.actividad_id = ?
    ''',
      [activityId],
    );

    return res.map((row) => ParticipanteModel.fromMap(row)).toList();
  }

  Future<void> saveInspeccionCompleta({
    required Map<String, dynamic> actividad,
    required List<Map<String, dynamic>> respuestas,
    List<Map<String, dynamic>>? participantes, // Opcional
    Map<String, dynamic>? verificacionesBuceo, // Opcional
  }) async {
    // 1. Instancia DB
    final db = await DatabaseHelper.instance.database;

    // 2. TRANSACCIÓN ATÓMICA
    await db.transaction((txn) async {
      print('💾 TXN: Iniciando guardado atómico...');

      // --- A. GUARDAR PADRE (ACTIVIDAD) ---
      // Aseguramos que 'subido' sea 0 porque acabamos de editarla
      final actividadMap = Map<String, dynamic>.from(actividad);
      actividadMap['subido'] = 0;

      int count = await txn.update(
        'actividades_pendientes',
        actividadMap,
        where: 'id = ?',
        whereArgs: [actividadMap['id']],
      );

      if (count == 0) {
        await txn.insert('actividades_pendientes', actividadMap);
      }

      // --- B. GUARDAR HIJOS (RESPUESTAS) ---
      final batch = txn.batch();

      for (var resp in respuestas) {
        // Borrado lógico compuesto (evita duplicados de items)
        batch.delete(
          'inspeccion_respuestas_pendientes',
          where: 'actividad_id = ? AND item_id = ?',
          whereArgs: [resp['actividad_id'], resp['item_id']],
        );

        // COPIA Y RESETEO DE FLAG (CORREGIDO)
        final respuestaConFlag = Map<String, dynamic>.from(resp);
        respuestaConFlag['subido'] =
            0; // Importante para que el Sync la detecte

        // ❌ ANTES HACÍAS: batch.insert(..., resp); <-- ERROR
        // ✅ AHORA HACEMOS:
        batch.insert('inspeccion_respuestas_pendientes', respuestaConFlag);
      }

      // --- C. GUARDAR VERIFICACIONES DE BUCEO ---
      if (verificacionesBuceo != null) {
        // Aseguramos que tenga el ID correcto
        if (!verificacionesBuceo.containsKey('actividad_id')) {
          verificacionesBuceo['actividad_id'] = actividad['id'];
        }

        // Upsert manual
        int vCount = await txn.update(
          'verificaciones_buceo',
          verificacionesBuceo,
          where: 'actividad_id = ?',
          whereArgs: [verificacionesBuceo['actividad_id']],
        );

        if (vCount == 0) {
          batch.insert('verificaciones_buceo', verificacionesBuceo);
        }
      }

      // --- D. GUARDAR PARTICIPANTES ---
      if (participantes != null && participantes.isNotEmpty) {
        // Limpiamos la cuadrilla anterior para evitar fantasmas
        batch.delete(
          'actividad_participantes',
          where: 'actividad_id = ?',
          whereArgs: [actividad['id']],
        );

        for (var p in participantes) {
          // 2. MAGIA: Guardamos/Actualizamos a la PERSONA en la tabla maestra primero
          // Preparamos el mapa solo con los datos de la persona
          final datosPersona = {
            'id': p['personal_id'],
            'nombre_completo': p['nombre_completo'],
            'rut': p['rut'],
            'cargo': p['cargo'], // o p['rol_en_faena']
            'activo': 1,
            // Opcional: si manejas contratista_id y lo tienes, agrégalo.
            // Si es null, SQLite lo dejará null (está bien para creación local rápida).
          };
          batch.insert(
            'personal_externo',
            datosPersona,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          final datosRelacion = {
            'actividad_id': p['actividad_id'],
            'personal_id': p['personal_id'],
            'rol_en_faena': p['rol_en_faena'],
            'condiciones_optimas': p['condiciones_optimas'],
          };
          batch.insert('actividad_participantes', datosRelacion);
        }
      }

      // --- E. EJECUTAR LOTE ---
      await batch.commit(noResult: false);
      print('✅ TXN: Guardado completo y exitoso.');
    });
  }
}
