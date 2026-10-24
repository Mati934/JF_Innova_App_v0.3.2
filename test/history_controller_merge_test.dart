import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/history/controllers/history_controller.dart';

void main() {
  group('HistoryController.filter matching', () {
    test('aplica filtros de area, contratista y tipo de inspeccion', () {
      final row = {
        'tipo_registro': 'INSPECCION_BUCEO',
        'area_id': 'area-1',
        'contratista_id': 'ct-2',
      };

      final filters = {
        'area_id': 'area-1',
        'contratista_id': 'ct-2',
        'tipo_inspeccion': 'INSPECCION_BUCEO',
      };

      expect(HistoryController.matchesHistoryFilters(row, filters), isTrue);
      expect(
        HistoryController.matchesHistoryFilters({
          ...row,
          'area_id': 'area-9',
        }, filters),
        isFalse,
      );
    });
  });

  group('HistoryController.mergeCloudAndLocalRecords', () {
    test('prioriza registro de nube cuando ID se repite', () {
      final cloud = [
        {
          'id': 'a1',
          'fecha_realizacion': '2026-08-03T10:00:00.000Z',
          'numero_reporte': '1234',
          'pdf_url': 'https://cloud/a1.pdf',
        },
      ];

      final local = [
        {
          'id': 'a1',
          'fecha_realizacion': '2026-08-03T09:00:00.000Z',
          'numero_reporte': 'LOCAL-1234',
          'pdf_url': null,
        },
      ];

      final merged = HistoryController.mergeCloudAndLocalRecords(cloud, local);

      expect(merged.length, 1);
      expect(merged.first['id'], 'a1');
      expect(merged.first['numero_reporte'], '1234');
      expect(merged.first['pdf_url'], 'https://cloud/a1.pdf');
    });

    test('incluye registros locales faltantes en nube', () {
      final cloud = [
        {'id': 'a1', 'fecha_realizacion': '2026-08-03T10:00:00.000Z'},
      ];

      final local = [
        {
          'id': 'a2',
          'fecha_realizacion': '2026-08-03T11:00:00.000Z',
          'numero_reporte': 'PEND-2',
        },
      ];

      final merged = HistoryController.mergeCloudAndLocalRecords(cloud, local);

      expect(merged.length, 2);
      expect(merged.map((r) => r['id']).toSet(), {'a1', 'a2'});
    });

    test('ordena por fecha descendente', () {
      final cloud = [
        {'id': 'a1', 'fecha_realizacion': '2026-08-03T08:00:00.000Z'},
      ];

      final local = [
        {'id': 'a2', 'fecha_realizacion': '2026-08-03T12:00:00.000Z'},
      ];

      final merged = HistoryController.mergeCloudAndLocalRecords(cloud, local);

      expect(merged.first['id'], 'a2');
      expect(merged.last['id'], 'a1');
    });
  });
}
