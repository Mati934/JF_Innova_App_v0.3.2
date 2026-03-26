import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jf_innova_app/features/inspection/domain/models/buceo_verificacion_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/participante_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../../../core/database/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
    final db = await DatabaseHelper.instance.database;

    // MALA PRÁCTICA (Lo que estabas haciendo):
    // await db.delete('actividades_pendientes', where: 'id = ?', whereArgs: [activityId]);

    // BUENA PRÁCTICA (Soft Delete local):
    // Lo marcamos como eliminado y le decimos 'subido = 0' para que el SyncService lo procese.
    await db.update(
      'actividades_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  // --- MÉTODO CORREGIDO: Soporte PDF y Limpieza de Estado ---
  Future<void> saveActividad({
    required String id,
    required String tipoActividad,
    required String? centroId,
    required DateTime fecha,
    required bool esBorrador, // 👈 EL JEFE DEL ESTADO
    String? usuarioId,
    String? contratistaId,
    String? embarcacionId,
    String? numeroReporte,
    int? numeroSeguimiento,
    String? pdfUrl, // 👈 NUEVO: Recibimos la URL del PDF
  }) async {
    final db = await dbHelper.database;

    // LÓGICA DE ESTADO (Source of Truth)
    final estadoFinal = esBorrador ? 'En Progreso' : 'En Seguimiento';

    try {
      final datos = {
        'id': id,
        'tipo_actividad': tipoActividad,
        'centro_id': centroId,
        'usuario_id': usuarioId,
        'contratista_id': contratistaId,
        'embarcacion_id': embarcacionId,
        'fecha_realizacion': fecha.toIso8601String(),
        'subido': 0, // Siempre reset a 0 al guardar cambios
        'estado_final': estadoFinal,
        'puerto_abierto': 1,
        'numero_reporte': numeroReporte,
        'numero_seguimiento': numeroSeguimiento ?? 0,
        // Si pdfUrl viene nulo (ej: guardando borrador), no lo sobrescribimos con null
        // a menos que quieras borrarlo. Aquí asumimos que si viene, se guarda.
      };

      if (pdfUrl != null) {
        datos['pdf_url'] = pdfUrl;
      }

      await db.insert(
        'actividades_pendientes',
        datos,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint("💾 ACTIVIDAD GUARDADA: $id | Estado: $estadoFinal");
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
          'subido': 0,
        });
      }
      await batch.commit(noResult: true);
      debugPrint("💾 Respuestas guardadas (${respuestas.length} items).");
    } catch (e) {
      debugPrint("❌ Error guardando respuestas batch: $e");
    }
  }

  @override
  Future<String> saveFoto({
    required String activityId,
    required String? itemId,
    required XFile file,
    required String descripcion,
  }) async {
    final db = await dbHelper.database;
    final directory = await getApplicationDocumentsDirectory();
    final folderPath = '${directory.path}/inspecciones_img';
    final folder = Directory(folderPath);

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    String permanentPath;
    if (file.path.contains(folderPath)) {
      permanentPath = file.path;
    } else {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${itemId ?? "general"}.jpg';
      permanentPath = '$folderPath/$fileName';
      final sourceFile = File(file.path);
      if (await sourceFile.exists()) {
        await sourceFile.copy(permanentPath);
      } else {
        throw Exception("El archivo original desapareció.");
      }
    }

    if (itemId != null) {
      await db.delete(
        'fotos_pendientes',
        where: 'actividad_id = ? AND item_id = ?',
        whereArgs: [activityId, itemId],
      );
    }

    await db.insert('fotos_pendientes', {
      'actividad_id': activityId,
      'item_id': itemId,
      'local_path': permanentPath,
      'descripcion': descripcion,
      'subido': 0,
    });

    return permanentPath;
  }

  @override
  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await dbHelper.database;
    try {
      final result = await db.rawQuery('''
        SELECT a.*, c.nombre as nombre_centro 
        FROM actividades_pendientes a
        LEFT JOIN centros c ON a.centro_id = c.id
        WHERE a.estado_final = 'En Progreso' AND a.eliminado = 0
        ORDER BY a.fecha_realizacion DESC
      ''');
      // 👇 INYECTA ESTO 👇
      debugPrint("🚨 FORENSE SQLite - Ruta DB: ${db.path}");
      debugPrint(
        "🚨 FORENSE SQLite - Borradores encontrados: ${result.length}",
      );
      for (var r in result) {
        debugPrint(
          "🚨 BORRADOR ENCONTRADO: ID=${r['id']}, Subido=${r['subido']}, Eliminado=${r['eliminado']}, Actividad=${r['tipo_actividad']}",
        );
      }
      // 👆 HASTA AQUÍ 👆
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

  // --- MÉTODOS ESPECÍFICOS DE BUCEO ---

  @override
  Future<void> guardarVerificacionesBuceo(BuceoVerificacionModel data) async {
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
    final res = await db.query(
      'verificaciones_buceo',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );
    return res.isNotEmpty ? BuceoVerificacionModel.fromMap(res.first) : null;
  }

  @override
  Future<void> guardarParticipantes(
    String activityId,
    List<ParticipanteModel> participantes,
  ) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'actividad_participantes',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );

      for (var p in participantes) {
        // CAMBIO: Usamos replace para actualizar matrícula si el buzo ya existe
        await txn.insert('personal_externo', {
          'id': p.personalId,
          'nombre_completo': p.nombreCompleto,
          'rut': p.rut,
          'cargo': p.cargo,
          'activo': 1,
          'matricula': p.matricula,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

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
    final db = await dbHelper.database;
    final res = await db.rawQuery(
      '''
      SELECT ap.personal_id, p.nombre_completo, p.rut, p.matricula, p.contratista_id, ap.rol_en_faena, ap.condiciones_optimas
      FROM actividad_participantes ap
      INNER JOIN personal_externo p ON ap.personal_id = p.id
      WHERE ap.actividad_id = ?
    ''',
      [activityId],
    );
    return res.map((row) => ParticipanteModel.fromMap(row)).toList();
  }

  // --- TRANSACCIÓN MAESTRA (Con soporte para PDF_URL) ---
  Future<void> saveInspeccionCompleta({
    required Map<String, dynamic> actividad,
    required List<Map<String, dynamic>> respuestas,
    required bool esBorrador, // 👈 PARAMETRO CLAVE
    List<Map<String, dynamic>>? participantes,
    Map<String, dynamic>? verificacionesBuceo,
    Map<String, dynamic>? verificacionesEmbarcacion,
    List<Map<String, dynamic>>? fotos,
  }) async {
    final db = await dbHelper.database;

    // DETERMINAMOS ESTADO
    final estadoFinal = esBorrador ? 'En Progreso' : 'En Seguimiento';

    await db.transaction((txn) async {
      debugPrint('💾 TXN: Iniciando guardado ($estadoFinal)...');

      // 1. GUARDAR ACTIVIDAD
      final actividadMap = Map<String, dynamic>.from(actividad);
      actividadMap['subido'] = 0;
      actividadMap['estado_final'] = estadoFinal;
      // Nota: Como 'actividad' viene del Controller, ya debería traer 'pdf_url' si existe.
      // El insert lo guardará automáticamente si la columna existe en SQLite.

      await txn.insert(
        'actividades_pendientes',
        actividadMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. GUARDAR RESPUESTAS
      final batch = txn.batch();
      for (var resp in respuestas) {
        batch.delete(
          'inspeccion_respuestas_pendientes',
          where: 'actividad_id = ? AND item_id = ?',
          whereArgs: [resp['actividad_id'], resp['item_id']],
        );
        final respuestaConFlag = Map<String, dynamic>.from(resp);
        respuestaConFlag['subido'] = 0;
        batch.insert('inspeccion_respuestas_pendientes', respuestaConFlag);
      }

      // 3. VERIFICACIONES (Buceo o Embarcación)
      if (verificacionesBuceo != null) {
        if (!verificacionesBuceo.containsKey('actividad_id')) {
          verificacionesBuceo['actividad_id'] = actividad['id'];
        }
        batch.insert(
          'verificaciones_buceo',
          verificacionesBuceo,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (verificacionesEmbarcacion != null) {
        if (!verificacionesEmbarcacion.containsKey('actividad_id')) {
          verificacionesEmbarcacion['actividad_id'] = actividad['id'];
        }
        batch.insert(
          'verificaciones_embarcacion',
          verificacionesEmbarcacion,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 4. PARTICIPANTES
      if (participantes != null) {
        batch.delete(
          'actividad_participantes',
          where: 'actividad_id = ?',
          whereArgs: [actividad['id']],
        );
        for (var p in participantes) {
          // CAMBIO: Usamos replace para actualizar matrícula si el buzo ya existe
          batch.insert('personal_externo', {
            'id': p['personal_id'],
            'nombre_completo': p['nombre_completo'],
            'rut': p['rut'],
            'cargo': p['cargo'],
            'activo': 1,
            'matricula': p['matricula'],
            'contratista_id': p['contratista_id'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          batch.insert('actividad_participantes', {
            'actividad_id': actividad['id'],
            'personal_id': p['personal_id'],
            'rol_en_faena': p['rol_en_faena'],
            'condiciones_optimas':
                (p['condiciones_optimas'] == true ||
                    p['condiciones_optimas'] == 1)
                ? 1
                : 0,
          });
        }
      }

      // 5. FOTOS
      if (fotos != null) {
        // AÑADE ESTA LÍNEA PARA MATAR DUPLICADOS
        batch.delete(
          'fotos_pendientes',
          where: 'actividad_id = ?',
          whereArgs: [actividad['id']],
        );

        for (var f in fotos) {
          final fotoMap = Map<String, dynamic>.from(f);
          fotoMap['subido'] = 0;
          fotoMap['actividad_id'] = actividad['id'];
          // ... quítale la clave 'id' a fotoMap si la trae, para que SQLite genere una nueva
          fotoMap.remove('id');

          batch.insert(
            'fotos_pendientes',
            fotoMap,
          ); // Ya no necesitas conflictAlgorithm
        }
      }

      await batch.commit(noResult: true);
      debugPrint('✅ TXN: Guardado exitoso. Estado final: $estadoFinal');
    });
  }

  Future<String?> sugerirSiguienteNumeroReporte(String tipoActividad) async {
    final db = await dbHelper.database;
    try {
      final result = await db.rawQuery(
        '''
        SELECT numero_reporte FROM actividades_pendientes 
        WHERE tipo_actividad = ? AND numero_reporte IS NOT NULL AND numero_reporte != ""
        ''',
        [tipoActividad], // Ya no filtramos por centro_id
      );
      int maxNum = 0;
      for (var row in result) {
        final val = row['numero_reporte'] as String?;
        if (val != null && RegExp(r'^[0-9]+$').hasMatch(val)) {
          final num = int.tryParse(val);
          if (num != null && num > maxNum) maxNum = num;
        }
      }
      return maxNum > 0 ? (maxNum + 1).toString() : null;
    } catch (e) {
      debugPrint("❌ Error calculando siguiente informe: $e");
      return null;
    }
  }

  // Añadir dentro de LocalInspectionRepository
  Future<ParticipanteModel?> getPersonalByRut(String rut) async {
    final db = await dbHelper.database;
    final res = await db.query(
      'personal_externo',
      where: 'rut = ?',
      whereArgs: [rut],
      limit: 1, // Optimización: Cortamos la búsqueda al primer match
    );

    if (res.isNotEmpty) {
      final map = res.first;
      return ParticipanteModel(
        personalId: map['id'] as String,
        nombreCompleto: map['nombre_completo'] as String,
        rut: map['rut'] as String,
        cargo: map['cargo'] as String? ?? 'Buzo',
        matricula: map['matricula'] as String? ?? '',
        contratistaId:
            map['contratista_id'] as String?, // <--- AGREGAR CONTRATISTA_ID
        condicionesOptimas: true, // Default por negocio
      );
    }
    return null;
  }

  // --- MÉTODOS ESPECÍFICOS DE EMBARCACIONES ---
  Future<void> guardarVerificacionesEmbarcacion(
    String activityId,
    Map<String, dynamic> data,
  ) async {
    final db = await dbHelper.database;
    data['actividad_id'] = activityId; // Seguro de integridad
    await db.insert(
      'verificaciones_embarcacion',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getVerificacionesEmbarcacion(
    String activityId,
  ) async {
    final db = await dbHelper.database;
    final res = await db.query(
      'verificaciones_embarcacion',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );
    return res.isNotEmpty ? res.first : null;
  }
}
