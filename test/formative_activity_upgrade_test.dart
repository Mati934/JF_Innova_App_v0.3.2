import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v60 to v62 preserves pending inspections and evidence', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp(
      'formative_upgrade_',
    );
    await databaseFactory.setDatabasesPath(directory.path);
    final path = p.join(directory.path, 'jfinnova_v18_local.db');
    final signature = [1, 2, 3, 4];
    final legacy = await openDatabase(
      path,
      version: 60,
      onCreate: (db, _) async {
        // Only the legacy tables used by this migration and onOpen repair.
        await db.execute('''
          CREATE TABLE actividades_pendientes (
            id TEXT PRIMARY KEY, usuario_id TEXT, tipo_actividad TEXT,
            estado_final TEXT, numero_reporte TEXT, pdf_path_local TEXT,
            estado_faena TEXT, subido INTEGER, eliminado INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE inspeccion_respuestas_pendientes (
            id INTEGER PRIMARY KEY, actividad_id TEXT, estado TEXT,
            observacion TEXT, subido INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE visitas_tecnicas_pendientes (
            id TEXT PRIMARY KEY, signature_image BLOB
          )
        ''');
        await db.execute(
          'CREATE TABLE contratistas (id TEXT PRIMARY KEY, rut TEXT)',
        );
        await db.execute('''
          CREATE TABLE extintores_pendientes (
            id TEXT PRIMARY KEY, tipo_extintor TEXT, peso_extintor TEXT,
            fecha_ultima_mantencion TEXT, fecha_proxima_mantencion TEXT
          )
        ''');
      },
    );
    final inspection = <String, Object?>{
      'id': 'legacy-inspection',
      'usuario_id': 'legacy-user',
      'tipo_actividad': 'INSPECCION_BUCEO',
      'estado_final': 'En Progreso',
      'numero_reporte': '123',
      'pdf_path_local': r'C:\offline\inspection.pdf',
      'estado_faena': null,
      'subido': 0,
      'eliminado': 0,
    };
    final response = <String, Object?>{
      'id': 1,
      'actividad_id': 'legacy-inspection',
      'estado': 'NC',
      'observacion': 'Pending evidence',
      'subido': 0,
    };
    await legacy.insert('actividades_pendientes', inspection);
    await legacy.insert('inspeccion_respuestas_pendientes', response);
    await legacy.rawInsert(
      'INSERT INTO visitas_tecnicas_pendientes (id, signature_image) VALUES (?, ?)',
      ['legacy-visit', Uint8List.fromList(signature)],
    );
    await legacy.close();

    Database? upgraded;
    try {
      upgraded = await DatabaseHelper.instance.database;
      expect(await upgraded.getVersion(), 62);
      expect((await upgraded.query('actividades_pendientes')).single, {
        ...inspection,
        'empresa_id': null,
      });
      expect(
        (await upgraded.query('inspeccion_respuestas_pendientes')).single,
        response,
      );
      expect(
        (await upgraded.query(
          'visitas_tecnicas_pendientes',
        )).single['signature_image'],
        signature,
      );
      expect(
        await upgraded.query('actividades_formativas_pendientes'),
        isEmpty,
      );
      expect(await upgraded.query('formativa_fotos_eliminadas'), isEmpty);
      final columns = await upgraded.rawQuery(
        'PRAGMA table_info(actividades_formativas_pendientes)',
      );
      expect(
        columns.map((column) => column['name']),
        containsAll([
          'actividad_id',
          'empresa_id',
          'firma_relator_image',
          'hh_sin_relator',
          'hh_con_relator',
        ]),
      );
      expect(
        await upgraded.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_actividad_formativa_sync'",
        ),
        hasLength(1),
      );
    } finally {
      await upgraded?.close();
      await directory.delete(recursive: true);
    }
  });
}
