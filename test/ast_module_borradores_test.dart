// Tests del módulo AST tras separar borradores del historial general.
//
// Reglas verificadas:
// 1. El módulo AST lista SOLO borradores (`estado_final = 'En Progreso'`).
//    Los AST finalizados ('En Seguimiento') salen del módulo y viven en el
//    historial general → sin duplicación entre ambas vistas.
// 2. Finalizar un borrador (mismo id pasa a 'En Seguimiento') lo retira del
//    módulo sin crear una fila duplicada.
// 3. Los borradores eliminados no se listan.
// 4. `num_hallazgos` refleja correctamente la cantidad de hallazgos.
// 5. En el historial, el estado interno 'En Seguimiento' de un AST se muestra
//    como 'Finalizado'.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/ast/data/repositories/local_ast_repository.dart';
import 'package:jf_innova_app/features/ast/domain/models/ast_models.dart';
import 'package:jf_innova_app/features/history/presentation/widgets/history_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  AstInforme informe(String id, String estado) => AstInforme(
    id: id,
    estadoFinal: estado,
    areaNombre: 'Área $id',
    centroNombre: 'Centro $id',
    contratistaNombre: 'Empresa $id',
    profesional: 'Pro $id',
    fechaRealizacion: DateTime(2026, 6, 9, 12, 0),
  );

  group('AST · el módulo solo muestra borradores (sin duplicar historial)', () {
    late LocalAstRepository repo;

    setUp(() async {
      repo = LocalAstRepository();
      final db = await DatabaseHelper.instance.database;
      await db.delete('ast_hallazgos_pendientes');
      await db.delete('ast_informes_pendientes');
    });

    test('getBorradores incluye En Progreso y excluye finalizados', () async {
      await repo.guardarInforme(informe('b1', 'En Progreso'), const []);
      await repo.guardarInforme(informe('f1', 'En Seguimiento'), const []);

      final borradores = await repo.getBorradores();
      final ids = borradores.map((e) => e['id']).toSet();

      expect(borradores.length, 1);
      expect(ids, contains('b1'));
      expect(ids, isNot(contains('f1')));
    });

    test(
      'finalizar un AST lo retira del módulo sin duplicar la fila',
      () async {
        await repo.guardarInforme(informe('x', 'En Progreso'), const []);
        expect((await repo.getBorradores()).length, 1);

        // Finalización: el mismo id pasa a 'En Seguimiento'.
        await repo.guardarInforme(informe('x', 'En Seguimiento'), const []);

        expect(await repo.getBorradores(), isEmpty);

        // No se duplican filas: el id existe una sola vez en la tabla.
        final db = await DatabaseHelper.instance.database;
        final filas = await db.query(
          'ast_informes_pendientes',
          where: 'id = ?',
          whereArgs: ['x'],
        );
        expect(filas.length, 1);
        expect(filas.single['estado_final'], 'En Seguimiento');
      },
    );

    test('los borradores eliminados no se listan', () async {
      await repo.guardarInforme(informe('e1', 'En Progreso'), const []);
      await repo.eliminarBorrador('e1');
      expect(await repo.getBorradores(), isEmpty);
    });

    test('num_hallazgos refleja la cantidad de hallazgos', () async {
      final hallazgos = [
        AstHallazgo(id: 'h1', informeId: 'b', numero: 1, titulo: 'T1'),
        AstHallazgo(id: 'h2', informeId: 'b', numero: 2, titulo: 'T2'),
      ];
      await repo.guardarInforme(informe('b', 'En Progreso'), hallazgos);

      final borradores = await repo.getBorradores();
      expect(borradores.single['num_hallazgos'], 2);
    });
  });

  group('AST · historial muestra "Finalizado" en vez de "En Seguimiento"', () {
    test('estadoLabel mapea AST En Seguimiento -> Finalizado', () {
      expect(
        HistoryCardConfig.estadoLabel('AST', 'En Seguimiento'),
        'Finalizado',
      );
    });

    test('estadoLabel no altera otros módulos ni otros estados', () {
      expect(
        HistoryCardConfig.estadoLabel('Inspección', 'En Seguimiento'),
        'En Seguimiento',
      );
      expect(
        HistoryCardConfig.estadoLabel('AST', 'En Progreso'),
        'En Progreso',
      );
    });

    test('resolve para AST usa título, icono y acento propios', () {
      final cfg = HistoryCardConfig.resolve(
        modulo: 'AST',
        tipoRegistro: 'AST',
        folio: 'AST-2026-0016',
      );
      expect(cfg.titulo, 'AST-2026-0016');
      expect(cfg.tipoChipLabel, 'AST');
      expect(cfg.icon, Icons.shield_outlined);
      expect(cfg.accent, const Color(0xFF003366));
    });
  });
}
