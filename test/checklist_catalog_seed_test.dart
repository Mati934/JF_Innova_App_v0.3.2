import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/configurable_checklists/domain/checklist_catalog_seed.dart';

void main() {
  group('resolveEmpresaUserIds', () {
    test('includes bridge users when no legacy user has empresa_id', () {
      final ids = resolveEmpresaUserIds(
        empresaId: 'empresa-mys',
        legacyUsers: const [],
        empresaLinks: const [
          {'usuario_id': 'supervisor-mys', 'empresa_id': 'empresa-mys'},
          {'usuario_id': 'dueno-mys', 'empresa_id': 'empresa-mys'},
        ],
      );

      expect(ids, ['dueno-mys', 'supervisor-mys']);
    });

    test('merges legacy and bridge users without duplicates', () {
      final ids = resolveEmpresaUserIds(
        empresaId: 'empresa-1',
        legacyUsers: const [
          {'id': 'legacy-user', 'empresa_id': 'empresa-1'},
          {'id': 'shared-user', 'empresa_id': 'empresa-1'},
          {'id': 'other-user', 'empresa_id': 'empresa-2'},
        ],
        empresaLinks: const [
          {'usuario_id': 'shared-user', 'empresa_id': 'empresa-1'},
          {'usuario_id': 'bridge-user', 'empresa_id': 'empresa-1'},
          {'usuario_id': 'other-link', 'empresa_id': 'empresa-2'},
        ],
      );

      expect(ids, ['bridge-user', 'legacy-user', 'shared-user']);
    });
  });

  group('buildHerramientasNavigationRows', () {
    test('creates 1 group + 5 grouped children + 5 flat nodes', () {
      final rows = buildHerramientasNavigationRows(
        '11112222-aaaa-bbbb-cccc-333344445555',
      );

      expect(rows, hasLength(11));
      expect(rows.where((r) => r['node_type'] == 'GROUP'), hasLength(1));
      expect(
        rows.where(
          (r) => r['node_type'] == 'CHECKLIST' && r['parent_node_key'] != null,
        ),
        hasLength(5),
      );
      expect(
        rows.where(
          (r) => r['node_type'] == 'CHECKLIST' && r['parent_node_key'] == null,
        ),
        hasLength(5),
      );
    });

    test('derives distinct node_key per empresa from its id', () {
      final rowsA = buildHerramientasNavigationRows(
        '11112222-0000-0000-0000-000000000000',
      );
      final rowsB = buildHerramientasNavigationRows(
        '99998888-0000-0000-0000-000000000000',
      );

      final groupKeyA = rowsA.firstWhere(
        (r) => r['node_type'] == 'GROUP',
      )['node_key'];
      final groupKeyB = rowsB.firstWhere(
        (r) => r['node_type'] == 'GROUP',
      )['node_key'];

      expect(groupKeyA, isNot(equals(groupKeyB)));
    });

    test('grouped children start enabled and flat nodes start disabled', () {
      final rows = buildHerramientasNavigationRows(
        'abcdefab-0000-0000-0000-000000000000',
      );

      final grouped = rows.where(
        (r) => r['node_type'] == 'CHECKLIST' && r['parent_node_key'] != null,
      );
      final flat = rows.where(
        (r) => r['node_type'] == 'CHECKLIST' && r['parent_node_key'] == null,
      );

      expect(grouped.every((r) => r['habilitado'] == true), true);
      expect(flat.every((r) => r['habilitado'] == false), true);
    });
  });

  group('buildHerramientasPermissionGrantRows', () {
    test('grants the 4 capacidades for each usuario and each checklist', () {
      final rows = buildHerramientasPermissionGrantRows(
        empresaId: 'empresa-1',
        usuarioIds: ['user-a', 'user-b'],
      );

      // 2 usuarios x 5 checklists x 4 capacidades
      expect(rows, hasLength(40));
      expect(
        rows.where(
          (r) => r['usuario_id'] == 'user-a' && r['capacidad'] == 'ver',
        ),
        hasLength(5),
      );
    });

    test('returns no rows when there are no usuarios', () {
      final rows = buildHerramientasPermissionGrantRows(
        empresaId: 'empresa-1',
        usuarioIds: const [],
      );

      expect(rows, isEmpty);
    });
  });
}
