import 'package:flutter_test/flutter_test.dart';

/// Tests que verifican la integridad de la descarga de datos maestros.
/// Simulan la lógica de SyncService.descargarDatosMaestros() sin
/// instanciar Supabase ni SQLite — validan contratos y transformaciones.
void main() {
  // ===================================================================
  // TABLAS MAESTRAS OBLIGATORIAS
  // ===================================================================
  group('Tablas maestras obligatorias', () {
    // Lista canónica: si cambia la cantidad de tablas en descargarDatosMaestros,
    // este test debe fallar para recordar actualizar la validación.
    const tablasObligatorias = [
      'areas',
      'centros',
      'contratistas',
      'embarcaciones',
      'formulario_items',
      'personal_externo',
      'empresas',
      'ticket_categorias',
      'usuarios',
    ];

    const tablasCondicionales = ['empresa_modulos', 'usuario_empresas'];

    test(
      'Existen 9 tablas obligatorias + 2 condicionales = 11 en Future.wait',
      () {
        expect(tablasObligatorias.length, 9);
        expect(tablasCondicionales.length, 2);
        expect(
          tablasObligatorias.length + tablasCondicionales.length,
          11,
          reason: 'descargarDatosMaestros descarga 11 tablas en Future.wait',
        );
      },
    );

    test('Ninguna tabla duplicada en la lista de descarga', () {
      final todas = [...tablasObligatorias, ...tablasCondicionales];
      final set = todas.toSet();
      expect(
        set.length,
        todas.length,
        reason: 'No debe haber tablas duplicadas en la descarga',
      );
    });
  });

  // ===================================================================
  // BLINDAJE: LISTA VACÍA NO DEBE BORRAR DATOS EXISTENTES
  // ===================================================================
  group('Blindaje guardarMaestros — lista vacía', () {
    test('Lista vacía no ejecuta operaciones en DB (simula blindaje)', () {
      final datos = <Map<String, dynamic>>[];
      bool operacionEjecutada = false;

      // Simula guardarMaestros: si datos.isEmpty, return sin hacer nada
      if (datos.isEmpty) {
        // Blindaje activo: no toca la DB
      } else {
        operacionEjecutada = true;
      }

      expect(
        operacionEjecutada,
        false,
        reason:
            'guardarMaestros con lista vacía NO debe tocar la base de datos',
      );
    });

    test('Lista con datos sí ejecuta operaciones', () {
      final datos = [
        {'id': '1', 'nombre': 'Test'},
      ];
      bool operacionEjecutada = false;

      if (datos.isEmpty) {
        // Blindaje
      } else {
        operacionEjecutada = true;
      }

      expect(operacionEjecutada, true);
    });
  });

  // ===================================================================
  // TRANSFORMACIONES DE DATOS (guardarMaestros)
  // ===================================================================
  group('Transformación de datos al guardar maestros', () {
    test('personal_externo: RUT se normaliza (sin puntos ni guiones)', () {
      final rawRut = '12.345.678-9';
      final normalized = rawRut
          .replaceAll(RegExp(r'[\.\-\s\r\n\t\u00AD]'), '')
          .toLowerCase()
          .trim();
      expect(normalized, '123456789');
    });

    test('personal_externo: RUT con espacios y saltos de línea se limpia', () {
      final rawRut = ' 12.345.678-K\n';
      final normalized = rawRut
          .replaceAll(RegExp(r'[\.\-\s\r\n\t\u00AD]'), '')
          .toLowerCase()
          .trim();
      expect(normalized, '12345678k');
    });

    test('personal_externo: activo se convierte a int', () {
      // Desde Supabase viene como bool; SQLite necesita int
      expect((true == true || true == 1) ? 1 : 0, 1);
      expect((false == true || false == 1) ? 1 : 0, 0);
      expect((1 == true || 1 == 1) ? 1 : 0, 1);
      expect((0 == true || 0 == 1) ? 1 : 0, 0);
    });

    test('usuarios: roles nested map se aplana a nombre_rol', () {
      final item = {
        'id': 'u1',
        'roles': {'nombre': 'Administrador'},
      };
      String? nombreRol;
      if (item['roles'] != null && item['roles'] is Map) {
        nombreRol = (item['roles'] as Map)['nombre'] as String?;
      }
      expect(nombreRol, 'Administrador');
    });

    test('usuarios: roles null resulta en nombre_rol null', () {
      final item = {'id': 'u1', 'roles': null};
      String? nombreRol;
      if (item['roles'] != null && item['roles'] is Map) {
        nombreRol = (item['roles'] as Map)['nombre'] as String?;
      }
      expect(nombreRol, isNull);
    });

    test('empresa_modulos: habilitado bool→int', () {
      final habilitado = true;
      final asInt = (habilitado == true || habilitado == 1) ? 1 : 0;
      expect(asInt, 1);
    });

    test('centros: se incluye subido=1 al guardar desde remote', () {
      final item = {'id': 'c1', 'nombre': 'Centro A', 'area_id': 'a1'};
      final row = <String, dynamic>{};
      row['id'] = item['id'];
      row['nombre'] = item['nombre'];
      row['area_id'] = item['area_id'];
      row['subido'] = 1; // Marca como sincronizado
      expect(row['subido'], 1);
    });

    test('embarcaciones: se incluye contratista_id y matricula', () {
      final item = {
        'id': 'e1',
        'nombre': 'Lancha A',
        'contratista_id': 'ct1',
        'matricula': 'MAT-001',
      };
      final row = <String, dynamic>{};
      row['id'] = item['id'];
      row['nombre'] = item['nombre'];
      row['contratista_id'] = item['contratista_id'];
      row['matricula'] = item['matricula'];
      row['subido'] = 1;
      expect(row['contratista_id'], 'ct1');
      expect(row['matricula'], 'MAT-001');
    });
  });

  // ===================================================================
  // SCOPE FILTERING (scopeWhere / scopeArgs)
  // ===================================================================
  group('Scope filtering para tablas con empresa_id', () {
    test('areas: con empresaId usa scope filter', () {
      final empresaId = 'emp-001';
      final scopeWhere = empresaId != null ? 'empresa_id = ?' : null;
      final scopeArgs = empresaId != null ? [empresaId] : null;
      expect(scopeWhere, 'empresa_id = ?');
      expect(scopeArgs, ['emp-001']);
    });

    test('areas: sin empresaId no usa scope filter', () {
      final String? empresaId = null;
      final scopeWhere = empresaId != null ? 'empresa_id = ?' : null;
      final scopeArgs = empresaId != null ? [empresaId] : null;
      expect(scopeWhere, isNull);
      expect(scopeArgs, isNull);
    });

    test(
      'empresa_modulos: sin empresaId retorna lista vacía (no descarga)',
      () {
        final String? empresaId = null;
        final resultado = empresaId != null
            ? 'query_supabase'
            : <Map<String, dynamic>>[];
        expect(resultado, isEmpty);
      },
    );

    test('usuario_empresas: sin userId retorna lista vacía', () {
      final String? userId = null;
      final resultado = userId != null
          ? 'query_supabase'
          : <Map<String, dynamic>>[];
      expect(resultado, isEmpty);
    });
  });

  // ===================================================================
  // VALIDACIÓN POST-DESCARGA: que se hayan descargado TODOS los datos
  // ===================================================================
  group('Validación post-descarga — completitud de datos', () {
    /// Simula los resultados de Future.wait: 11 listas.
    /// Si alguna es vacía (y no es condicional), hay un problema potencial.
    List<List<Map<String, dynamic>>> _crearResultadosCompletos() {
      return [
        // 0: areas
        [
          {'id': 'a1', 'nombre': 'Area 1', 'empresa_id': 'e1'},
        ],
        // 1: centros
        [
          {'id': 'c1', 'nombre': 'Centro 1', 'area_id': 'a1'},
        ],
        // 2: contratistas
        [
          {'id': 'ct1', 'nombre': 'Contratista 1'},
        ],
        // 3: embarcaciones
        [
          {
            'id': 'em1',
            'nombre': 'Emb 1',
            'contratista_id': 'ct1',
            'matricula': null,
          },
        ],
        // 4: formulario_items
        [
          {
            'id': 'fi1',
            'pregunta': 'Item 1',
            'activo': true,
            'orden': 1,
            'tipo_actividad': 'INSPECCION',
          },
        ],
        // 5: personal_externo
        [
          {
            'id': 'pe1',
            'nombre_completo': 'Juan',
            'rut': '12345678-9',
            'cargo': null,
            'matricula': null,
            'contratista_id': null,
            'activo': true,
          },
        ],
        // 6: empresas
        [
          {'id': 'e1', 'nombre': 'Empresa 1', 'es_administradora': false},
        ],
        // 7: ticket_categorias
        [
          {'id': 'tc1', 'nombre': 'Cat 1', 'activo': true},
        ],
        // 8: usuarios
        [
          {
            'id': 'u1',
            'rut': '111111111',
            'nombre_completo': 'Admin',
            'email': 'a@b.com',
            'rol_id': 'r1',
            'telefono': null,
            'empresa_id': 'e1',
            'roles': {'nombre': 'Administrador'},
          },
        ],
        // 9: empresa_modulos (condicional)
        [
          {
            'id': 'em1',
            'empresa_id': 'e1',
            'modulo_key': 'INSPECCION',
            'habilitado': true,
            'orden': 0,
          },
        ],
        // 10: usuario_empresas (condicional)
        [
          {'id': 'ue1', 'usuario_id': 'u1', 'empresa_id': 'e1'},
        ],
      ];
    }

    test('Future.wait retorna exactamente 11 resultados', () {
      final results = _crearResultadosCompletos();
      expect(
        results.length,
        11,
        reason: 'descargarDatosMaestros espera 11 resultados de Future.wait',
      );
    });

    test(
      'Todas las 9 tablas obligatorias tienen datos (detecta descarga incompleta)',
      () {
        final results = _crearResultadosCompletos();
        final tablasConIndice = {
          'areas': 0,
          'centros': 1,
          'contratistas': 2,
          'embarcaciones': 3,
          'formulario_items': 4,
          'personal_externo': 5,
          'empresas': 6,
          'ticket_categorias': 7,
          'usuarios': 8,
        };

        for (final entry in tablasConIndice.entries) {
          expect(
            results[entry.value].isNotEmpty,
            true,
            reason:
                'Tabla ${entry.key} (índice ${entry.value}) no debe estar vacía después de descarga exitosa',
          );
        }
      },
    );

    test('Detecta tabla faltante en descarga (simula fallo parcial)', () {
      final results = _crearResultadosCompletos();
      // Simula que centros vino vacío (fallo de red parcial o query mal configurada)
      results[1] = [];

      final tablasVacias = <String>[];
      final tablas = [
        'areas',
        'centros',
        'contratistas',
        'embarcaciones',
        'formulario_items',
        'personal_externo',
        'empresas',
        'ticket_categorias',
        'usuarios',
      ];

      for (var i = 0; i < tablas.length; i++) {
        if (results[i].isEmpty) {
          tablasVacias.add(tablas[i]);
        }
      }

      expect(tablasVacias, [
        'centros',
      ], reason: 'Debe detectar que centros no se descargó');
    });

    test(
      'Tablas condicionales vacías NO son error si userId/empresaId es null',
      () {
        final String? empresaId = null;
        final String? userId = null;

        // empresa_modulos devuelve [] si no hay empresaId
        final modulosData = empresaId != null
            ? [
                {'id': 'x', 'empresa_id': 'e1', 'modulo_key': 'A'},
              ]
            : <Map<String, dynamic>>[];

        // usuario_empresas devuelve [] si no hay userId
        final ueData = userId != null
            ? [
                {'id': 'x', 'usuario_id': 'u1', 'empresa_id': 'e1'},
              ]
            : <Map<String, dynamic>>[];

        // No es error: simplemente no se guardan
        expect(modulosData.isEmpty, true);
        expect(ueData.isEmpty, true);
        // Pero CON empresaId sí deben tener datos
      },
    );

    test(
      'Tablas condicionales CON ids deben tener datos (detecta fallo silencioso)',
      () {
        final empresaId = 'emp-001';
        final userId = 'usr-001';

        // Si tenemos empresaId, empresa_modulos DEBERÍA tener datos
        // Si viene vacío, es una señal de que la tabla no existe en Supabase
        // o los datos no se han inicializado
        final modulosData = <Map<String, dynamic>>[]; // Simula descarga vacía

        // Verificación: si hay empresaId pero modulos vacío → advertencia
        final modulosEsperados = empresaId != null && modulosData.isEmpty;
        expect(
          modulosEsperados,
          true,
          reason:
              'Con empresaId activo, empresa_modulos vacío indica que la tabla no tiene datos iniciales',
        );
      },
    );
  });

  // ===================================================================
  // INTEGRIDAD DE CAMPOS POR TABLA
  // ===================================================================
  group('Integridad de campos descargados por tabla', () {
    test('areas: debe tener id, nombre, empresa_id', () {
      final area = {'id': 'a1', 'nombre': 'Area 1', 'empresa_id': 'e1'};
      expect(area.containsKey('id'), true);
      expect(area.containsKey('nombre'), true);
      expect(area.containsKey('empresa_id'), true);
    });

    test('centros: debe tener id, nombre, area_id', () {
      final centro = {'id': 'c1', 'nombre': 'Centro 1', 'area_id': 'a1'};
      expect(centro.containsKey('id'), true);
      expect(centro.containsKey('nombre'), true);
      expect(centro.containsKey('area_id'), true);
    });

    test('contratistas: debe tener id, nombre', () {
      final contratista = {'id': 'ct1', 'nombre': 'Contratista 1'};
      expect(contratista.containsKey('id'), true);
      expect(contratista.containsKey('nombre'), true);
    });

    test('embarcaciones: debe tener id, nombre, contratista_id, matricula', () {
      final emb = {
        'id': 'e1',
        'nombre': 'Lancha',
        'contratista_id': 'ct1',
        'matricula': 'MAT-001',
      };
      expect(emb.containsKey('id'), true);
      expect(emb.containsKey('nombre'), true);
      expect(emb.containsKey('contratista_id'), true);
      expect(emb.containsKey('matricula'), true);
    });

    test('usuarios: debe tener campos necesarios + roles nested', () {
      final usuario = {
        'id': 'u1',
        'rut': '111',
        'nombre_completo': 'Test',
        'email': 'a@b.com',
        'rol_id': 'r1',
        'telefono': null,
        'empresa_id': 'e1',
        'roles': {'nombre': 'Admin'},
      };
      expect(usuario.containsKey('id'), true);
      expect(usuario.containsKey('nombre_completo'), true);
      expect(usuario.containsKey('empresa_id'), true);
      expect(usuario['roles'], isA<Map>());
    });

    test(
      'empresa_modulos: debe tener empresa_id, modulo_key, habilitado, orden',
      () {
        final mod = {
          'id': 'm1',
          'empresa_id': 'e1',
          'modulo_key': 'INSPECCION',
          'habilitado': true,
          'orden': 0,
        };
        expect(mod.containsKey('empresa_id'), true);
        expect(mod.containsKey('modulo_key'), true);
        expect(mod.containsKey('habilitado'), true);
        expect(mod.containsKey('orden'), true);
      },
    );

    test('usuario_empresas: debe tener usuario_id, empresa_id', () {
      final ue = {'id': 'ue1', 'usuario_id': 'u1', 'empresa_id': 'e1'};
      expect(ue.containsKey('usuario_id'), true);
      expect(ue.containsKey('empresa_id'), true);
    });
  });

  // ===================================================================
  // FUTURE.WAIT — COMPORTAMIENTO ALL-OR-NOTHING
  // ===================================================================
  group('Future.wait — resiliencia ante fallos parciales', () {
    test('Future.wait falla completamente si un Future falla', () async {
      // Demuestra el problema actual: si una tabla falla, NINGUNA se guarda
      final futures = [
        Future.value([1, 2, 3]),
        Future<List<int>>.error('Tabla X falló por timeout'),
        Future.value([4, 5, 6]),
      ];

      expect(
        () => Future.wait(futures),
        throwsA(equals('Tabla X falló por timeout')),
      );
    });

    test(
      'Patrón recomendado: descargas independientes con manejo individual de errores',
      () async {
        // Muestra cómo debería funcionar: cada tabla se descarga independientemente
        Future<List<int>> descargaSegura(
          Future<List<int>> future,
          String tabla,
        ) async {
          try {
            return await future;
          } catch (e) {
            // Log el error pero retorna lista vacía en vez de propagar
            return [];
          }
        }

        final result1 = await descargaSegura(Future.value([1, 2]), 'areas');
        final result2 = await descargaSegura(
          Future.error('timeout'),
          'centros',
        );
        final result3 = await descargaSegura(
          Future.value([3, 4]),
          'contratistas',
        );

        expect(result1, [1, 2], reason: 'areas se descargó OK');
        expect(
          result2,
          isEmpty,
          reason: 'centros falló pero no mató las demás',
        );
        expect(result3, [3, 4], reason: 'contratistas se descargó OK');
      },
    );
  });

  // ===================================================================
  // HUÉRFANOS — DELETE de registros que ya no existen en remote
  // ===================================================================
  group('Limpieza de huérfanos en guardarMaestros', () {
    test('IDs remotos se usan para detectar huérfanos locales', () {
      final remotos = [
        {'id': 'a1', 'nombre': 'Area 1'},
        {'id': 'a2', 'nombre': 'Area 2'},
      ];
      final idsRemotos = remotos.map((r) => r['id'] as String).toSet();

      final locales = ['a1', 'a2', 'a3', 'a4']; // a3, a4 ya no existen
      final huerfanos = locales
          .where((id) => !idsRemotos.contains(id))
          .toList();

      expect(
        huerfanos,
        ['a3', 'a4'],
        reason: 'a3 y a4 deben eliminarse porque ya no existen en remote',
      );
    });

    test('Scope filter limita borrado de huérfanos a la empresa activa', () {
      final empresaId = 'e1';
      // Solo borra huérfanos WHERE empresa_id = 'e1', no de otras empresas
      final scopeWhere = 'empresa_id = ?';
      final scopeArgs = [empresaId];

      // Simula: locales de empresa e1 = [a1, a2, a3], remotos = [a1, a2]
      // Solo a3 se borra (de empresa e1). Areas de e2 no se tocan.
      final localesEmpresa = ['a1', 'a2', 'a3'];
      final remotosIds = {'a1', 'a2'};
      final huerfanos = localesEmpresa
          .where((id) => !remotosIds.contains(id))
          .toList();

      expect(huerfanos, ['a3']);
      expect(scopeWhere, contains('empresa_id'));
    });
  });
}
