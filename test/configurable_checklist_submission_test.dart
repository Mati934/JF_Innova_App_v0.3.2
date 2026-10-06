import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/checklist_submission.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/models/configurable_checklist.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_data.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_mapper.dart';

void main() {
  group('Required checklist fields', () {
    const fields = [
      ChecklistCampoDefinicion(
        id: 'equipment',
        clave: 'equipo_identificacion',
        etiqueta: 'Equipo',
        tipo: 'texto',
        requerido: true,
      ),
      ChecklistCampoDefinicion(
        id: 'operator',
        clave: 'operador_equipo',
        etiqueta: 'Operador',
        tipo: 'texto',
        requerido: true,
      ),
      ChecklistCampoDefinicion(
        id: 'region',
        clave: 'region',
        etiqueta: 'Región',
        tipo: 'texto',
      ),
    ];

    test('reports absent and whitespace-only required values', () {
      expect(
        missingRequiredChecklistFields(fields, {'operador_equipo': '  '}),
        ['Equipo', 'Operador'],
      );
    });

    test('accepts required values without requiring optional fields', () {
      expect(
        missingRequiredChecklistFields(fields, {
          'equipo_identificacion': 'TP-01',
          'operador_equipo': 'Operador de turno',
        }),
        isEmpty,
      );
    });
  });

  group('Configurable checklist submission', () {
    const items = [
      {'id': 'power_cable', 'pregunta': 'Cable de poder'},
      {'id': 'guard', 'pregunta': 'Proteccion instalada'},
    ];

    test('blocks finalization when an item has no response', () {
      final missing = missingChecklistResponses(items, {
        'power_cable': 'C',
        'guard': null,
      });

      expect(missing, ['guard']);
    });

    test('allows finalization when every item has a supported response', () {
      final missing = missingChecklistResponses(items, {
        'power_cable': 'C',
        'guard': 'NC',
      });

      expect(missing, isEmpty);
    });

    test('maps a configurable checklist draft with its remote title', () {
      final draft = DraftCardMapper.fromConfigurableChecklist({
        'id': 'draft-1',
        'checklist_key': 'esmeril_angular',
        'checklist_nombre': 'Esmeril angular',
        'fecha_realizacion': '2026-09-13T10:00:00.000',
      });

      expect(draft.kind, DraftKind.checklistConfigurable);
      expect(draft.title, 'Esmeril angular');
    });
  });
}
