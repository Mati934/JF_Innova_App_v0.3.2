import 'package:flutter_test/flutter_test.dart';

/// Tests for the AdminCrudController optimizations and the new
/// master-data admin screen flow (search-based CRUD).
///
/// Since AdminCrudController depends on DatabaseHelper (SQLite),
/// we test the pure-logic pieces that don't require a DB connection:
/// - O(1) lookup caches
/// - Selective reload routing
/// - Search/filter algorithm (same logic as _BuscadorSheet._filtrar)
/// - Form validation logic (same logic as _FormularioSheet._guardar*)
/// - TablaConfig builders

void main() {
  // ===================================================================
  // 1. O(1) Lookup Cache Tests
  // ===================================================================
  group('AdminCrudController - Cache lookups O(1)', () {
    test('areaNombreCache: lookup returns correct nombre', () {
      final cache = _buildAreaCache([
        {'id': 'a1', 'nombre': 'Natales'},
        {'id': 'a2', 'nombre': 'Aysén'},
        {'id': 'a3', 'nombre': 'Chiloé'},
      ]);
      expect(cache['a1'], 'Natales');
      expect(cache['a2'], 'Aysén');
      expect(cache['a3'], 'Chiloé');
    });

    test('areaNombreCache: missing id returns null', () {
      final cache = _buildAreaCache([
        {'id': 'a1', 'nombre': 'Natales'},
      ]);
      expect(cache['nonexistent'], isNull);
    });

    test('areaNombreCache: empty list produces empty cache', () {
      final cache = _buildAreaCache([]);
      expect(cache, isEmpty);
    });

    test('contratistaNombreCache: lookup returns correct nombre', () {
      final cache = _buildContratistaCache([
        {'id': 'c1', 'nombre': 'Contratista A'},
        {'id': 'c2', 'nombre': 'Contratista B'},
      ]);
      expect(cache['c1'], 'Contratista A');
      expect(cache['c2'], 'Contratista B');
    });

    test('contratistaNombreCache: null nombre defaults to empty string', () {
      final cache = _buildContratistaCache([
        {'id': 'c1', 'nombre': null},
      ]);
      expect(cache['c1'], '');
    });

    test('cache rebuild replaces old data', () {
      var cache = _buildAreaCache([
        {'id': 'a1', 'nombre': 'Old Name'},
      ]);
      expect(cache['a1'], 'Old Name');

      cache = _buildAreaCache([
        {'id': 'a1', 'nombre': 'New Name'},
        {'id': 'a2', 'nombre': 'Added'},
      ]);
      expect(cache['a1'], 'New Name');
      expect(cache['a2'], 'Added');
    });
  });

  // ===================================================================
  // 2. Search/Filter Algorithm Tests
  // ===================================================================
  group('Buscador - filtro de items', () {
    final items = [
      {'id': '1', 'nombre': 'Centro Natales', 'area': 'Natales'},
      {'id': '2', 'nombre': 'Centro Aysén', 'area': 'Aysén'},
      {'id': '3', 'nombre': 'Puerto Williams', 'area': 'Natales'},
      {'id': '4', 'nombre': 'Chiloé Base', 'area': 'Chiloé'},
    ];

    List<Map<String, dynamic>> filtrar(
      List<Map<String, dynamic>> items,
      String query, {
      String Function(Map<String, dynamic>)? getNombre,
      String Function(Map<String, dynamic>)? getSubtitulo,
    }) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return items;
      return items.where((item) {
        final nombre = (getNombre?.call(item) ?? item['nombre'] as String)
            .toLowerCase();
        final sub = (getSubtitulo?.call(item) ?? '').toLowerCase();
        return nombre.contains(q) || sub.contains(q);
      }).toList();
    }

    test('query vacío retorna todos los items', () {
      final result = filtrar(items, '');
      expect(result.length, 4);
    });

    test('query con espacios vacíos retorna todos', () {
      final result = filtrar(items, '   ');
      expect(result.length, 4);
    });

    test('filtra por nombre (case insensitive)', () {
      final result = filtrar(items, 'natales');
      expect(result.length, 1);
      expect(result[0]['nombre'], 'Centro Natales');
    });

    test('filtra por subtítulo (area)', () {
      final result = filtrar(
        items,
        'natales',
        getSubtitulo: (item) => item['area'] as String,
      );
      expect(result.length, 2); // Centro Natales + Puerto Williams
    });

    test('filtra parcial (substring)', () {
      final result = filtrar(items, 'cent');
      expect(result.length, 2); // Centro Natales + Centro Aysén
    });

    test('sin resultados retorna lista vacía', () {
      final result = filtrar(items, 'zzzzz');
      expect(result, isEmpty);
    });

    test('case insensitive: mayúsculas y minúsculas mezcladas', () {
      final result = filtrar(items, 'CHILOÉ');
      expect(result.length, 1);
      expect(result[0]['nombre'], 'Chiloé Base');
    });

    test('filtra lista vacía sin error', () {
      final result = filtrar([], 'algo');
      expect(result, isEmpty);
    });
  });

  // ===================================================================
  // 3. Form Validation Logic Tests
  // ===================================================================
  group('Formulario - validación centros', () {
    test('nombre vacío es inválido', () {
      expect(_validarCentro('', 'Área 1', _sampleAreas()), 'Ingresa el nombre');
    });

    test('nombre con solo espacios es inválido', () {
      expect(
        _validarCentro('   ', 'Área 1', _sampleAreas()),
        'Ingresa el nombre',
      );
    });

    test('area null es inválido', () {
      expect(
        _validarCentro('Centro X', null, _sampleAreas()),
        'Selecciona un area',
      );
    });

    test('area no encontrada es inválido', () {
      expect(
        _validarCentro('Centro X', 'Area Fantasma', _sampleAreas()),
        'Area no encontrada',
      );
    });

    test('datos validos retorna null (ok)', () {
      expect(_validarCentro('Centro X', 'Natales', _sampleAreas()), isNull);
    });

    test('nombre se trimmea antes de validar', () {
      expect(_validarCentro('  Centro X  ', 'Natales', _sampleAreas()), isNull);
    });
  });

  group('Formulario - validación contratistas', () {
    test('nombre vacío es inválido', () {
      expect(_validarContratista(''), 'Ingresa el nombre');
    });

    test('nombre válido retorna null (ok)', () {
      expect(_validarContratista('Contratista X'), isNull);
    });
  });

  group('Formulario - validación embarcaciones', () {
    test('nombre vacío es inválido', () {
      expect(
        _validarEmbarcacion('', 'Contratista A', null, _sampleContratistas()),
        'Ingresa el nombre',
      );
    });

    test('contratista null es inválido', () {
      expect(
        _validarEmbarcacion('Barco X', null, null, _sampleContratistas()),
        'Selecciona un contratista',
      );
    });

    test('contratista no encontrado es inválido', () {
      expect(
        _validarEmbarcacion('Barco X', 'Fantasma', null, _sampleContratistas()),
        'Contratista no encontrado',
      );
    });

    test('datos válidos sin matrícula retorna null (ok)', () {
      expect(
        _validarEmbarcacion(
          'Barco X',
          'Contratista A',
          null,
          _sampleContratistas(),
        ),
        isNull,
      );
    });

    test('datos válidos con matrícula retorna null (ok)', () {
      expect(
        _validarEmbarcacion(
          'Barco X',
          'Contratista A',
          'MAT-123',
          _sampleContratistas(),
        ),
        isNull,
      );
    });

    test('matrícula vacía se trata como null (ok)', () {
      expect(
        _validarEmbarcacion(
          'Barco X',
          'Contratista A',
          '   ',
          _sampleContratistas(),
        ),
        isNull,
      );
    });
  });

  // ===================================================================
  // 4. TablaConfig Builder Logic Tests
  // ===================================================================
  group('TablaConfig - builders de subtítulos', () {
    test('centros: subtítulo muestra nombre del área', () {
      final areaCache = {'area-1': 'Natales', 'area-2': 'Aysén'};
      String getSubtitulo(Map<String, dynamic> item) =>
          areaCache[item['area_id'] as String? ?? ''] ?? 'Sin area';

      expect(getSubtitulo({'area_id': 'area-1'}), 'Natales');
      expect(getSubtitulo({'area_id': 'area-unknown'}), 'Sin area');
      expect(getSubtitulo({}), 'Sin area');
    });

    test('embarcaciones: subtítulo contratista + matrícula', () {
      final contratistaCache = {'c1': 'ACME Corp', 'c2': 'Beta SA'};
      String getSubtitulo(Map<String, dynamic> item) {
        final contratista =
            contratistaCache[item['contratista_id'] as String? ?? ''] ??
            'Sin contratista';
        final mat = item['matricula'] as String?;
        return mat != null && mat.isNotEmpty
            ? '$contratista  |  $mat'
            : contratista;
      }

      expect(
        getSubtitulo({'contratista_id': 'c1', 'matricula': 'MAT-001'}),
        'ACME Corp  |  MAT-001',
      );
      expect(getSubtitulo({'contratista_id': 'c1'}), 'ACME Corp');
      expect(
        getSubtitulo({'contratista_id': 'c1', 'matricula': ''}),
        'ACME Corp',
      );
      expect(getSubtitulo({}), 'Sin contratista');
    });

    test('contratistas: sin subtítulo (getSubtitulo es null)', () {
      // Contratistas don't have a subtitle function
      const String? Function(Map<String, dynamic>)? getSubtitulo = null;
      expect(getSubtitulo, isNull);
    });
  });

  // ===================================================================
  // 5. Edit Pre-population Tests
  // ===================================================================
  group('Formulario - pre-población al editar', () {
    test('editar centro: precarga nombre y área', () {
      final areaCache = {'area-1': 'Natales'};
      final item = {
        'id': 'centro-1',
        'nombre': 'Centro Norte',
        'area_id': 'area-1',
      };

      final nombre = item['nombre'];
      final areaSeleccionada = areaCache[item['area_id'] ?? ''];

      expect(nombre, 'Centro Norte');
      expect(areaSeleccionada, 'Natales');
    });

    test('editar contratista: precarga solo nombre', () {
      final item = {'id': 'con-1', 'nombre': 'ACME Corp'};
      expect(item['nombre'], 'ACME Corp');
    });

    test('editar embarcación: precarga nombre, contratista y matrícula', () {
      final contratistaCache = {'c1': 'ACME Corp'};
      final item = {
        'id': 'emb-1',
        'nombre': 'Barco Azul',
        'contratista_id': 'c1',
        'matricula': 'MAT-999',
      };

      final nombre = item['nombre'];
      final contratistaSeleccionado =
          contratistaCache[item['contratista_id'] ?? ''];
      final matricula = item['matricula'];

      expect(nombre, 'Barco Azul');
      expect(contratistaSeleccionado, 'ACME Corp');
      expect(matricula, 'MAT-999');
    });

    test('editar embarcación sin matrícula: matrícula queda vacía', () {
      final item = {
        'id': 'emb-2',
        'nombre': 'Barco Rojo',
        'contratista_id': 'c1',
      };
      final matricula = item['matricula'] ?? '';
      expect(matricula, '');
    });

    test('editar embarcación: se puede cambiar contratista', () {
      final contratistaCache = {'c1': 'ACME Corp', 'c2': 'Beta SA'};
      // Starts with c1
      var seleccionado = contratistaCache['c1'];
      expect(seleccionado, 'ACME Corp');

      // User changes to c2 via dropdown
      seleccionado = 'Beta SA';
      expect(seleccionado, 'Beta SA');

      // Find the new contratista ID
      final contratistas = [
        {'id': 'c1', 'nombre': 'ACME Corp'},
        {'id': 'c2', 'nombre': 'Beta SA'},
      ];
      final match = contratistas.firstWhere(
        (c) => c['nombre'] == seleccionado,
        orElse: () => {},
      );
      expect(match['id'], 'c2');
    });

    test('editar centro: se puede cambiar el área', () {
      final areas = [
        {'id': 'a1', 'nombre': 'Natales'},
        {'id': 'a2', 'nombre': 'Aysén'},
      ];
      // Starts with Natales
      var areaSeleccionada = 'Natales';
      expect(areaSeleccionada, 'Natales');

      // User changes to Aysén
      areaSeleccionada = 'Aysén';
      final match = areas.firstWhere(
        (a) => a['nombre'] == areaSeleccionada,
        orElse: () => {},
      );
      expect(match['id'], 'a2');
    });
  });

  // ===================================================================
  // 6. Duplicate Detection (Autocomplete Suggestions) Tests
  // ===================================================================
  group('Autocomplete - detección de duplicados', () {
    final suggestions = [
      'Centro Natales',
      'Centro Aysén',
      'Puerto Williams',
      'Chiloé Base',
    ];

    List<String> filterSuggestions(String text) {
      final q = text.trim().toLowerCase();
      if (q.isEmpty) return [];
      return suggestions.where((s) => s.toLowerCase().contains(q)).toList();
    }

    test('texto vacío no muestra sugerencias', () {
      expect(filterSuggestions(''), isEmpty);
    });

    test('match parcial muestra coincidencias', () {
      final result = filterSuggestions('cent');
      expect(result, ['Centro Natales', 'Centro Aysén']);
    });

    test('match exacto muestra el item (advertencia duplicado)', () {
      final result = filterSuggestions('Centro Natales');
      expect(result, ['Centro Natales']);
    });

    test('sin match no muestra nada', () {
      final result = filterSuggestions('xyz');
      expect(result, isEmpty);
    });

    test('case insensitive', () {
      final result = filterSuggestions('PUERTO');
      expect(result, ['Puerto Williams']);
    });
  });

  // ===================================================================
  // 7. Selective Reload Routing Tests
  // ===================================================================
  group('AdminCrudController - reload selectivo', () {
    test('crearCentro solo recarga centros', () {
      final log = <String>[];
      _simulateReload('centros', log);
      expect(log, ['centros']);
      expect(log, isNot(contains('contratistas')));
      expect(log, isNot(contains('embarcaciones')));
    });

    test('crearContratista recarga contratistas + cache', () {
      final log = <String>[];
      _simulateReload('contratistas', log);
      expect(log, ['contratistas', 'contratista_cache']);
    });

    test('crearEmbarcacion solo recarga embarcaciones', () {
      final log = <String>[];
      _simulateReload('embarcaciones', log);
      expect(log, ['embarcaciones']);
    });

    test('areas recarga áreas + cache', () {
      final log = <String>[];
      _simulateReload('areas', log);
      expect(log, ['areas', 'area_cache']);
    });
  });

  // ===================================================================
  // 8. Pending Badge Logic Tests
  // ===================================================================
  group('Badge pendiente (subido)', () {
    test('subido=0 muestra badge pendiente', () {
      final item = {'id': '1', 'nombre': 'Test', 'subido': 0};
      final pendiente = (item['subido'] as int? ?? 1) == 0;
      expect(pendiente, isTrue);
    });

    test('subido=1 no muestra badge', () {
      final item = {'id': '1', 'nombre': 'Test', 'subido': 1};
      final pendiente = (item['subido'] as int? ?? 1) == 0;
      expect(pendiente, isFalse);
    });

    test('subido null (legacy data) no muestra badge', () {
      final item = {'id': '1', 'nombre': 'Test'};
      final pendiente = (item['subido'] as int? ?? 1) == 0;
      expect(pendiente, isFalse);
    });
  });

  // ===================================================================
  // 9. Titulo Singular Helper Tests
  // ===================================================================
  group('tituloSingular helper', () {
    String tituloSingular(String tabla) {
      switch (tabla) {
        case 'centros':
          return 'Centro';
        case 'contratistas':
          return 'Contratista';
        case 'embarcaciones':
          return 'Embarcacion';
        default:
          return '';
      }
    }

    test('centros -> Centro', () {
      expect(tituloSingular('centros'), 'Centro');
    });

    test('contratistas -> Contratista', () {
      expect(tituloSingular('contratistas'), 'Contratista');
    });

    test('embarcaciones -> Embarcacion', () {
      expect(tituloSingular('embarcaciones'), 'Embarcacion');
    });

    test('tabla desconocida -> vacío', () {
      expect(tituloSingular('unknown'), '');
    });
  });
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Simulates the O(1) cache building from AdminCrudController._rebuildCaches
Map<String, String> _buildAreaCache(List<Map<String, dynamic>> areas) {
  return {for (var a in areas) a['id'] as String: a['nombre'] as String? ?? ''};
}

Map<String, String> _buildContratistaCache(
  List<Map<String, dynamic>> contratistas,
) {
  return {
    for (var c in contratistas) c['id'] as String: c['nombre'] as String? ?? '',
  };
}

/// Simulates validation logic from _FormularioSheet._guardarCentro
String? _validarCentro(
  String nombre,
  String? areaSeleccionada,
  List<Map<String, dynamic>> areas,
) {
  if (nombre.trim().isEmpty) return 'Ingresa el nombre';
  if (areaSeleccionada == null) return 'Selecciona un area';
  final area = areas.firstWhere(
    (a) => a['nombre'] == areaSeleccionada,
    orElse: () => <String, dynamic>{},
  );
  if (area.isEmpty) return 'Area no encontrada';
  return null;
}

String? _validarContratista(String nombre) {
  if (nombre.trim().isEmpty) return 'Ingresa el nombre';
  return null;
}

String? _validarEmbarcacion(
  String nombre,
  String? contratistaSeleccionado,
  String? matricula,
  List<Map<String, dynamic>> contratistas,
) {
  if (nombre.trim().isEmpty) return 'Ingresa el nombre';
  if (contratistaSeleccionado == null) return 'Selecciona un contratista';
  final contratista = contratistas.firstWhere(
    (c) => c['nombre'] == contratistaSeleccionado,
    orElse: () => <String, dynamic>{},
  );
  if (contratista.isEmpty) return 'Contratista no encontrado';
  return null;
}

List<Map<String, dynamic>> _sampleAreas() => [
  {'id': 'a1', 'nombre': 'Natales'},
  {'id': 'a2', 'nombre': 'Aysén'},
];

List<Map<String, dynamic>> _sampleContratistas() => [
  {'id': 'c1', 'nombre': 'Contratista A'},
  {'id': 'c2', 'nombre': 'Contratista B'},
];

/// Simulates the selective reload routing from AdminCrudController._recargarTabla
void _simulateReload(String tabla, List<String> log) {
  switch (tabla) {
    case 'centros':
      log.add('centros');
      break;
    case 'contratistas':
      log.add('contratistas');
      log.add('contratista_cache');
      break;
    case 'embarcaciones':
      log.add('embarcaciones');
      break;
    case 'areas':
      log.add('areas');
      log.add('area_cache');
      break;
  }
}
