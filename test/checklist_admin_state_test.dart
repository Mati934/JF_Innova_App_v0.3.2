import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/checklist_admin_state.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/models/configurable_checklist.dart';

ChecklistNavigationNode _grupo({bool habilitado = true}) =>
    ChecklistNavigationNode(
      key: 'grp_x',
      empresaId: 'e1',
      nodeType: 'GROUP',
      permissionKey: 'checklist.grupo',
      titulo: 'Herramientas y Equipos',
      icono: 'build_circle',
      orden: 50,
      habilitado: habilitado,
    );

ChecklistNavigationNode _hijo(
  String checklistKey, {
  bool habilitado = true,
  int orden = 1,
}) => ChecklistNavigationNode(
  key: 'nod_${checklistKey}_x',
  empresaId: 'e1',
  parentNodeKey: 'grp_x',
  nodeType: 'CHECKLIST',
  checklistKey: checklistKey,
  permissionKey: 'checklist.$checklistKey',
  titulo: checklistKey,
  orden: orden,
  habilitado: habilitado,
);

ChecklistNavigationNode _suelto(
  String checklistKey, {
  bool habilitado = false,
  int orden = 51,
}) => ChecklistNavigationNode(
  key: 'nod_flat_${checklistKey}_x',
  empresaId: 'e1',
  nodeType: 'CHECKLIST',
  checklistKey: checklistKey,
  permissionKey: 'checklist.$checklistKey',
  titulo: checklistKey,
  orden: orden,
  habilitado: habilitado,
);

void main() {
  group('buildChecklistAdminFamilies', () {
    test('fusiona el nodo agrupado y su gemelo suelto en un solo item', () {
      final familias = buildChecklistAdminFamilies([
        _grupo(),
        _hijo('chq_a'),
        _hijo('chq_b', orden: 2),
        _suelto('chq_a'),
        _suelto('chq_b', orden: 52),
      ]);

      expect(familias, hasLength(1));
      expect(familias.first.items, hasLength(2));
      expect(familias.first.soportaAgrupacion, isTrue);
      expect(familias.first.items.every((i) => i.soportaAgrupacion), isTrue);
    });

    test('los sueltos sin grupo quedan en una carpeta aparte', () {
      final familias = buildChecklistAdminFamilies([
        _grupo(),
        _hijo('chq_a'),
        _suelto('chq_a'),
        _suelto('chq_huerfano', orden: 60),
      ]);

      expect(familias, hasLength(2));
      final sueltos = familias.last;
      expect(sueltos.groupNode, isNull);
      expect(sueltos.soportaAgrupacion, isFalse);
      expect(sueltos.items.single.checklistKey, 'chq_huerfano');
    });

    test('un grupo sin gemelos sueltos no ofrece alternar agrupacion', () {
      final familias = buildChecklistAdminFamilies([_grupo(), _hijo('chq_a')]);
      expect(familias.single.soportaAgrupacion, isFalse);
    });
  });

  group('ChecklistAdminFamilyState.fromFamily', () {
    test('lee el estado real de la BD (agrupado y activo)', () {
      final familia = buildChecklistAdminFamilies([
        _grupo(),
        _hijo('chq_a'),
        _hijo('chq_b', habilitado: false, orden: 2),
        _suelto('chq_a'),
        _suelto('chq_b', orden: 52),
      ]).single;

      final estado = ChecklistAdminFamilyState.fromFamily(familia);
      expect(estado.moduloActivo, isTrue);
      expect(estado.agrupado, isTrue);
      expect(estado.checklistsActivos['chq_a'], isTrue);
      expect(estado.checklistsActivos['chq_b'], isFalse);
    });

    test('detecta modo suelto: grupo apagado y flats encendidos', () {
      final familia = buildChecklistAdminFamilies([
        _grupo(habilitado: false),
        _hijo('chq_a', habilitado: false),
        _suelto('chq_a', habilitado: true),
      ]).single;

      final estado = ChecklistAdminFamilyState.fromFamily(familia);
      expect(estado.moduloActivo, isTrue);
      expect(estado.agrupado, isFalse);
      expect(estado.checklistsActivos['chq_a'], isTrue);
    });

    test('todo apagado => modulo inactivo', () {
      final familia = buildChecklistAdminFamilies([
        _grupo(habilitado: false),
        _hijo('chq_a', habilitado: false),
        _suelto('chq_a'),
      ]).single;

      expect(ChecklistAdminFamilyState.fromFamily(familia).moduloActivo, false);
    });
  });

  group('resolveChecklistNodeStates', () {
    final familia = buildChecklistAdminFamilies([
      _grupo(),
      _hijo('chq_a'),
      _hijo('chq_b', orden: 2),
      _suelto('chq_a'),
      _suelto('chq_b', orden: 52),
    ]).single;

    test('agrupado: grupo e hijos activos, sueltos apagados', () {
      final estados = resolveChecklistNodeStates(
        familia,
        const ChecklistAdminFamilyState(
          moduloActivo: true,
          agrupado: true,
          checklistsActivos: {'chq_a': true, 'chq_b': false},
        ),
      );

      expect(estados['grp_x'], isTrue);
      expect(estados['nod_chq_a_x'], isTrue);
      expect(estados['nod_chq_b_x'], isFalse);
      expect(estados['nod_flat_chq_a_x'], isFalse);
      expect(estados['nod_flat_chq_b_x'], isFalse);
    });

    test('sin agrupar: grupo e hijos apagados, sueltos activos', () {
      final estados = resolveChecklistNodeStates(
        familia,
        const ChecklistAdminFamilyState(
          moduloActivo: true,
          agrupado: false,
          checklistsActivos: {'chq_a': true, 'chq_b': true},
        ),
      );

      expect(estados['grp_x'], isFalse);
      expect(estados['nod_chq_a_x'], isFalse);
      expect(estados['nod_chq_b_x'], isFalse);
      expect(estados['nod_flat_chq_a_x'], isTrue);
      expect(estados['nod_flat_chq_b_x'], isTrue);
    });

    test(
      'modulo apagado deja TODO en false, aunque haya checklists activos',
      () {
        final estados = resolveChecklistNodeStates(
          familia,
          const ChecklistAdminFamilyState(
            moduloActivo: false,
            agrupado: true,
            checklistsActivos: {'chq_a': true, 'chq_b': true},
          ),
        );

        expect(estados.values.any((v) => v), isFalse);
      },
    );

    test('nunca deja el checklist duplicado (agrupado + suelto a la vez)', () {
      for (final agrupado in [true, false]) {
        final estados = resolveChecklistNodeStates(
          familia,
          ChecklistAdminFamilyState(
            moduloActivo: true,
            agrupado: agrupado,
            checklistsActivos: const {'chq_a': true, 'chq_b': true},
          ),
        );
        for (final key in ['chq_a', 'chq_b']) {
          final dobles =
              (estados['nod_${key}_x'] == true ? 1 : 0) +
              (estados['nod_flat_${key}_x'] == true ? 1 : 0);
          expect(dobles, 1, reason: 'agrupado=$agrupado, $key');
        }
      }
    });

    test('carpeta sin grupo: el suelto responde solo a activar/desactivar', () {
      final sinGrupo = buildChecklistAdminFamilies([
        _suelto('chq_solo', habilitado: true),
      ]).single;

      expect(
        resolveChecklistNodeStates(
          sinGrupo,
          const ChecklistAdminFamilyState(
            moduloActivo: true,
            agrupado: true,
            checklistsActivos: {'chq_solo': true},
          ),
        )['nod_flat_chq_solo_x'],
        isTrue,
      );
      expect(
        resolveChecklistNodeStates(
          sinGrupo,
          const ChecklistAdminFamilyState(
            moduloActivo: false,
            agrupado: false,
            checklistsActivos: {'chq_solo': true},
          ),
        )['nod_flat_chq_solo_x'],
        isFalse,
      );
    });
  });
}
