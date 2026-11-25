import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/checklist_catalog_seed.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/checklist_navigation_tree.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/models/configurable_checklist.dart';
import 'package:jf_innova_app/features/configurable_checklists/presentation/checklist_icons.dart';
import 'package:jf_innova_app/features/configurable_checklists/presentation/screens/generic_checklist_form_screen.dart';

void main() {
  test('critical equipment icons resolve to distinct Material icons', () {
    expect(checklistIconFromName('factory'), Icons.factory);
    expect(checklistIconFromName('emergency'), Icons.emergency);
    expect(checklistIconFromName('pallet'), Icons.pallet);
    expect(
      checklistIconFromName('precision_manufacturing'),
      Icons.precision_manufacturing,
    );
  });

  test('three entries share the generic form with distinct checklist keys', () {
    final checklists = {
      for (final key in equiposCriticosChecklistKeys)
        key: ConfigurableChecklist(
          key: key,
          formTypeKey: 'generic_standard_form',
          permissionKey: 'checklist.$key',
          reportPrefix: key,
          nombre: key,
          publishedVersion: 1,
        ),
    };
    final nodes = [
      const ChecklistNavigationNode(
        key: 'grp_mb',
        empresaId: 'mb',
        nodeType: 'GROUP',
        permissionKey: 'checklist.grupo_equipos_criticos',
        titulo: 'Equipos Críticos',
        icono: 'factory',
        orden: 60,
        habilitado: true,
      ),
      for (var i = 0; i < equiposCriticosChecklistKeys.length; i++)
        ChecklistNavigationNode(
          key: 'node_$i',
          empresaId: 'mb',
          parentNodeKey: 'grp_mb',
          nodeType: 'CHECKLIST',
          checklistKey: equiposCriticosChecklistKeys[i],
          permissionKey: 'checklist.${equiposCriticosChecklistKeys[i]}',
          titulo: equiposCriticosChecklistKeys[i],
          orden: i + 1,
          habilitado: true,
        ),
    ];

    final menu = buildChecklistMenu(nodes, checklists);
    expect(menu, hasLength(1));
    expect(menu.single.isGroup, true);
    expect(menu.single.children, hasLength(3));
    final forms = menu.single.children
        .map((checklist) => GenericChecklistFormScreen(checklist: checklist))
        .toList();
    expect(
      forms.map((form) => form.checklist.key),
      orderedEquals(equiposCriticosChecklistKeys),
    );
  });

  test('SQL seed contains exactly 7, 4 and 7 stable question definitions', () {
    final sql = File(
      'supabase_seed_checklists_equipos_criticos_mb_v1.sql',
    ).readAsStringSync();
    final questions = RegExp(
      r"\('(?<key>chq_[a-z_]+)', (?<order>\d+), '[^']+', '¿",
    ).allMatches(sql).toList();
    expect(questions, hasLength(18));
    final counts = {
      for (final key in equiposCriticosChecklistKeys)
        key: questions.where((match) => match.namedGroup('key') == key).length,
    };
    expect(counts.values, orderedEquals([7, 4, 7]));
    for (final key in equiposCriticosChecklistKeys) {
      expect(
        questions
            .where((match) => match.namedGroup('key') == key)
            .map((match) => int.parse(match.namedGroup('order')!)),
        orderedEquals(List.generate(counts[key]!, (index) => index + 1)),
      );
    }
    expect(sql, contains("'HISTORY', TRUE"));
    expect(sql, contains("lower(trim(nombre)) = 'mb embajadores'"));
    expect(sql, contains('ON CONFLICT (checklist_key, version) DO NOTHING'));
  });
}
