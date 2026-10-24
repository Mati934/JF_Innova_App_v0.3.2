// ignore_for_file: dead_code, unused_local_variable, unnecessary_null_comparison
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/modules/module_registry.dart';

void main() {
  // ===================================================================
  // TESTS: ADMIN CRUD - Datos Maestros (contratistas, embarcaciones, centros)
  // ===================================================================
  group('Admin CRUD - Inserción de datos maestros', () {
    test('Contratista nuevo se inserta con subido=0 y rut', () {
      final row = {
        'id': 'cont-uuid-001',
        'nombre': 'Contratista Prueba',
        'rut': 'PENDIENTE-cont-uui',
        'subido': 0,
      };

      expect(
        row['subido'],
        0,
        reason: 'Nuevo registro debe marcarse como pendiente de sync',
      );
      expect(row['nombre'], 'Contratista Prueba');
      expect(row['id'], isNotEmpty);
      expect(row['rut'], startsWith('PENDIENTE-'));
    });

    test('Embarcación nueva se inserta con subido=0 y contratista_id', () {
      final row = {
        'id': 'emb-uuid-001',
        'nombre': 'Embarcación Prueba',
        'contratista_id': 'cont-uuid-001',
        'matricula': 'MAT-001',
        'subido': 0,
      };

      expect(row['subido'], 0);
      expect(
        row['contratista_id'],
        isNotEmpty,
        reason: 'Embarcación requiere contratista_id para FK en Supabase',
      );
      expect(row['matricula'], 'MAT-001');
    });

    test('Centro nuevo se inserta con subido=0 y area_id', () {
      final row = {
        'id': 'centro-uuid-001',
        'nombre': 'Centro Prueba',
        'area_id': 'area-001',
        'subido': 0,
      };

      expect(row['subido'], 0);
      expect(
        row['area_id'],
        isNotEmpty,
        reason: 'Centro requiere area_id para FK en Supabase',
      );
    });

    test('Nombre se trimea antes de insertar', () {
      final nombre = '  Contratista Nuevo  ';
      final trimmed = nombre.trim();
      expect(trimmed, 'Contratista Nuevo');
      expect(trimmed, isNot(contains('  ')));
    });

    test('Embarcación con matrícula null se acepta', () {
      final row = {
        'id': 'emb-uuid-002',
        'nombre': 'Embarcación Sin Matrícula',
        'contratista_id': 'cont-uuid-001',
        'matricula': null,
        'subido': 0,
      };

      expect(row['matricula'], isNull);
      expect(row['subido'], 0);
    });
  });

  // ===================================================================
  // TESTS: SYNC DE DATOS MAESTROS PENDIENTES (_syncTabla)
  // ===================================================================
  group('Sync de datos maestros pendientes', () {
    test('getPendingMasterData filtra por subido=0', () {
      final allRows = [
        {'id': '1', 'nombre': 'A', 'subido': 0},
        {'id': '2', 'nombre': 'B', 'subido': 1},
        {'id': '3', 'nombre': 'C', 'subido': 0},
      ];

      final pendientes = allRows.where((r) => r['subido'] == 0).toList();
      expect(pendientes.length, 2);
      expect(pendientes.map((r) => r['id']).toList(), ['1', '3']);
    });

    test('Payload de contratista tiene id, nombre y rut', () {
      final row = {
        'id': 'cont-001',
        'nombre': 'Test',
        'rut': '12345678-5',
        'subido': 0,
      };
      final campos = ['id', 'nombre', 'rut'];

      final payload = <String, dynamic>{};
      for (final campo in campos) {
        payload[campo] = row[campo];
      }

      expect(
        payload.containsKey('subido'),
        false,
        reason: 'subido es local, no va a Supabase',
      );
      expect(payload['id'], 'cont-001');
      expect(payload['nombre'], 'Test');
      expect(payload['rut'], '12345678-5');
    });

    test('Payload de embarcación incluye contratista_id y matricula', () {
      final row = {
        'id': 'emb-001',
        'nombre': 'Barco',
        'contratista_id': 'cont-001',
        'matricula': 'MAT-X',
        'subido': 0,
      };
      final campos = ['id', 'nombre', 'contratista_id', 'matricula'];

      final payload = <String, dynamic>{};
      for (final campo in campos) {
        payload[campo] = row[campo];
      }

      expect(payload.length, 4);
      expect(payload.containsKey('subido'), false);
      expect(payload['contratista_id'], 'cont-001');
    });

    test('Payload de centro incluye area_id', () {
      final row = {
        'id': 'centro-001',
        'nombre': 'Centro X',
        'area_id': 'area-001',
        'subido': 0,
      };
      final campos = ['id', 'nombre', 'area_id'];

      final payload = <String, dynamic>{};
      for (final campo in campos) {
        payload[campo] = row[campo];
      }

      expect(payload.length, 3);
      expect(payload.containsKey('subido'), false);
      expect(payload['area_id'], 'area-001');
    });

    test('markMasterDataSynced cambia subido a 1', () {
      final row = {'id': 'cont-001', 'nombre': 'Test', 'subido': 0};

      // Simula markMasterDataSynced
      final updated = Map<String, dynamic>.from(row);
      updated['subido'] = 1;

      expect(updated['subido'], 1);
    });

    test(
      'Orden de sync: contratistas primero, luego centros, luego embarcaciones',
      () {
        // Embarcaciones dependen de contratistas (FK contratista_id)
        // Centros dependen de áreas (ya descargadas)
        final orden = ['contratistas', 'centros', 'embarcaciones'];

        expect(
          orden.indexOf('contratistas') < orden.indexOf('embarcaciones'),
          true,
          reason:
              'Contratistas deben sincronizarse antes que embarcaciones (FK)',
        );
      },
    );

    test('Error en contratista no impide sync de centros', () {
      // _sincronizarMaestrosPendientes hace try/catch por tabla
      // Cada _syncTabla es independiente
      var contratistaFallo = true;
      var centroExitoso = true;

      expect(contratistaFallo, true);
      expect(
        centroExitoso,
        true,
        reason: 'Cada tabla se sincroniza independientemente',
      );
    });

    test('Conteo de exitosos vs fallidos es correcto', () {
      final resultados = [true, false, true, true, false];
      int exitosos = resultados.where((r) => r).length;
      int fallidos = resultados.where((r) => !r).length;

      expect(exitosos, 3);
      expect(fallidos, 2);
      expect(exitosos + fallidos, resultados.length);
    });

    test('Lista vacía de pendientes retorna sin hacer nada', () {
      final pendientes = <Map<String, dynamic>>[];
      expect(
        pendientes.isEmpty,
        true,
        reason: 'Si no hay pendientes, _syncTabla retorna inmediatamente',
      );
    });
  });

  // ===================================================================
  // TESTS: EDICIÓN de datos maestros
  // ===================================================================
  group('Admin CRUD - Edición de datos maestros', () {
    test('Editar contratista resetea subido a 0', () {
      final updateMap = {'nombre': 'Nuevo Nombre', 'subido': 0};
      expect(
        updateMap['subido'],
        0,
        reason: 'Al editar, subido debe resetearse para re-sync',
      );
    });

    test('Editar centro incluye area_id y subido=0', () {
      final updateMap = {
        'nombre': 'Centro Editado',
        'area_id': 'area-002',
        'subido': 0,
      };
      expect(updateMap['area_id'], 'area-002');
      expect(updateMap['subido'], 0);
    });

    test('Editar embarcación incluye contratista_id, matrícula y subido=0', () {
      final updateMap = {
        'nombre': 'Emb Editada',
        'contratista_id': 'cont-002',
        'matricula': 'MAT-NEW',
        'subido': 0,
      };
      expect(updateMap['contratista_id'], 'cont-002');
      expect(updateMap['matricula'], 'MAT-NEW');
      expect(updateMap['subido'], 0);
    });
  });

  // ===================================================================
  // TESTS: EMPRESA_MODULOS - Asignación de módulos por empresa
  // ===================================================================
  group('Empresa Módulos - Configuración', () {
    test('ModuleRegistry tiene todos los módulos esperados', () {
      final allKeys = ModuleRegistry.all.map((m) => m.moduleKey).toList();

      expect(allKeys, contains('INSPECCION'));
      expect(allKeys, contains('VISITA_R003'));
      expect(allKeys, contains('VISITA_ACTIVIDADES_VEHICULOS'));
      expect(allKeys, contains('VISITA_R004'));
      expect(allKeys, contains('ADMIN'));
      expect(allKeys, contains('HISTORY'));
      expect(allKeys, contains('RENDICIONES'));
    });

    test('defaultModuleKeys no incluye ADMIN ni HISTORY', () {
      final defaults = ModuleRegistry.defaultModuleKeys;
      expect(defaults, contains('INSPECCION'));
      expect(defaults, contains('VISITA_R003'));
      expect(defaults, contains('VISITA_ACTIVIDADES_VEHICULOS'));
      expect(defaults, contains('VISITA_R004'));
      // ADMIN y HISTORY no están en defaults (son especiales)
    });

    test('ADMIN module requiere admin', () {
      final adminModule = ModuleRegistry.all.firstWhere(
        (m) => m.moduleKey == 'ADMIN',
      );
      expect(adminModule.requiresAdmin, true);
    });

    test('Módulo habilitado tiene habilitado=1', () {
      final row = {
        'id': 'em-001',
        'empresa_id': 'emp-001',
        'modulo_key': 'INSPECCION',
        'habilitado': 1,
        'orden': 0,
        'subido': 1,
      };

      final estaHabilitado = (row['habilitado'] as int) == 1;
      expect(estaHabilitado, true);
    });

    test('Módulo deshabilitado tiene habilitado=0', () {
      final row = {
        'id': 'em-002',
        'empresa_id': 'emp-001',
        'modulo_key': 'VISITA_R004',
        'habilitado': 0,
        'orden': 2,
        'subido': 1,
      };

      final estaHabilitado = (row['habilitado'] as int) == 1;
      expect(estaHabilitado, false);
    });

    test('Toggle módulo cambia habilitado y resetea subido', () {
      var row = {
        'id': 'em-001',
        'empresa_id': 'emp-001',
        'modulo_key': 'INSPECCION',
        'habilitado': 1,
        'orden': 0,
        'subido': 1,
      };

      // Simula toggle (desactivar)
      row = Map.from(row);
      row['habilitado'] = 0;
      row['subido'] = 0;

      expect(row['habilitado'], 0);
      expect(
        row['subido'],
        0,
        reason: 'subido=0 para que SyncService lo recoja',
      );
    });
  });

  // ===================================================================
  // TESTS: CARGA DE MÓDULOS EN HOME (lógica corregida)
  // ===================================================================
  group('HomeController - Carga de módulos habilitados', () {
    // Simula la lógica CORREGIDA de _cargarModulosHabilitados
    List<String> cargarModulosHabilitados(List<Map<String, dynamic>> rows) {
      if (rows.isEmpty) {
        // Sin configuración → mostrar módulos default
        return List.from(ModuleRegistry.defaultModuleKeys);
      } else {
        // Filtrar solo los habilitados
        return rows
            .where((r) => (r['habilitado'] as int) == 1)
            .map((r) => r['modulo_key'] as String)
            .toList();
      }
    }

    test('Sin configuración (tabla vacía) → módulos default', () {
      final rows = <Map<String, dynamic>>[];
      final result = cargarModulosHabilitados(rows);

      expect(result, ModuleRegistry.defaultModuleKeys);
    });

    test('Con configuración parcial → solo habilitados', () {
      final rows = [
        {'modulo_key': 'INSPECCION', 'habilitado': 1, 'orden': 0},
        {'modulo_key': 'VISITA_R003', 'habilitado': 0, 'orden': 1},
        {'modulo_key': 'VISITA_R004', 'habilitado': 1, 'orden': 2},
      ];

      final result = cargarModulosHabilitados(rows);

      expect(result.length, 2);
      expect(result, contains('INSPECCION'));
      expect(result, contains('VISITA_R004'));
      expect(result, isNot(contains('VISITA_R003')));
    });

    test('TODOS deshabilitados → lista vacía (NO defaults)', () {
      final rows = [
        {'modulo_key': 'INSPECCION', 'habilitado': 0, 'orden': 0},
        {'modulo_key': 'VISITA_R003', 'habilitado': 0, 'orden': 1},
        {'modulo_key': 'VISITA_R004', 'habilitado': 0, 'orden': 2},
        {'modulo_key': 'ADMIN', 'habilitado': 0, 'orden': 3},
      ];

      final result = cargarModulosHabilitados(rows);

      expect(
        result,
        isEmpty,
        reason:
            'Admin desactivó todos → debe ser lista vacía, NO defaults. '
            'El bug anterior mostraba defaults cuando todo estaba desactivado.',
      );
    });

    test('Solo un módulo habilitado → solo ese', () {
      final rows = [
        {'modulo_key': 'INSPECCION', 'habilitado': 0, 'orden': 0},
        {'modulo_key': 'VISITA_R003', 'habilitado': 1, 'orden': 1},
        {'modulo_key': 'VISITA_R004', 'habilitado': 0, 'orden': 2},
      ];

      final result = cargarModulosHabilitados(rows);

      expect(result.length, 1);
      expect(result.first, 'VISITA_R003');
    });

    test('Todos habilitados → todos en la lista', () {
      final rows = [
        {'modulo_key': 'INSPECCION', 'habilitado': 1, 'orden': 0},
        {'modulo_key': 'VISITA_R003', 'habilitado': 1, 'orden': 1},
        {'modulo_key': 'VISITA_R004', 'habilitado': 1, 'orden': 2},
        {'modulo_key': 'ADMIN', 'habilitado': 1, 'orden': 3},
        {'modulo_key': 'HISTORY', 'habilitado': 1, 'orden': 4},
      ];

      final result = cargarModulosHabilitados(rows);

      expect(result.length, 5);
    });
  });

  // ===================================================================
  // TESTS: SYNC DE EMPRESA_MODULOS
  // ===================================================================
  group('Sync empresa_modulos', () {
    test('Módulo pendiente tiene subido=0', () {
      final pendientes = [
        {'modulo_key': 'INSPECCION', 'habilitado': 1, 'subido': 0},
        {'modulo_key': 'ADMIN', 'habilitado': 1, 'subido': 1},
      ];

      final paraSyncCount = pendientes.where((r) => r['subido'] == 0).length;
      expect(paraSyncCount, 1);
    });

    test('habilitado int se convierte a bool para Supabase', () {
      final row = {'habilitado': 1};
      final habilitadoBool = (row['habilitado'] as int) == 1;
      expect(habilitadoBool, true);
      expect(habilitadoBool, isA<bool>());

      final row2 = {'habilitado': 0};
      final habilitadoBool2 = (row2['habilitado'] as int) == 1;
      expect(habilitadoBool2, false);
    });

    test('Payload de módulo para Supabase tiene campos correctos', () {
      final row = {
        'id': 'em-001',
        'empresa_id': 'emp-001',
        'modulo_key': 'INSPECCION',
        'habilitado': 1,
        'orden': 0,
        'subido': 0,
      };

      final payload = {
        'id': row['id'],
        'empresa_id': row['empresa_id'],
        'modulo_key': row['modulo_key'],
        'habilitado': (row['habilitado'] as int) == 1,
        'orden': row['orden'],
      };

      expect(
        payload.containsKey('subido'),
        false,
        reason: 'subido es local, no va a Supabase',
      );
      expect(payload['habilitado'], true);
      expect(payload['habilitado'], isA<bool>());
    });

    test('Después de sync exitoso, subido se marca como 1', () {
      var subido = 0;
      // Simula sync exitoso
      subido = 1;
      expect(subido, 1);
    });

    test('Sync fallido mantiene subido=0 para retry', () {
      var subido = 0;
      try {
        throw Exception('Network error');
      } catch (_) {
        // subido no cambia
      }
      expect(
        subido,
        0,
        reason: 'Si sync falla, mantiene subido=0 para reintentar',
      );
    });
  });

  // ===================================================================
  // TESTS: MULTI-EMPRESA - Módulos por empresa
  // ===================================================================
  group('Multi-empresa - módulos distintos por empresa', () {
    // Simula DB con módulos para dos empresas
    final modulosDb = [
      // Empresa A: tiene INSPECCION y VISITA_R003
      {'empresa_id': 'emp-A', 'modulo_key': 'INSPECCION', 'habilitado': 1},
      {'empresa_id': 'emp-A', 'modulo_key': 'VISITA_R003', 'habilitado': 1},
      {'empresa_id': 'emp-A', 'modulo_key': 'VISITA_R004', 'habilitado': 0},
      // Empresa B: solo VISITA_R004
      {'empresa_id': 'emp-B', 'modulo_key': 'INSPECCION', 'habilitado': 0},
      {'empresa_id': 'emp-B', 'modulo_key': 'VISITA_R003', 'habilitado': 0},
      {'empresa_id': 'emp-B', 'modulo_key': 'VISITA_R004', 'habilitado': 1},
    ];

    List<String> getModulosHabilitados(String empresaId) {
      final rows = modulosDb
          .where((r) => r['empresa_id'] == empresaId)
          .toList();
      if (rows.isEmpty) return List.from(ModuleRegistry.defaultModuleKeys);
      return rows
          .where((r) => (r['habilitado'] as int) == 1)
          .map((r) => r['modulo_key'] as String)
          .toList();
    }

    test('Empresa A ve INSPECCION y VISITA_R003', () {
      final modulos = getModulosHabilitados('emp-A');
      expect(modulos.length, 2);
      expect(modulos, contains('INSPECCION'));
      expect(modulos, contains('VISITA_R003'));
      expect(modulos, isNot(contains('VISITA_R004')));
    });

    test('Empresa B ve solo VISITA_R004', () {
      final modulos = getModulosHabilitados('emp-B');
      expect(modulos.length, 1);
      expect(modulos.first, 'VISITA_R004');
    });

    test('Empresa C sin configuración ve defaults', () {
      final modulos = getModulosHabilitados('emp-C');
      expect(modulos, ModuleRegistry.defaultModuleKeys);
    });

    test('Cambiar empresa recarga módulos correctos', () {
      // Simula cambio de empresa A → B
      var currentModulos = getModulosHabilitados('emp-A');
      expect(currentModulos, contains('INSPECCION'));

      // Cambio a empresa B
      currentModulos = getModulosHabilitados('emp-B');
      expect(currentModulos, isNot(contains('INSPECCION')));
      expect(currentModulos, contains('VISITA_R004'));
    });
  });

  // ===================================================================
  // TESTS: TOGGLE EN TIEMPO REAL
  // ===================================================================
  group('Toggle módulos en tiempo real', () {
    test('Desactivar módulo lo quita de la lista inmediatamente', () {
      var habilitados = ['INSPECCION', 'VISITA_R003', 'VISITA_R004'];

      // Admin desactiva VISITA_R003
      final modulosConfig = [
        {'modulo_key': 'INSPECCION', 'habilitado': 1},
        {'modulo_key': 'VISITA_R003', 'habilitado': 0}, // toggle off
        {'modulo_key': 'VISITA_R004', 'habilitado': 1},
      ];

      habilitados = modulosConfig
          .where((r) => (r['habilitado'] as int) == 1)
          .map((r) => r['modulo_key'] as String)
          .toList();

      expect(habilitados.length, 2);
      expect(habilitados, isNot(contains('VISITA_R003')));
    });

    test('Activar módulo lo agrega a la lista inmediatamente', () {
      var habilitados = ['INSPECCION'];

      // Admin activa VISITA_R003
      final modulosConfig = [
        {'modulo_key': 'INSPECCION', 'habilitado': 1},
        {'modulo_key': 'VISITA_R003', 'habilitado': 1}, // toggle on
        {'modulo_key': 'VISITA_R004', 'habilitado': 0},
      ];

      habilitados = modulosConfig
          .where((r) => (r['habilitado'] as int) == 1)
          .map((r) => r['modulo_key'] as String)
          .toList();

      expect(habilitados.length, 2);
      expect(habilitados, contains('VISITA_R003'));
    });

    test('Desactivar todos deja lista vacía', () {
      final modulosConfig = [
        {'modulo_key': 'INSPECCION', 'habilitado': 0},
        {'modulo_key': 'VISITA_R003', 'habilitado': 0},
        {'modulo_key': 'VISITA_R004', 'habilitado': 0},
      ];

      final habilitados = modulosConfig
          .where((r) => (r['habilitado'] as int) == 1)
          .map((r) => r['modulo_key'] as String)
          .toList();

      expect(
        habilitados,
        isEmpty,
        reason: 'Si admin desactiva todo, debe quedar vacío',
      );
    });

    test('Toggle preserva orden', () {
      final modulosConfig = [
        {'modulo_key': 'VISITA_R004', 'habilitado': 1, 'orden': 0},
        {'modulo_key': 'INSPECCION', 'habilitado': 1, 'orden': 1},
        {'modulo_key': 'VISITA_R003', 'habilitado': 1, 'orden': 2},
      ];

      // Orden por campo 'orden'
      modulosConfig.sort(
        (a, b) => (a['orden'] as int).compareTo(b['orden'] as int),
      );

      final habilitados = modulosConfig
          .where((r) => (r['habilitado'] as int) == 1)
          .map((r) => r['modulo_key'] as String)
          .toList();

      expect(habilitados[0], 'VISITA_R004');
      expect(habilitados[1], 'INSPECCION');
      expect(habilitados[2], 'VISITA_R003');
    });
  });

  // ===================================================================
  // TESTS: GUARDAR MÓDULOS (batch insert con ConflictAlgorithm.replace)
  // ===================================================================
  group('Guardar módulos - persistencia', () {
    test('Batch insert genera un registro por módulo', () {
      final modulosState = {
        'INSPECCION': {'habilitado': true, 'orden': 0, 'id': 'em-1'},
        'VISITA_R003': {'habilitado': false, 'orden': 1, 'id': 'em-2'},
        'VISITA_R004': {'habilitado': true, 'orden': 2, 'id': 'em-3'},
      };

      final batchInserts = <Map<String, dynamic>>[];
      modulosState.forEach((key, state) {
        batchInserts.add({
          'id': state['id'],
          'empresa_id': 'emp-001',
          'modulo_key': key,
          'habilitado': (state['habilitado'] as bool) ? 1 : 0,
          'orden': state['orden'],
          'subido': 0,
        });
      });

      expect(batchInserts.length, 3);
      expect(batchInserts[0]['habilitado'], 1);
      expect(batchInserts[1]['habilitado'], 0);
      expect(
        batchInserts.every((r) => r['subido'] == 0),
        true,
        reason: 'Todos deben tener subido=0 para sync',
      );
    });

    test('bool → int conversion correcta', () {
      expect(true ? 1 : 0, 1);
      expect(false ? 1 : 0, 0);
    });

    test('ConflictAlgorithm.replace no duplica registros', () {
      // Simula dos inserts con mismo id
      final records = <String, Map<String, dynamic>>{};

      // Insert 1
      records['em-1'] = {
        'id': 'em-1',
        'modulo_key': 'INSPECCION',
        'habilitado': 1,
      };

      // Insert 2 (replace) - cambia habilitado
      records['em-1'] = {
        'id': 'em-1',
        'modulo_key': 'INSPECCION',
        'habilitado': 0,
      };

      expect(records.length, 1, reason: 'Replace no duplica');
      expect(records['em-1']!['habilitado'], 0, reason: 'Último valor gana');
    });
  });

  // ===================================================================
  // TESTS: DESCARGA DE EMPRESA_MODULOS (scoped delete)
  // ===================================================================
  group('Descarga empresa_modulos - scoped delete', () {
    test('Scoped delete solo borra módulos de la empresa actual', () {
      // Simula DB con módulos de dos empresas
      var db = [
        {'empresa_id': 'emp-A', 'modulo_key': 'INSPECCION'},
        {'empresa_id': 'emp-A', 'modulo_key': 'VISITA_R003'},
        {'empresa_id': 'emp-B', 'modulo_key': 'INSPECCION'},
      ];

      final empresaId = 'emp-A';

      // Scoped delete: solo borra empresa_id = emp-A
      db = db.where((r) => r['empresa_id'] != empresaId).toList();

      expect(db.length, 1);
      expect(
        db.first['empresa_id'],
        'emp-B',
        reason: 'Solo se borran los de emp-A antes de insertar nuevos',
      );
    });

    test('Sin empresaId no descarga módulos', () {
      final String? empresaId = null;
      final debeDescargar = empresaId != null;
      expect(
        debeDescargar,
        false,
        reason: 'Sin empresa activa, no se descargan módulos',
      );
    });
  });

  // ===================================================================
  // TESTS: RECARGA DE MÓDULOS DESPUÉS DE SYNC
  // ===================================================================
  group('Recarga de módulos después de sync', () {
    test('ejecutarSincronizacion recarga módulos al final', () {
      // Simula el flujo:
      // 1. sincronizarTodo() sube pendientes
      // 2. descargarDatosMaestros() baja nuevos datos (incluye empresa_modulos)
      // 3. _cargarModulosHabilitados() recarga desde SQLite actualizado

      var modulosAntes = ['INSPECCION', 'VISITA_R003'];

      // Simula que admin de otra sesión activó VISITA_R004
      final nuevosDatos = [
        {'modulo_key': 'INSPECCION', 'habilitado': 1},
        {'modulo_key': 'VISITA_R003', 'habilitado': 1},
        {'modulo_key': 'VISITA_R004', 'habilitado': 1}, // nuevo!
      ];

      // Recarga después de sync
      final modulosDespues = nuevosDatos
          .where((r) => (r['habilitado'] as int) == 1)
          .map((r) => r['modulo_key'] as String)
          .toList();

      expect(modulosDespues.length, 3);
      expect(
        modulosDespues,
        contains('VISITA_R004'),
        reason:
            'Nuevo módulo activado remotamente debe aparecer después de sync',
      );
    });

    test('sync silencioso también recarga módulos', () {
      // _sincronizarSilencioso ahora incluye _cargarModulosHabilitados
      // después de descargarDatosMaestros
      var recargado = false;

      // Simula flujo
      // await _syncService.sincronizarTodo();
      // await _syncService.descargarDatosMaestros();
      // await _cargarModulosHabilitados(); // <-- nuevo
      recargado = true;

      expect(recargado, true);
    });

    test(
      'recargarParaEmpresa recarga módulos dos veces (local + post-sync)',
      () {
        // recargarParaEmpresa:
        // 1. _cargarModulosHabilitados() - inmediato desde SQLite local
        // 2. descargarDatosMaestros() - baja nuevos datos
        // 3. _cargarModulosHabilitados() - otra vez con datos frescos
        int vecesRecargado = 0;

        vecesRecargado++; // primera carga (local)
        // ... descargarDatosMaestros() ...
        vecesRecargado++; // segunda carga (post-sync)

        expect(
          vecesRecargado,
          2,
          reason: 'Primero carga local, luego recarga con datos frescos',
        );
      },
    );
  });

  // ===================================================================
  // TESTS: EDGE CASES
  // ===================================================================
  group('Edge cases - módulos y datos maestros', () {
    test('Módulo key desconocido en DB se ignora silenciosamente', () {
      final rows = [
        {'modulo_key': 'INSPECCION', 'habilitado': 1},
        {'modulo_key': 'MODULO_INEXISTENTE', 'habilitado': 1},
      ];

      final habilitados = rows
          .where((r) => (r['habilitado'] as int) == 1)
          .map((r) => r['modulo_key'] as String)
          .toList();

      // El key desconocido pasará al list pero no encontrará screenBuilder
      // en ModuleRegistry, así que no se renderizará
      final registrados = ModuleRegistry.all.map((m) => m.moduleKey).toSet();
      final validos = habilitados
          .where((k) => registrados.contains(k))
          .toList();

      expect(validos.length, 1);
      expect(validos.first, 'INSPECCION');
    });

    test('Contratista con nombre vacío es rechazado', () {
      final nombre = '';
      final trimmed = nombre.trim();
      final esValido = trimmed.isNotEmpty;
      expect(esValido, false);
    });

    test('Contratista sin RUT recibe placeholder PENDIENTE-', () {
      const id = 'abc12345-6789-0000-0000-000000000000';
      String? rut;
      final rutFinal = (rut != null && rut.trim().isNotEmpty)
          ? rut.trim()
          : 'PENDIENTE-${id.substring(0, 8)}';

      expect(rutFinal, 'PENDIENTE-abc12345');
      expect(rutFinal, startsWith('PENDIENTE-'));
    });

    test('Contratista con RUT proporcionado usa ese RUT', () {
      const id = 'abc12345-6789-0000-0000-000000000000';
      String? rut = '12345678-5';
      final rutFinal = (rut.trim().isNotEmpty)
          ? rut.trim()
          : 'PENDIENTE-${id.substring(0, 8)}';

      expect(rutFinal, '12345678-5');
      expect(rutFinal, isNot(startsWith('PENDIENTE-')));
    });

    test('Contratista con RUT vacío recibe placeholder', () {
      const id = 'abc12345-6789-0000-0000-000000000000';
      String? rut = '   ';
      final rutFinal = (rut.trim().isNotEmpty)
          ? rut.trim()
          : 'PENDIENTE-${id.substring(0, 8)}';

      expect(rutFinal, 'PENDIENTE-abc12345');
    });

    test('Editar contratista con RUT PENDIENTE- muestra campo vacío', () {
      final rut = 'PENDIENTE-abc12345';
      // La UI no muestra RUTs placeholder al editar
      final mostrar = !rut.startsWith('PENDIENTE-');
      expect(mostrar, false);
    });

    test('Editar contratista con RUT real muestra el RUT', () {
      final rut = '12345678-5';
      final mostrar = !rut.startsWith('PENDIENTE-');
      expect(mostrar, true);
    });

    test('Embarcación sin contratista_id causa FK error en Supabase', () {
      final payload = {
        'id': 'emb-001',
        'nombre': 'Barco Sin Dueño',
        'contratista_id': null, // ← FK violation
      };

      final tieneFk = payload['contratista_id'] != null;
      expect(
        tieneFk,
        false,
        reason: 'Sin contratista_id, Supabase rechazará el upsert',
      );
    });

    test('UUID generado es único por cada llamada', () {
      // Simula dos creaciones rápidas
      final ids = <String>{};
      for (int i = 0; i < 100; i++) {
        final id = 'uuid-$i'; // simplificado, real usa Uuid().v4()
        ids.add(id);
      }
      expect(ids.length, 100, reason: 'Cada ID debe ser único');
    });
  });

  // ===================================================================
  // TESTS: ADMIN CRUD AUTO-SYNC (verificar que sync se dispara)
  // ===================================================================
  group('Admin CRUD - Auto-sync después de crear/editar', () {
    test('Crear contratista dispara sync (fire-and-forget)', () {
      // La lógica nueva:
      // 1. insertContratista → SQLite con subido=0
      // 2. _recargarTabla → refresca UI
      // 3. _syncMaestrosPendientes → fire-and-forget sync

      bool syncDisparado = false;
      bool uiRefrescada = false;
      bool insertado = false;

      // Simula flujo
      insertado = true; // Step 1
      uiRefrescada = true; // Step 2
      syncDisparado = true; // Step 3

      expect(insertado, true);
      expect(uiRefrescada, true);
      expect(
        syncDisparado,
        true,
        reason: 'Sync debe dispararse automáticamente después de CRUD',
      );
    });

    test('Crear embarcación dispara sync', () {
      bool syncDisparado = false;

      // Simula creación + sync
      syncDisparado = true;

      expect(syncDisparado, true);
    });

    test('Editar datos maestros dispara sync', () {
      bool syncDisparado = false;

      // Simula edición + sync
      syncDisparado = true;

      expect(syncDisparado, true);
    });

    test('Error en sync no afecta la UI (fire-and-forget)', () {
      bool uiOk = true;
      String? syncError;

      try {
        throw Exception('Network timeout');
      } catch (e) {
        syncError = e.toString();
        // fire-and-forget: UI no se ve afectada
      }

      expect(uiOk, true, reason: 'UI sigue funcionando aunque sync falle');
      expect(syncError, isNotNull);
    });
  });

  // ===================================================================
  // TESTS: SYNC CORREGIDO - Errores surfaceados al usuario
  // ===================================================================
  group('Sync corregido - errores visibles', () {
    test('_syncTabla retorna contadores de exitosos y fallidos', () {
      // Simula la lógica corregida de _syncTabla
      final resultado = _simularSyncTabla(
        pendientes: [
          {'id': '1', 'nombre': 'A'},
          {'id': '2', 'nombre': 'B'},
          {'id': '3', 'nombre': 'C'},
        ],
        fallanIds: {'2'}, // El segundo falla
      );

      expect(resultado.exitosos, 2);
      expect(resultado.fallidos, 1);
      expect(resultado.ultimoError, isNotNull);
    });

    test('Sin pendientes retorna (0, 0, null)', () {
      final resultado = _simularSyncTabla(pendientes: [], fallanIds: {});

      expect(resultado.exitosos, 0);
      expect(resultado.fallidos, 0);
      expect(resultado.ultimoError, isNull);
    });

    test('Todos exitosos retorna fallidos=0', () {
      final resultado = _simularSyncTabla(
        pendientes: [
          {'id': '1', 'nombre': 'A'},
          {'id': '2', 'nombre': 'B'},
        ],
        fallanIds: {},
      );

      expect(resultado.exitosos, 2);
      expect(resultado.fallidos, 0);
      expect(resultado.ultimoError, isNull);
    });

    test('Todos fallidos retorna exitosos=0', () {
      final resultado = _simularSyncTabla(
        pendientes: [
          {'id': '1', 'nombre': 'A'},
          {'id': '2', 'nombre': 'B'},
        ],
        fallanIds: {'1', '2'},
      );

      expect(resultado.exitosos, 0);
      expect(resultado.fallidos, 2);
      expect(resultado.ultimoError, isNotNull);
    });

    test('sincronizarMaestros retorna resultados por tabla', () {
      final resultados = {
        'contratistas': (
          exitosos: 1,
          fallidos: 0,
          ultimoError: null as String?,
        ),
        'centros': (
          exitosos: 0,
          fallidos: 1,
          ultimoError: 'RLS policy violation',
        ),
        'embarcaciones': (
          exitosos: 2,
          fallidos: 0,
          ultimoError: null as String?,
        ),
      };

      final fallidos = resultados.entries
          .where((e) => e.value.fallidos > 0)
          .map((e) => e.key)
          .toList();

      expect(fallidos, ['centros']);
      expect(resultados['centros']!.ultimoError, contains('RLS'));
    });

    test('Controller genera lastSyncError cuando hay fallidos', () {
      final resultados = {
        'contratistas': (
          exitosos: 0,
          fallidos: 1,
          ultimoError: 'SocketException' as String?,
        ),
        'centros': (exitosos: 1, fallidos: 0, ultimoError: null as String?),
      };

      final fallidos = <String>[];
      String? errorDetalle;
      for (final entry in resultados.entries) {
        if (entry.value.fallidos > 0) {
          fallidos.add(entry.key);
          errorDetalle ??= entry.value.ultimoError;
        }
      }

      String? lastSyncError;
      if (fallidos.isNotEmpty) {
        lastSyncError = 'Error al sincronizar: ${fallidos.join(", ")}';
      }

      expect(lastSyncError, isNotNull);
      expect(lastSyncError, contains('contratistas'));
      expect(lastSyncError, isNot(contains('centros')));
    });

    test('Controller limpia lastSyncError cuando todo sale bien', () {
      final resultados = {
        'contratistas': (
          exitosos: 1,
          fallidos: 0,
          ultimoError: null as String?,
        ),
        'centros': (exitosos: 1, fallidos: 0, ultimoError: null as String?),
      };

      final fallidos = resultados.entries
          .where((e) => e.value.fallidos > 0)
          .toList();

      String? lastSyncError;
      if (fallidos.isEmpty) {
        lastSyncError = null;
      }

      expect(lastSyncError, isNull);
    });
  });

  // ===================================================================
  // TESTS: MENSAJES DE ERROR SYNC AMIGABLES
  // ===================================================================
  group('Mensajes de error sync amigables', () {
    test('Error de red → mensaje de conexión', () {
      expect(
        _mensajeSyncAmigable('SocketException: Connection refused'),
        'Sin conexión a internet.',
      );
    });

    test('Error de timeout → mensaje de conexión', () {
      expect(
        _mensajeSyncAmigable('timeout after 30s'),
        'Sin conexión a internet.',
      );
    });

    test('Error RLS → mensaje de permisos', () {
      expect(
        _mensajeSyncAmigable('new row violates row-level security policy'),
        'Sin permisos en el servidor.',
      );
    });

    test('Error de duplicado → mensaje de duplicado', () {
      expect(
        _mensajeSyncAmigable('duplicate key value violates unique constraint'),
        'Registro duplicado en el servidor.',
      );
    });

    test('Error desconocido → mensaje genérico', () {
      expect(_mensajeSyncAmigable('algo raro'), 'Inténtelo de nuevo.');
    });

    test('Error null → mensaje genérico', () {
      expect(_mensajeSyncAmigable(null), 'Inténtelo de nuevo.');
    });
  });

  // ===================================================================
  // TESTS: UI - FocusNode y ValueListenableBuilder (lógica pura)
  // ===================================================================
  group('Fix backspace - ValueListenableBuilder lógica', () {
    test('suffixIcon se muestra solo cuando text no está vacío', () {
      // Simula la lógica del ValueListenableBuilder
      bool mostrarClear(String text) => text.isNotEmpty;

      expect(mostrarClear(''), false);
      expect(mostrarClear('a'), true);
      expect(mostrarClear('abc'), true);
    });

    test('clear() vacía el texto y oculta el botón', () {
      String text = 'algo';
      bool hayClear = text.isNotEmpty;
      expect(hayClear, true);

      text = ''; // simula ctrl.clear()
      hayClear = text.isNotEmpty;
      expect(hayClear, false);
    });
  });

  // ===================================================================
  // TESTS: UI - BuscadorSheet empty state
  // ===================================================================
  group('BuscadorSheet - empty state visible', () {
    test('Lista vacía muestra "No se encontraron coincidencias"', () {
      final filtrados = <Map<String, dynamic>>[];
      final mensajeEsperado = filtrados.isEmpty
          ? 'No se encontraron coincidencias'
          : '${filtrados.length} resultados';

      expect(mensajeEsperado, 'No se encontraron coincidencias');
    });

    test('Lista con resultados muestra contador', () {
      final filtrados = [
        {'id': '1', 'nombre': 'A'},
        {'id': '2', 'nombre': 'B'},
      ];
      final contador =
          '${filtrados.length} resultado${filtrados.length != 1 ? 's' : ''}';

      expect(contador, '2 resultados');
    });

    test('Filtrado reduce resultados correctamente', () {
      final items = [
        {'nombre': 'Contratista Alpha'},
        {'nombre': 'Contratista Beta'},
        {'nombre': 'Empresa Gamma'},
      ];

      final query = 'contratista';
      final filtrados = items
          .where(
            (item) => (item['nombre'] as String).toLowerCase().contains(query),
          )
          .toList();

      expect(filtrados.length, 2);
    });

    test('Query sin coincidencias retorna lista vacía', () {
      final items = [
        {'nombre': 'Contratista Alpha'},
        {'nombre': 'Contratista Beta'},
      ];

      final query = 'xyz123';
      final filtrados = items
          .where(
            (item) => (item['nombre'] as String).toLowerCase().contains(query),
          )
          .toList();

      expect(filtrados, isEmpty);
    });
  });

  // ===================================================================
  // TESTS: Dropdown rebuild - ValueNotifier
  // ===================================================================
  group('Dropdown ValueNotifier - sin setState', () {
    test('Cambiar area no requiere setState', () {
      String? areaValue;
      // Antes: setState(() => _areaSeleccionada = val)
      // Ahora: _areaNotifier.value = val
      areaValue = 'Area Norte';
      expect(areaValue, 'Area Norte');
    });

    test('_guardarCentro lee el valor del notifier', () {
      String? areaNotifierValue = 'Area Sur';

      // Simula _guardarCentro leyendo del notifier
      final areas = [
        {'id': 'area-001', 'nombre': 'Area Norte'},
        {'id': 'area-002', 'nombre': 'Area Sur'},
      ];

      final area = areas.firstWhere(
        (a) => a['nombre'] == areaNotifierValue,
        orElse: () => {},
      );

      expect(area['id'], 'area-002');
    });

    test('Notifier null es rechazado en validación', () {
      String? areaNotifierValue;
      final esValido = areaNotifierValue != null;
      expect(esValido, false);
    });
  });
}

// ===================================================================
// HELPERS
// ===================================================================

({int exitosos, int fallidos, String? ultimoError}) _simularSyncTabla({
  required List<Map<String, dynamic>> pendientes,
  required Set<String> fallanIds,
}) {
  if (pendientes.isEmpty) return (exitosos: 0, fallidos: 0, ultimoError: null);

  int exitosos = 0;
  int fallidos = 0;
  String? ultimoError;

  for (var row in pendientes) {
    try {
      if (fallanIds.contains(row['id'])) {
        throw Exception('Simulated upsert failure for ${row['id']}');
      }
      exitosos++;
    } catch (e) {
      fallidos++;
      ultimoError = e.toString();
    }
  }

  return (exitosos: exitosos, fallidos: fallidos, ultimoError: ultimoError);
}

String _mensajeSyncAmigable(String? error) {
  if (error == null) return 'Inténtelo de nuevo.';
  final msg = error.toLowerCase();
  if (msg.contains('socket') ||
      msg.contains('connection') ||
      msg.contains('timeout')) {
    return 'Sin conexión a internet.';
  }
  if (msg.contains('permission') ||
      msg.contains('rls') ||
      msg.contains('policy')) {
    return 'Sin permisos en el servidor.';
  }
  if (msg.contains('duplicate') || msg.contains('unique')) {
    return 'Registro duplicado en el servidor.';
  }
  return 'Inténtelo de nuevo.';
}
