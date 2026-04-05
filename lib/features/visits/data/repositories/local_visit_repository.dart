import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/user_session.dart';
import '../../domain/models/visit_model.dart';
import '../../domain/models/visita_respuesta.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class LocalVisitRepository {
  final dbHelper = DatabaseHelper.instance;

  // Obtener Regiones (Áreas) filtradas por empresa del usuario
  Future<List<Map<String, dynamic>>> getRegiones() async {
    final empresaId = UserSession().empresaId;
    if (empresaId != null) {
      return await dbHelper.getAreasByEmpresa(empresaId);
    }
    return await dbHelper.getAreas();
  }

  // Obtener Lugares de Visita (Centros) filtrados por Región
  Future<List<Map<String, dynamic>>> getCentrosPorRegion(String areaId) async {
    return await dbHelper.getCentros(areaId);
  }

  Future<List<String>> getRegionesHistoricas() async {
    final db = await dbHelper.database; // ✅ Usamos la instancia de la clase

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT region 
      FROM visitas_tecnicas_pendientes
      WHERE region IS NOT NULL AND trim(region) != ''
      ORDER BY region ASC
    ''');

    return maps.map((e) => e['region'] as String).toList();
  }

  Future<List<String>> getCentrosHistoricos() async {
    final db = await dbHelper.database; // ✅ Usamos la instancia de la clase

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT lugar_visita 
      FROM visitas_tecnicas_pendientes
      WHERE lugar_visita IS NOT NULL AND trim(lugar_visita) != ''
      ORDER BY lugar_visita ASC
    ''');

    return maps.map((e) => e['lugar_visita'] as String).toList();
  }

  Future<List<String>> getEmpresasHistoricas() async {
    final db = await dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT empresa
      FROM visitas_tecnicas_pendientes
      WHERE empresa IS NOT NULL AND trim(empresa) != ''
      ORDER BY empresa ASC
    ''');

    return maps.map((e) => e['empresa'] as String).toList();
  }

  Future<void> saveVisitaCompleta({
    required Map<String, dynamic> visitaMap,
    required List<String> fotosPaths,
    required bool esBorrador,
    // 👈 NUEVOS PARÁMETROS OPCIONALES PARA EL DETALLE DINÁMICO
    String? tipoChecklist,
    Map<String, dynamic>? respuestasChecklist,
  }) async {
    final db = await dbHelper.database;
    final estadoFinal = esBorrador ? 'En Progreso' : 'Finalizada';

    visitaMap['estado_final'] = estadoFinal;
    visitaMap['subido'] = 0;

    await db.transaction((txn) async {
      debugPrint('💾 TXN: Guardando Visita Técnica (Borrador: $esBorrador)...');

      // 1. Guardar Cabecera (Master)
      await txn.insert(
        'visitas_tecnicas_pendientes',
        visitaMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Guardar Detalle Checklist (Detail) - NUEVO BLINDAJE
      if (tipoChecklist != null && respuestasChecklist != null) {
        // Limpiamos el checklist anterior de este tipo para evitar basura acumulada
        await txn.delete(
          'visitas_checklists_pendientes',
          where: 'visita_id = ? AND tipo_checklist = ?',
          whereArgs: [visitaMap['id'], tipoChecklist],
        );

        // Insertamos la versión fresca (Codificando el Map a String para SQLite)
        await txn.insert('visitas_checklists_pendientes', {
          'id': const Uuid().v4(),
          'visita_id': visitaMap['id'],
          'tipo_checklist': tipoChecklist,
          'respuestas': jsonEncode(respuestasChecklist),
          'subido': 0,
        });
      }

      // 3. Guardar Fotos (Se mantiene igual)
      if (fotosPaths.isNotEmpty) {
        await txn.delete(
          'fotos_pendientes',
          where: 'actividad_id = ?',
          whereArgs: [visitaMap['id']],
        );
        for (var path in fotosPaths) {
          await txn.insert('fotos_pendientes', {
            'actividad_id': visitaMap['id'],
            'item_id': 'visita_general',
            'local_path': path,
            'descripcion': 'Anexo fotográfico de Visita Técnica',
            'subido': 0,
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getBorradores() async {
    final db = await dbHelper.database;
    final result = await db.query(
      'visitas_tecnicas_pendientes',
      where:
          'estado_final = ? AND eliminado = 0 AND (tipo_actividad IS NULL OR tipo_actividad != ?)',
      whereArgs: ['En Progreso', 'VISITA_R004'],
      orderBy: 'fecha_realizacion DESC',
    );

    // INYECCIÓN VITAL: El DraftListWidget necesita 'tipo_actividad' y 'nombre_centro' para funcionar
    return result.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['tipo_actividad'] = 'Visita Técnica';
      map['nombre_centro'] =
          map['lugar_visita']; // Homologamos nombre para la UI
      return map;
    }).toList();
  }

  // Soft delete para ser llamado desde el Home
  Future<void> eliminarBorrador(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'visitas_tecnicas_pendientes',
      {
        'estado_final': 'Eliminada',
        'eliminado': 1,
        'subido': 0, // Fuerza al SyncService a leer esto y subir el cambio
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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

  // Extrae el perfil del usuario activo desde SQLite
  Future<Map<String, dynamic>?> getUsuarioLocal(String userId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Recuperar el checklist dinámico para la UI
  Future<Map<String, dynamic>?> getChecklistPorVisita(String visitaId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'visitas_checklists_pendientes',
      where: 'visita_id = ?',
      whereArgs: [visitaId],
      limit: 1, // Asumimos 1 checklist por visita por ahora
    );

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'tipo_checklist': row['tipo_checklist'],
        // Decodificamos el String de SQLite de vuelta a Map
        'respuestas': jsonDecode(row['respuestas'] as String),
      };
    }
    return null;
  }

  /// Tipos de checklist disponibles para visitas (excluye VISITA_R004 que tiene módulo propio)
  Future<List<Map<String, dynamic>>> getTiposChecklistVisita() async {
    final db = await dbHelper.database;
    return await db.rawQuery('''
      SELECT DISTINCT tipo_actividad
      FROM formulario_items
      WHERE tipo_actividad LIKE 'VISITA_%' AND tipo_actividad != 'VISITA_R004' AND activo = 1
      ORDER BY tipo_actividad ASC
    ''');
  }

  /// Guarda respuestas individuales en visita_respuestas_pendientes
  Future<void> saveVisitaRespuestas(
    String visitaId,
    List<VisitaRespuesta> respuestas,
  ) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'visita_respuestas_pendientes',
        where: 'visita_id = ?',
        whereArgs: [visitaId],
      );
      for (var r in respuestas) {
        await txn.insert('visita_respuestas_pendientes', r.toMap());
      }
    });
  }

  /// Carga respuestas individuales desde visita_respuestas_pendientes
  Future<List<VisitaRespuesta>> getVisitaRespuestas(String visitaId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'visita_respuestas_pendientes',
      where: 'visita_id = ?',
      whereArgs: [visitaId],
    );
    return result.map((m) => VisitaRespuesta.fromMap(m)).toList();
  }
}
