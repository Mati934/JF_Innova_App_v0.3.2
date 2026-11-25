import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/checklist_navigation_tree.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/models/configurable_checklist.dart';

ConfigurableChecklist _checklist(String key) => ConfigurableChecklist(
  key: key,
  formTypeKey: 'generic_standard_form',
  permissionKey: 'checklist.$key',
  reportPrefix: key.substring(0, 3).toUpperCase(),
  nombre: key,
  publishedVersion: 1,
);

ChecklistNavigationNode _node({
  required String key,
  String? parent,
  required String type,
  String? checklistKey,
  int orden = 0,
}) => ChecklistNavigationNode(
  key: key,
  empresaId: 'empresa-1',
  parentNodeKey: parent,
  nodeType: type,
  checklistKey: checklistKey,
  permissionKey: 'checklist.ver',
  titulo: key,
  orden: orden,
);

void main() {
  group('buildChecklistMenu', () {
    test('flat top-level checklist becomes a single entry', () {
      final nodes = [
        _node(key: 'nod_a', type: 'CHECKLIST', checklistKey: 'esmeril'),
      ];
      final byKey = {'esmeril': _checklist('esmeril')};

      final menu = buildChecklistMenu(nodes, byKey);

      expect(menu, hasLength(1));
      expect(menu.single.isGroup, false);
      expect(menu.single.checklist?.key, 'esmeril');
    });

    test('group node resolves its children sorted by orden', () {
      final nodes = [
        _node(key: 'grp_herramientas', type: 'GROUP'),
        _node(
          key: 'nod_soldadora',
          parent: 'grp_herramientas',
          type: 'CHECKLIST',
          checklistKey: 'soldadora',
          orden: 2,
        ),
        _node(
          key: 'nod_esmeril',
          parent: 'grp_herramientas',
          type: 'CHECKLIST',
          checklistKey: 'esmeril',
          orden: 1,
        ),
      ];
      final byKey = {
        'soldadora': _checklist('soldadora'),
        'esmeril': _checklist('esmeril'),
      };

      final menu = buildChecklistMenu(nodes, byKey);

      expect(menu, hasLength(1));
      expect(menu.single.isGroup, true);
      expect(menu.single.children.map((c) => c.key).toList(), [
        'esmeril',
        'soldadora',
      ]);
    });

    test('group without resolvable children is omitted', () {
      final nodes = [
        _node(key: 'grp_vacio', type: 'GROUP'),
        _node(
          key: 'nod_huerfano',
          parent: 'grp_vacio',
          type: 'CHECKLIST',
          checklistKey: 'no_existe',
        ),
      ];

      final menu = buildChecklistMenu(nodes, const {});

      expect(menu, isEmpty);
    });

    test('checklist child without a matching catalog entry is skipped', () {
      final nodes = [
        _node(key: 'grp', type: 'GROUP'),
        _node(
          key: 'nod_ok',
          parent: 'grp',
          type: 'CHECKLIST',
          checklistKey: 'valido',
          orden: 1,
        ),
        _node(
          key: 'nod_missing',
          parent: 'grp',
          type: 'CHECKLIST',
          checklistKey: 'faltante',
          orden: 2,
        ),
      ];
      final byKey = {'valido': _checklist('valido')};

      final menu = buildChecklistMenu(nodes, byKey);

      expect(menu.single.children.map((c) => c.key).toList(), ['valido']);
    });
  });
}
