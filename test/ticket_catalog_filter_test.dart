import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/tickets/domain/ticket_catalog_filter.dart';

void main() {
  group('extractDistinctIds', () {
    test('ignores null values and removes duplicates', () {
      final rows = [
        {'area_id': 'a1'},
        {'area_id': 'a2'},
        {'area_id': 'a1'},
        {'area_id': null},
      ];

      final ids = extractDistinctIds(rows, 'area_id');

      expect(ids, {'a1', 'a2'});
    });

    test('returns empty set when there are no rows', () {
      expect(extractDistinctIds(const [], 'area_id'), isEmpty);
    });
  });

  group('filterCatalogByUsedIds', () {
    test('keeps only catalog rows referenced by at least one ticket', () {
      final catalogo = [
        {'id': 'c1', 'nombre': 'Centro Uno'},
        {'id': 'c2', 'nombre': 'Centro Dos'},
        {'id': 'c3', 'nombre': 'Centro Tres (sin tickets)'},
      ];

      final resultado = filterCatalogByUsedIds(catalogo, {'c1', 'c2'});

      expect(resultado.map((r) => r['id']), ['c1', 'c2']);
    });

    test('returns an empty list when nothing is used', () {
      final catalogo = [
        {'id': 'c1', 'nombre': 'Centro Uno'},
      ];

      expect(filterCatalogByUsedIds(catalogo, {}), isEmpty);
    });
  });
}
