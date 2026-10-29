import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/checklist_evidence_sync.dart';

void main() {
  const evidence = {
    'id': 'photo-1',
    'inspeccion_id': 'inspection-1',
    'respuesta_id': 'question-1',
    'tipo': 'RESPUESTA',
    'orden': 0,
    'metadata': '{}',
    'local_path': 'local-file.jpg',
    'subido': 0,
  };

  test('maps local item key to the persisted response UUID', () {
    final payload = buildChecklistEvidencePayload(
      evidence: evidence,
      responseIdsByItemKey: {'question-1': 'response-uuid'},
      storagePath: 'checklists/inspection-1/photo-1.jpg',
    );
    expect(payload['respuesta_id'], 'response-uuid');
    expect(payload['metadata'], isEmpty);
    expect(payload, isNot(contains('local_path')));
    expect(payload, isNot(contains('subido')));
  });

  test('general photos have no linked response', () {
    final payload = buildChecklistEvidencePayload(
      evidence: {...evidence, 'tipo': 'GENERAL', 'respuesta_id': null},
      responseIdsByItemKey: const {},
      storagePath: 'general.jpg',
    );
    expect(payload['respuesta_id'], isNull);
  });

  test(
    'orphan response photos fail rather than silently losing their link',
    () {
      expect(
        () => buildChecklistEvidencePayload(
          evidence: evidence,
          responseIdsByItemKey: const {},
          storagePath: 'photo.jpg',
        ),
        throwsStateError,
      );
    },
  );

  test('invalid evidence types fail explicitly', () {
    expect(
      () => buildChecklistEvidencePayload(
        evidence: {...evidence, 'tipo': 'UNKNOWN'},
        responseIdsByItemKey: const {},
        storagePath: 'photo.jpg',
      ),
      throwsStateError,
    );
  });
}
