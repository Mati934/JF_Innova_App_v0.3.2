// v65 → v66: `registros_inmersion_pendientes.actividad_id` deja de ser
// obligatorio (registro sin inspección) sin perder los borradores existentes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v65 a v66 vuelve opcional actividad_id y conserva filas', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('ri_upgrade_');
    await databaseFactory.setDatabasesPath(directory.path);
    final path = p.join(directory.path, 'jfinnova_v18_local.db');

    final legacy = await openDatabase(
      path,
      version: 65,
      onCreate: (db, _) async {
        // Solo las tablas que usan esta migración y el repair de onOpen.
        await db.execute('''
          CREATE TABLE actividades_pendientes (
            id TEXT PRIMARY KEY, usuario_id TEXT, tipo_actividad TEXT,
            estado_final TEXT, numero_reporte TEXT, pdf_path_local TEXT,
            estado_faena TEXT, subido INTEGER, eliminado INTEGER
          )
        ''');
        await db.execute(
          'CREATE TABLE visitas_tecnicas_pendientes '
          '(id TEXT PRIMARY KEY, signature_image BLOB)',
        );
        await db.execute(
          'CREATE TABLE contratistas (id TEXT PRIMARY KEY, rut TEXT)',
        );
        await db.execute('''
          CREATE TABLE extintores_pendientes (
            id TEXT PRIMARY KEY, tipo_extintor TEXT, peso_extintor TEXT,
            fecha_ultima_mantencion TEXT, fecha_proxima_mantencion TEXT
          )
        ''');
        // Tabla tal como la creó v65 (actividad_id NOT NULL).
        await db.execute('''
          CREATE TABLE registros_inmersion_pendientes (
            id TEXT PRIMARY KEY,
            actividad_id TEXT NOT NULL,
            empresa_id TEXT, usuario_id TEXT, centro_id TEXT,
            contratista_id TEXT, centro_nombre TEXT, contratista_nombre TEXT,
            numero_inspeccion TEXT, fecha_realizacion TEXT,
            profundidad_autorizada_m REAL, observacion_general TEXT,
            origen TEXT NOT NULL DEFAULT 'TARJETA_INICIO',
            estado_final TEXT NOT NULL DEFAULT 'Borrador',
            numero INTEGER, correlativo TEXT, pdf_url TEXT, pdf_version TEXT,
            pdf_path_local TEXT,
            subido INTEGER NOT NULL DEFAULT 0,
            eliminado INTEGER NOT NULL DEFAULT 0,
            created_at TEXT, updated_at TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_reg_inm_actividad '
          'ON registros_inmersion_pendientes(actividad_id)',
        );
      },
    );
    await legacy.insert('registros_inmersion_pendientes', {
      'id': 'reg-viejo',
      'actividad_id': 'act-1',
      'centro_nombre': 'Centro A',
      'subido': 0,
    });
    await legacy.close();

    Database? upgraded;
    try {
      upgraded = await DatabaseHelper.instance.database;
      expect(await upgraded.getVersion(), 66);
      final cols = await upgraded.rawQuery(
        'PRAGMA table_info(registros_inmersion_pendientes)',
      );
      final act = cols.firstWhere((c) => c['name'] == 'actividad_id');
      expect(act['notnull'], 0);

      final filas = await upgraded.query('registros_inmersion_pendientes');
      expect(filas.single['id'], 'reg-viejo');
      expect(filas.single['actividad_id'], 'act-1');
      expect(filas.single['centro_nombre'], 'Centro A');

      await upgraded.insert('registros_inmersion_pendientes', {
        'id': 'reg-suelto',
        'actividad_id': null,
      });
      final indices = await upgraded.rawQuery(
        'PRAGMA index_list(registros_inmersion_pendientes)',
      );
      expect(indices.map((i) => i['name']), contains('idx_reg_inm_actividad'));
      final restos = await upgraded.query(
        'sqlite_master',
        where: 'name = ?',
        whereArgs: ['registros_inmersion_pendientes_v65'],
      );
      expect(restos, isEmpty);
    } finally {
      await upgraded?.close();
      await directory.delete(recursive: true);
    }
  });
}
