import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/ast/services/ast_evidence_sync_plan.dart';

void main() {
  test('crea claves remotas deterministas para evidencias AST', () {
    final plan = buildAstEvidenceSyncPlan(
      informeId: 'informe-1',
      fotosGeneralesJson: jsonEncode([
        r'C:\app\ast_img\primera.jpg',
        r'C:\app\ast_img\segunda.jpeg',
      ]),
      hallazgos: [
        {'id': 'hallazgo-1', 'foto_path': r'C:\app\ast_img\hallazgo.png'},
      ],
    );

    expect(plan.map((e) => e.storagePath), [
      'ast/informe-1/general_1.jpg',
      'ast/informe-1/general_2.jpeg',
      'ast/informe-1/hallazgo_hallazgo-1.png',
    ]);
    expect(plan.map((e) => e.tipo), ['general', 'general', 'hallazgo']);
    expect(plan.last.hallazgoId, 'hallazgo-1');
  });

  test('ignora JSON inválido y hallazgos sin fotografía', () {
    final plan = buildAstEvidenceSyncPlan(
      informeId: 'informe-2',
      fotosGeneralesJson: 'no-json',
      hallazgos: [
        {'id': 'hallazgo-2', 'foto_path': null},
      ],
    );

    expect(plan, isEmpty);
  });
}
