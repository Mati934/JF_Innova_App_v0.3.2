// Tests del módulo Merieux (submódulos Visitas + Extintores, independiente).
//
// Reglas verificadas:
// 1. `getBorradores` filtra por tipo_actividad (VISITAS vs EXTINTORES),
//    estado_final = 'En Progreso', eliminado = 0 y usuario_id.
// 2. Guardar una visita con checklist persiste sus respuestas y se pueden
//    releer junto con la cabecera (`getVisitaConRespuestasById`).
// 3. Guardar un registro de extintores persiste la grilla completa y se
//    puede releer con `getExtintoresPorVisita`.
// 4. `eliminarBorrador` hace borrado lógico (no aparece más en borradores).

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/merieux/data/repositories/local_merieux_repository.dart';
import 'package:jf_innova_app/features/merieux/domain/models/merieux_visita.dart';
import 'package:jf_innova_app/features/prosesso/domain/models/prosesso_extintor_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalMerieuxRepository repo;
  const usuarioId = 'user-1';

  MerieuxVisita visita(
    String id,
    String tipoActividad, {
    String estado = 'En Progreso',
  }) => MerieuxVisita(
    id: id,
    tipoActividad: tipoActividad,
    fechaRealizacion: DateTime(2026, 7, 8, 10, 0),
    usuarioId: usuarioId,
    region: 'Región X',
    area: 'Área Y',
    estadoFinal: estado,
  );

  setUp(() async {
    repo = LocalMerieuxRepository();
    final db = await DatabaseHelper.instance.database;
    await db.delete('merieux_visita_respuestas_pendientes');
    await db.delete('merieux_extintores_pendientes');
    await db.delete('merieux_visitas_pendientes');
  });

  group('Merieux · borradores por submódulo', () {
    test(
      'getBorradores filtra por tipo_actividad y excluye finalizados',
      () async {
        await repo.guardarVisita(visita('v1', kMerieuxTipoVisitas), const []);
        await repo.guardarVisita(
          visita('v2', kMerieuxTipoVisitas, estado: 'En Seguimiento'),
          const [],
        );
        await repo.guardarVisitaExtintores(
          visita('e1', kMerieuxTipoExtintores),
          const [],
        );

        final borradoresVisitas = await repo.getBorradores(
          tipoActividad: kMerieuxTipoVisitas,
        );
        final borradoresExtintores = await repo.getBorradores(
          tipoActividad: kMerieuxTipoExtintores,
        );

        expect(borradoresVisitas.map((e) => e['id']).toSet(), {'v1'});
        expect(borradoresExtintores.map((e) => e['id']).toSet(), {'e1'});
      },
    );

    test('eliminarBorrador hace borrado lógico', () async {
      await repo.guardarVisita(visita('v1', kMerieuxTipoVisitas), const []);
      expect(
        (await repo.getBorradores(tipoActividad: kMerieuxTipoVisitas)).length,
        1,
      );

      await repo.eliminarBorrador('v1');

      expect(
        (await repo.getBorradores(tipoActividad: kMerieuxTipoVisitas)).length,
        0,
      );
    });
  });

  group('Merieux · persistencia de checklist', () {
    test(
      'guardarVisita persiste respuestas y se releen con la cabecera',
      () async {
        final v = visita('v1', kMerieuxTipoVisitas)
          ..checklistTipo = kMerieuxChecklistVehiculosLivianos;
        final respuestas = [
          MerieuxRespuesta(
            id: 'r1',
            visitaId: 'v1',
            itemId: 'item-1',
            estado: 'C',
          ),
          MerieuxRespuesta(
            id: 'r2',
            visitaId: 'v1',
            itemId: 'item-2',
            estado: 'NC',
          ),
        ];

        await repo.guardarVisita(v, respuestas);
        final leido = await repo.getVisitaConRespuestasById('v1');

        expect(leido, isNotNull);
        expect(leido!['checklist_tipo'], kMerieuxChecklistVehiculosLivianos);
        final respuestasLeidas = leido['respuestas'] as List;
        expect(respuestasLeidas.length, 2);
      },
    );

    test('guardarVisitaExtintores persiste la grilla completa', () async {
      final v = visita('e1', kMerieuxTipoExtintores);
      final extintores = [
        ExtintorProsessoState(
          localId: 'ext-1',
          numero: 1,
          planta: 'Planta A',
          puntos: const [
            PuntoProsessoState(
              itemId: 'p1',
              pregunta: '¿Presión correcta?',
              estado: EstadoPuntoProsesso.cumple,
            ),
          ],
        ),
      ];

      await repo.guardarVisitaExtintores(v, extintores);
      final releidos = await repo.getExtintoresPorVisita('e1', const []);

      expect(releidos.length, 1);
      expect(releidos.first.planta, 'Planta A');
    });
  });
}
