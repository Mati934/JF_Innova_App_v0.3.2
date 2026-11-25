// Tests del módulo Turno (PLAN_TURNO.md §2).
//
// Reglas verificadas:
// 1. Salida estimada = ingreso + 13 (14 días), también cruzando mes y año.
// 2. Ingreso: no futuro, máximo 13 días atrás y después de la salida anterior.
// 3. Salida: entre el ingreso y hoy; se propone hoy, o la estimada si ya pasó.
// 4. Vencido: activo y hoy después de la salida estimada.
// 5. Diferencia con la estimada y días reales.
// 6. Controlador: un solo activo, editar recalcula la estimada (o la
//    acorta si el auditor la ajusta, máximo 14 días), confirmar
//    salida cierra (con fecha atrás) y el turno pasa a "Mis turnos" con
//    área y centro; eliminar es soft delete pendiente de subir.
// 7. Payloads de Supabase: sin columnas locales y booleanos reales.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/turno/data/local_turno_cierre_repository.dart';
import 'package:jf_innova_app/features/turno/domain/turno.dart';
import 'package:jf_innova_app/features/turno/domain/turno_cierre.dart';
import 'package:flutter/material.dart';
import 'package:jf_innova_app/features/turno/presentation/controllers/turno_controller.dart';
import 'package:jf_innova_app/features/turno/presentation/screens/turno_module_screen.dart';
import 'package:jf_innova_app/features/sync/services/sync_service.dart';
import 'package:jf_innova_app/features/turno/services/turno_sync.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

Turno turno({
  required DateTime ingreso,
  String estado = TurnoEstado.activo,
  DateTime? egreso,
}) => Turno(
  id: 't1',
  usuarioId: 'u1',
  empresaId: 'e1',
  areaId: 'a1',
  centroId: null,
  estado: estado,
  ingresoFecha: ingreso,
  egresoEstimado: TurnoReglas.egresoEstimado(ingreso),
  egresoFecha: egreso,
  extraordinario: false,
  observacionIngreso: null,
  observacionEgreso: null,
  ingresoRegistradoAt: ingreso,
  egresoRegistradoAt: null,
  appVersion: null,
  createdAt: ingreso,
  updatedAt: ingreso,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // SyncService pide Supabase al construirse; sin red (solo se usan los
    // contadores locales).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await Supabase.initialize(
      url: 'https://turno-test.invalid',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  group('Reglas de fechas', () {
    test('salida estimada = ingreso + 13, cruzando mes y año', () {
      expect(TurnoReglas.egresoEstimado(d(2026, 11, 24)), d(2026, 12, 7));
      expect(TurnoReglas.egresoEstimado(d(2026, 12, 25)), d(2027, 1, 7));
      expect(TurnoReglas.egresoEstimado(d(2028, 2, 20)), d(2028, 3, 4));
    });

    test('día del turno y vencido', () {
      final t = turno(ingreso: d(2026, 11, 24));
      expect(TurnoReglas.diaDelTurno(t.ingresoFecha, d(2026, 11, 24)), 1);
      expect(TurnoReglas.diaDelTurno(t.ingresoFecha, d(2026, 12, 7)), 14);
      expect(TurnoReglas.vencido(t, d(2026, 12, 7)), isFalse);
      expect(TurnoReglas.vencido(t, d(2026, 12, 8)), isTrue);
      final cerrado = turno(
        ingreso: d(2026, 11, 24),
        estado: TurnoEstado.cerrado,
        egreso: d(2026, 12, 7),
      );
      expect(TurnoReglas.vencido(cerrado, d(2026, 12, 20)), isFalse);
    });

    test(
      'ingreso: no futuro, máximo 13 días atrás, tras la salida anterior',
      () {
        final hoy = d(2026, 11, 24);
        expect(TurnoReglas.validarIngreso(hoy, hoy), isNull);
        expect(TurnoReglas.validarIngreso(d(2026, 11, 11), hoy), isNull);
        expect(TurnoReglas.validarIngreso(d(2026, 11, 10), hoy), isNotNull);
        expect(TurnoReglas.validarIngreso(d(2026, 11, 25), hoy), isNotNull);
        final salida = d(2026, 11, 20);
        expect(
          TurnoReglas.validarIngreso(salida, hoy, ultimaSalida: salida),
          isNotNull,
        );
        expect(
          TurnoReglas.validarIngreso(
            d(2026, 11, 21),
            hoy,
            ultimaSalida: salida,
          ),
          isNull,
        );
        expect(TurnoReglas.ingresoMinimo(hoy), d(2026, 11, 11));
        expect(
          TurnoReglas.ingresoMinimo(hoy, ultimaSalida: salida),
          d(2026, 11, 21),
        );
      },
    );

    test('salida: propuesta y límites', () {
      final t = turno(ingreso: d(2026, 11, 24));
      expect(TurnoReglas.salidaPropuesta(t, d(2026, 12, 5)), d(2026, 12, 5));
      // Pasó la estimada: se propone la estimada (olvidó marcar).
      expect(TurnoReglas.salidaPropuesta(t, d(2026, 12, 9)), d(2026, 12, 7));
      final hoy = d(2026, 12, 9);
      expect(TurnoReglas.validarSalida(d(2026, 12, 8), t, hoy), isNull);
      expect(TurnoReglas.validarSalida(d(2026, 11, 24), t, hoy), isNull);
      expect(TurnoReglas.validarSalida(d(2026, 11, 23), t, hoy), isNotNull);
      expect(TurnoReglas.validarSalida(d(2026, 12, 10), t, hoy), isNotNull);
    });

    test('días reales y diferencia con la estimada', () {
      final est = d(2026, 12, 7);
      expect(TurnoReglas.diasReales(d(2026, 11, 24), est), 14);
      expect(TurnoReglas.diferencia(est, est), 'a tiempo');
      expect(TurnoReglas.diferencia(d(2026, 12, 5), est), '2 días antes');
      expect(TurnoReglas.diferencia(d(2026, 12, 8), est), '1 día después');
    });

    test('fila SQLite ida y vuelta', () {
      final t = turno(ingreso: d(2026, 11, 24));
      final r = Turno.fromRow({...t.toRow(), 'subido': 1});
      expect(r.ingresoFecha, d(2026, 11, 24));
      expect(r.egresoEstimado, d(2026, 12, 7));
      expect(r.egresoFecha, isNull);
      expect(r.subido, isTrue);
      expect(t.toRow()['ingreso_fecha'], '2026-11-24');
    });

    test('salida estimada ajustable: entre el ingreso y 14 días', () {
      final ing = d(2026, 11, 24);
      expect(TurnoReglas.duracion(ing, d(2026, 12, 7)), 14);
      expect(TurnoReglas.duracion(ing, ing), 1);
      expect(TurnoReglas.validarEgresoEstimado(ing, ing), isNull);
      expect(TurnoReglas.validarEgresoEstimado(ing, d(2026, 12, 7)), isNull);
      expect(TurnoReglas.validarEgresoEstimado(ing, d(2026, 12, 8)), isNotNull);
      expect(
        TurnoReglas.validarEgresoEstimado(ing, d(2026, 11, 23)),
        isNotNull,
      );
      expect(TurnoFechas.legible(d(2026, 11, 25)), 'mié 25 nov');
    });
  });

  group('Controlador y persistencia local', () {
    late DateTime ahora;
    late TurnoController c;
    var syncs = 0;

    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('turnos');
      await db.delete('areas', where: "id LIKE 'tt-%'");
      await db.delete('centros', where: "id LIKE 'tt-%'");
      await db.insert('areas', {'id': 'tt-a1', 'nombre': 'CISNES'});
      await db.insert('centros', {
        'id': 'tt-c1',
        'nombre': 'Puerto Cisnes',
        'area_id': 'tt-a1',
      });
      ahora = DateTime(2026, 11, 24, 9, 30);
      syncs = 0;
      c = TurnoController(
        ahora: () => ahora,
        usuarioId: () => 'tt-user',
        empresaId: () => null,
        sincronizar: () async => syncs++,
      );
      await c.cargar();
    });

    tearDown(() => c.dispose());

    test('registrar, editar, confirmar salida atrasada', () async {
      expect(c.activo, isNull);
      expect(
        await c.registrarIngreso(
          DatosIngreso(fecha: ahora, areaId: 'tt-a1', centroId: 'tt-c1'),
        ),
        isNull,
      );
      expect(c.activo?.areaNombre, 'CISNES');
      expect(c.activo?.centroNombre, 'Puerto Cisnes');
      expect(c.activo?.egresoEstimado, d(2026, 12, 7));
      expect(c.activo?.subido, isFalse);

      // Un solo activo.
      expect(
        await c.registrarIngreso(DatosIngreso(fecha: ahora, areaId: 'tt-a1')),
        isNotNull,
      );

      // Editar el ingreso (sin centro) recalcula la estimada.
      expect(
        await c.editarIngreso(
          DatosIngreso(fecha: d(2026, 11, 22), areaId: 'tt-a1'),
        ),
        isNull,
      );
      expect(c.activo?.ingresoFecha, d(2026, 11, 22));
      expect(c.activo?.egresoEstimado, d(2026, 12, 5));

      // Turno extra más corto: la salida se puede acortar; más de 14, no.
      expect(
        await c.editarIngreso(
          DatosIngreso(
            fecha: d(2026, 11, 22),
            areaId: 'tt-a1',
            egresoEstimado: d(2026, 11, 26),
          ),
        ),
        isNull,
      );
      expect(c.activo?.egresoEstimado, d(2026, 11, 26));
      expect(
        await c.editarIngreso(
          DatosIngreso(
            fecha: d(2026, 11, 22),
            areaId: 'tt-a1',
            egresoEstimado: d(2026, 12, 6),
          ),
        ),
        isNotNull,
      );
      expect(
        await c.editarIngreso(
          DatosIngreso(fecha: d(2026, 11, 22), areaId: 'tt-a1'),
        ),
        isNull,
      );
      expect(c.activo?.centroId, isNull);

      // Dos días después de la estimada confirma con fecha atrás.
      ahora = DateTime(2026, 12, 7, 18);
      expect(c.activo != null && TurnoReglas.vencido(c.activo!, c.hoy), isTrue);
      expect(
        await c.confirmarSalida(d(2026, 12, 5), observacion: ' llegó relevo '),
        isNull,
      );
      expect(c.activo, isNull);
      expect(c.cerrados, hasLength(1));
      final cerrado = c.cerrados.single;
      expect(cerrado.estado, TurnoEstado.cerrado);
      expect(cerrado.egresoFecha, d(2026, 12, 5));
      expect(cerrado.observacionEgreso, 'llegó relevo');
      expect(cerrado.egresoRegistradoAt, isNotNull);
      expect(c.ultimaSalida, d(2026, 12, 5));

      // El turno siguiente no puede empezar el mismo día de la salida.
      expect(
        await c.registrarIngreso(
          DatosIngreso(fecha: d(2026, 12, 5), areaId: 'tt-a1'),
        ),
        isNotNull,
      );
      // Preselección del último turno.
      expect(c.ultimaUbicacion.areaId, 'tt-a1');
      expect(syncs, greaterThan(0));
    });

    test(
      'un turno vencido de 20 días se puede editar sin cambiar la fecha',
      () async {
        await c.registrarIngreso(DatosIngreso(fecha: ahora, areaId: 'tt-a1'));
        ahora = DateTime(2026, 12, 13, 9);
        final t = c.activo!;
        expect(
          await c.editarIngreso(
            DatosIngreso(
              fecha: t.ingresoFecha,
              areaId: 'tt-a1',
              centroId: 'tt-c1',
            ),
          ),
          isNull,
        );
        expect(c.activo?.centroId, 'tt-c1');
        // Cambiar la fecha a otra igual de vieja sí se rechaza.
        expect(
          await c.editarIngreso(
            DatosIngreso(fecha: d(2026, 11, 25), areaId: 'tt-a1'),
          ),
          isNotNull,
        );
      },
    );

    test('un turno sin subir cuenta como pendiente en Inicio', () async {
      final antes = await SyncService().contarPendientesCabecera();
      await c.registrarIngreso(DatosIngreso(fecha: ahora, areaId: 'tt-a1'));
      expect(await SyncService().contarPendientesCabecera(), antes + 1);
      final lista = await SyncService().listarPendientesSincronizacion();
      final item = lista.firstWhere((i) => i['modulo'] == 'TURNO');
      expect(item['estado_final'], TurnoEstado.activo);
      expect(item['fecha_realizacion'], '2026-11-24');
    });

    test('eliminar deja el turno de baja y pendiente de subir', () async {
      await c.registrarIngreso(DatosIngreso(fecha: ahora, areaId: 'tt-a1'));
      final id = c.activo!.id;
      await c.eliminarActivo();
      expect(c.activo, isNull);
      final db = await DatabaseHelper.instance.database;
      final row = (await db.query(
        'turnos',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      expect(row['eliminado'], 1);
      expect(row['subido'], 0);
    });
  });

  group('Pantalla', () {
    // Reloj que se puede adelantar después de registrar (un turno vencido
    // no se puede registrar de una vez: el ingreso es de máximo 13 días atrás).
    late DateTime reloj;

    Future<TurnoController> preparar(
      WidgetTester tester,
      DateTime ahora,
    ) async {
      reloj = ahora;
      late TurnoController c;
      await tester.runAsync(() async {
        final db = await DatabaseHelper.instance.database;
        await db.delete('turnos');
        await db.insert('areas', {
          'id': 'tt-a1',
          'nombre': 'CISNES',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        c = TurnoController(
          ahora: () => reloj,
          usuarioId: () => 'tt-user',
          empresaId: () => null,
          sincronizar: () async {},
        );
        await c.registrarIngreso(
          DatosIngreso(fecha: d(2026, 11, 24), areaId: 'tt-a1'),
        );
      });
      return c;
    }

    testWidgets('turno activo, vencido y formulario sin errores', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final c = await preparar(tester, DateTime(2026, 11, 28, 10));
      await tester.pumpWidget(
        MaterialApp(home: TurnoModuleScreen(controller: c)),
      );
      await tester.pump();
      expect(find.text('En turno'), findsOneWidget);
      expect(find.text('Día 5 de 14'), findsOneWidget);
      expect(find.text('CISNES'), findsOneWidget);
      expect(find.text('Confirmar salida'), findsOneWidget);

      // El form carga centros desde SQLite (no resuelve en fake async):
      // se avanza con tiempo fijo en vez de pumpAndSettle.
      await tester.tap(find.text('Editar'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Editar turno'), findsOneWidget);
      expect(find.text('Turno de 14 días'), findsOneWidget);
      expect(find.text('Automática'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 600));

      // Turno corto: "Día X de 6", y el form a 360 de ancho no desborda.
      await tester.runAsync(
        () => c.editarIngreso(
          DatosIngreso(
            fecha: d(2026, 11, 24),
            areaId: 'tt-a1',
            egresoEstimado: d(2026, 11, 29),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Día 5 de 6'), findsOneWidget);
      await tester.tap(find.text('Editar'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Turno corto de 6 días'), findsOneWidget);
      expect(find.text('Ajustada'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Mañana es tu último día'), findsOneWidget);

      // Opciones → Eliminar muestra la confirmación con el resumen; cancelar
      // no borra.
      await tester.tap(find.byTooltip('Opciones del turno'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar turno'), findsOneWidget);
      await tester.tap(find.text('Eliminar turno'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar este turno?'), findsOneWidget);
      expect(find.text('Sí, eliminar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(c.activo, isNotNull);

      await tester.pumpWidget(const SizedBox());
      c.dispose();

      final v = await preparar(tester, DateTime(2026, 11, 28, 10));
      reloj = DateTime(2026, 12, 10, 10);
      await tester.pumpWidget(
        MaterialApp(home: TurnoModuleScreen(controller: v)),
      );
      await tester.pump();
      expect(find.text('Sin cerrar'), findsOneWidget);
      expect(find.textContaining('Tu turno terminaba'), findsOneWidget);

      await tester.tap(find.text('Confirmar salida'));
      await tester.pumpAndSettle();
      expect(find.text('14 días · a tiempo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      // La carga de la pantalla deja el aviso de bloqueo de sqflite (10 s).
      await tester.pump(const Duration(seconds: 15));
      v.dispose();
    });
  });

  group('Payloads de Supabase', () {
    test('sin columnas locales y booleano real', () {
      final row = {
        ...turno(ingreso: d(2026, 11, 24)).toRow(),
        'extraordinario': 1,
        'subido': 0,
        'eliminado': 0,
        'area_nombre': 'CISNES',
      };
      final p = turnoPayloadSupabase(row);
      expect(p.containsKey('subido'), isFalse);
      expect(p.containsKey('eliminado'), isFalse);
      expect(p.containsKey('area_nombre'), isFalse);
      expect(p['extraordinario'], isTrue);
      expect(p['ingreso_fecha'], '2026-11-24');

      final local = turnoRowDesdeSupabase({...p, 'extraordinario': false});
      expect(local['extraordinario'], 0);
      expect(local['subido'], 1);
    });
  });

  group('Cierre local', () {
    TurnoCierre cierre(String id, DateTime upd) => TurnoCierre(
      id: id,
      turnoId: 'tt-turno-c',
      usuarioId: 'tt-user',
      empresaId: null,
      areaId: null,
      desde: d(2026, 11, 1),
      hasta: d(2026, 11, 14),
      estado: CierreEstado.borrador,
      numeros: const {'n_centros': 2},
      filas: const {},
      bitacora: 'local',
      pdfUrl: null,
      pdfVersion: null,
      pdfGeneradoAt: null,
      pdfPathLocal: null,
      appVersion: null,
      createdAt: upd,
      updatedAt: upd,
    );

    test(
      'subido solo si no cambió y cambio de id sin perder lo editado',
      () async {
        final repo = LocalTurnoCierreRepository();
        final db = await DatabaseHelper.instance.database;
        await db.delete('turno_cierres');
        final v1 = cierre('c-local', DateTime.utc(2026, 11, 14, 10));
        await repo.guardar(v1);
        // Mientras subía v1 se guardó una versión más nueva: no se marca.
        final v2 = cierre('c-local', DateTime.utc(2026, 11, 14, 11));
        await repo.guardar(v2);
        await repo.marcarSubido('c-local', v1.toRow()['updated_at'] as String);
        expect((await repo.getPorTurno('tt-turno-c'))!.subido, isFalse);
        await repo.marcarSubido('c-local', v2.toRow()['updated_at'] as String);
        expect((await repo.getPorTurno('tt-turno-c'))!.subido, isTrue);

        await repo.guardar(v2);
        await repo.cambiarId('c-local', 'c-remoto');
        final c = (await repo.getPorTurno('tt-turno-c'))!;
        expect(c.id, 'c-remoto');
        expect(c.bitacora, 'local');
        expect(c.subido, isFalse);
      },
    );
  });
}
