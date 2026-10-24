import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'v61 upgrade is idempotent and preserves legacy photos and pending removals',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp('formativa_v61_');
      await databaseFactory.setDatabasesPath(directory.path);
      final legacy = await openDatabase(
        p.join(directory.path, 'jfinnova_v18_local.db'),
        version: 61,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE actividades_pendientes (id TEXT PRIMARY KEY)',
          );
          await db.execute(
            'CREATE TABLE visitas_tecnicas_pendientes (id TEXT PRIMARY KEY)',
          );
          await db.execute('CREATE TABLE contratistas (id TEXT PRIMARY KEY)');
          await db.execute(
            'CREATE TABLE extintores_pendientes (id TEXT PRIMARY KEY)',
          );
          await db.execute('''
          CREATE TABLE fotos_pendientes (
            id INTEGER PRIMARY KEY, actividad_id TEXT, local_path TEXT,
            descripcion TEXT, item_id TEXT, subido INTEGER DEFAULT 0
          )
        ''');
          // An interrupted upgrade may have already created the queue.
          await db.execute('''
          CREATE TABLE formativa_fotos_eliminadas (
            actividad_id TEXT NOT NULL, local_path TEXT NOT NULL,
            PRIMARY KEY (actividad_id, local_path)
          )
        ''');
        },
      );
      final photo = {
        'id': 1,
        'actividad_id': 'legacy',
        'local_path': 'local.jpg',
        'descripcion': null,
        'item_id': null,
        'subido': 1,
      };
      final deletion = {'actividad_id': 'legacy', 'local_path': 'removed.jpg'};
      await legacy.insert('fotos_pendientes', photo);
      await legacy.insert('formativa_fotos_eliminadas', deletion);
      await legacy.close();
      Database? upgraded;
      try {
        upgraded = await DatabaseHelper.instance.database;
        expect(await upgraded.getVersion(), 62);
        expect((await upgraded.query('fotos_pendientes')).single, photo);
        expect(
          (await upgraded.query('formativa_fotos_eliminadas')).single,
          deletion,
        );
        expect(
          await upgraded.query('actividades_formativas_pendientes'),
          isEmpty,
        );
      } finally {
        await upgraded?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
