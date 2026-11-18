// Tests del módulo Registro de inmersiones.
//
// Reglas verificadas:
// 1. Tiempo desde–hasta (incluye cruce de medianoche), metros con coma y
//    normalización de series.
// 2. Resumen por buzo con varias inmersiones: la mayor profundidad, la suma
//    de tiempos y la cantidad; un buzo que no buceó no suma nada.
// 3. Exceso: se guarda siempre; el rojo solo si el auditor lo marcó y hay
//    exceso.
// 4. Un registro nuevo trae solo a los de rol Buzo de la cuadrilla, con el
//    "desde" lleno.
// 5. Guardar y reabrir conserva buzos, inmersiones y fotos; la lista del
//    módulo marca qué inspecciones ya tienen registro.
// 6. Payloads de Supabase: booleanos reales y sin columnas del trigger.
// 7. PDF: "No buceó", rojo y N° pendiente.
// 8. Registro sin inspección: se crea vacío, aparece en la lista del módulo y
//    al vincularlo trae los buzos de la cuadrilla sin duplicar a los que ya
//    estaban.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/history/presentation/widgets/history_card.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_data.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_mapper.dart';
import 'package:jf_innova_app/features/registro_inmersiones/data/repositories/local_registro_inmersion_repository.dart';
import 'package:jf_innova_app/features/registro_inmersiones/domain/models/registro_inmersion_models.dart';
import 'package:jf_innova_app/features/registro_inmersiones/domain/models/registro_inmersion_pdf_data.dart';
import 'package:jf_innova_app/features/registro_inmersiones/presentation/controllers/registro_inmersion_form_controller.dart';
import 'package:jf_innova_app/features/registro_inmersiones/services/registro_inmersion_pdf_service.dart';
import 'package:jf_innova_app/features/registro_inmersiones/services/registro_inmersion_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Cálculos', () {
    test('tiempo desde–hasta, con cruce de medianoche', () {
      expect(RegistroInmersionCalculos.tiempoMin('09:10', '09:55'), 45);
      expect(RegistroInmersionCalculos.tiempoMin('23:50', '00:20'), 30);
      expect(RegistroInmersionCalculos.tiempoMin('9:05', '9:05'), 0);
      expect(RegistroInmersionCalculos.tiempoMin('09:10', null), isNull);
      expect(RegistroInmersionCalculos.tiempoMin('25:00', '10:00'), isNull);
    });

    test('metros con coma, series normalizadas y formato', () {
      expect(RegistroInmersionCalculos.parseMetros('18,8'), 18.8);
      expect(RegistroInmersionCalculos.parseMetros(''), isNull);
      expect(RegistroInmersionCalculos.parseMetros('abc'), isNull);
      expect(RegistroInmersionCalculos.normalizarSerie('u-18659'), 'U18659');
      expect(RegistroInmersionCalculos.normalizarSerie(' '), isNull);
      expect(RegistroInmersionCalculos.formatoMetros(21), '21');
      expect(RegistroInmersionCalculos.formatoMetros(18.8), '18,8');
      expect(RegistroInmersionCalculos.normalizarHora('9:05'), '09:05');
    });
  });

  group('Resumen por buzo', () {
    RegistroInmersionBuzo buzo({bool buceo = true}) => RegistroInmersionBuzo(
      id: 'b1',
      registroId: 'r1',
      nombre: 'Buzo Uno',
      realizoInmersion: buceo,
      inmersiones: [
        Inmersion(
          id: 'i1',
          buzoId: 'b1',
          registroId: 'r1',
          profundidadMaximaM: 18.8,
          horaInicio: '09:00',
          horaTermino: '09:40',
        ),
        Inmersion(
          id: 'i2',
          buzoId: 'b1',
          registroId: 'r1',
          profundidadMaximaM: 21,
          horaInicio: '11:00',
          horaTermino: '11:20',
        ),
        // Bloque vacío (se agregó y no se llenó): no cuenta.
        Inmersion(id: 'i3', buzoId: 'b1', registroId: 'r1'),
      ],
    );

    test('varias inmersiones: mayor profundidad, suma y cantidad', () {
      final b = buzo();
      expect(b.profundidadMaximaM, 21);
      expect(b.tiempoTotalMin, 60);
      expect(b.cantidadInmersiones, 2);
      expect(b.excede(20), isTrue);
      expect(b.excede(25), isFalse);
      expect(b.excede(null), isFalse);
      // 0 = sin dato (así viene hoy de la inspección): nunca es exceso.
      expect(b.excede(0), isFalse);
    });

    test('si no buceó, no suma nada', () {
      final b = buzo(buceo: false);
      expect(b.profundidadMaximaM, isNull);
      expect(b.tiempoTotalMin, isNull);
      expect(b.cantidadInmersiones, 0);
      expect(b.excede(20), isFalse);
    });

    test('el exceso se guarda siempre; el rojo solo si se marcó', () {
      final b = buzo();
      expect(b.toRow(20)['excede_autorizada'], 1);
      expect(b.toRow(20)['marcado_rojo'], 0);
      b.marcadoRojo = true;
      expect(b.toRow(20)['marcado_rojo'], 1);
      // Si ya no hay exceso, el rojo no queda guardado.
      expect(b.toRow(30)['marcado_rojo'], 0);
    });
  });

  group('Nuevo registro desde la inspección', () {
    test('trae solo a los buzos de la cuadrilla, con el desde lleno', () {
      final nuevo = LocalRegistroInmersionRepository.nuevoDesdeInspeccion(
        base: const InspeccionBuceoBase(
          actividadId: 'act-1',
          centroNombre: 'Punta Ganso',
          profundidadAutorizadaM: 20,
          cuadrilla: [
            ParticipanteCuadrilla(personalId: 'p1', nombre: 'A', rol: 'Buzo'),
            ParticipanteCuadrilla(personalId: 'p2', nombre: 'B', rol: 'Buzo'),
            ParticipanteCuadrilla(
              personalId: 'p3',
              nombre: 'C',
              rol: 'Supervisor',
            ),
          ],
        ),
        origen: RegistroInmersionOrigen.avisoFinalizar,
        usuarioId: 'u1',
        empresaId: 'e1',
        ahora: DateTime(2026, 7, 31, 14, 5),
      );
      expect(nuevo.registro.actividadId, 'act-1');
      expect(nuevo.registro.origen, RegistroInmersionOrigen.avisoFinalizar);
      expect(nuevo.registro.estadoFinal, RegistroInmersionEstado.borrador);
      expect(nuevo.buzos.map((b) => b.nombre), ['A', 'B']);
      final inm = nuevo.buzos.first.inmersiones.single;
      expect(inm.horaInicio, '14:05');
      expect(inm.horaInicioEditada, isFalse);
    });
  });

  group('Persistencia local', () {
    late LocalRegistroInmersionRepository repo;

    setUp(() async {
      repo = LocalRegistroInmersionRepository();
      final db = await DatabaseHelper.instance.database;
      for (final t in [
        'registro_inmersion_fotos_pendientes',
        'registro_inmersion_inmersiones_pendientes',
        'registro_inmersion_buzos_pendientes',
        'registros_inmersion_pendientes',
      ]) {
        await db.delete(t);
      }
      await db.delete('actividades_pendientes', where: "id LIKE 'ri-%'");
    });

    test('guardar y reabrir conserva buzos, inmersiones y fotos', () async {
      final registro = RegistroInmersion(
        id: 'reg-1',
        actividadId: 'ri-act-1',
        usuarioId: 'u1',
        profundidadAutorizadaM: 20,
      );
      final buzo = RegistroInmersionBuzo(
        id: 'bz-1',
        registroId: 'reg-1',
        nombre: 'Buzo Uno',
        rut: '131677804',
        dispositivoSerie: 'u-18659',
        marcadoRojo: true,
        inmersiones: [
          Inmersion(
            id: 'in-1',
            buzoId: 'bz-1',
            registroId: 'reg-1',
            profundidadMaximaM: 21,
            horaInicio: '09:00',
            horaTermino: '09:30',
          ),
        ],
      );
      final foto = RegistroInmersionFoto(
        id: 'f-1',
        registroId: 'reg-1',
        buzoId: 'bz-1',
        tipo: RegistroInmersionFotoTipo.profundimetro,
        localPath: '/tmp/x.jpg',
      );

      await repo.guardar(registro, [buzo], [foto]);
      final c = await repo.getCompleto('reg-1');

      expect(c, isNotNull);
      expect(c!.buzos.single.inmersiones.single.tiempoMin, 30);
      expect(c.buzos.single.marcadoRojo, isTrue);
      expect(c.buzos.single.dispositivoSerie, 'U18659');
      expect(c.fotos.single.tipo, RegistroInmersionFotoTipo.profundimetro);

      final db = await DatabaseHelper.instance.database;
      final fila = (await db.query(
        'registro_inmersion_buzos_pendientes',
      )).single;
      expect(fila['excede_autorizada'], 1);
      expect(fila['tiempo_total_min'], 30);
      expect(fila['cantidad_inmersiones'], 1);
    });

    test('abre un registro nuevo desde una inspección del teléfono', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'actividad_participantes',
        where: "actividad_id LIKE 'ri-%'",
      );
      await db.delete('personal_externo', where: "id LIKE 'ri-%'");
      await db.insert('actividades_pendientes', {
        'id': 'ri-act-9',
        'usuario_id': 'u1',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'estado_final': 'Aprobado',
        'fecha_realizacion': '2026-07-31T10:00:00',
        'numero_reporte': '1234',
        'eliminado': 0,
      });
      for (final p in [
        ['ri-p1', 'Buzo A', 'Buzo'],
        ['ri-p2', 'Super B', 'Supervisor'],
      ]) {
        await db.insert('personal_externo', {
          'id': p[0],
          'nombre_completo': p[1],
        });
        await db.insert('actividad_participantes', {
          'actividad_id': 'ri-act-9',
          'personal_id': p[0],
          'rol_en_faena': p[2],
        });
      }

      final ctrl = RegistroInmersionFormController(actividadId: 'ri-act-9');
      await ctrl.init();
      try {
        expect(ctrl.errorMessage, isNull);
        expect(ctrl.cargado, isTrue);
        expect(ctrl.registro.numeroInspeccion, '1234');
        expect(ctrl.registro.profundidadAutorizadaM, isNull);
        expect(ctrl.buzos.map((b) => b.nombre), ['Buzo A']);
        expect(ctrl.cuadrillaDisponible.map((p) => p.nombre), ['Super B']);

        // Queda guardado de inmediato como borrador.
        final vigente = await repo.getRegistroVigentePorActividad('ri-act-9');
        expect(vigente?['estado_final'], RegistroInmersionEstado.borrador);

        // Exceso: solo con autorizada ingresada.
        final b = ctrl.buzos.single;
        ctrl.setProfundidad(b.id, b.inmersiones.single.id, '25');
        expect(ctrl.debePreguntarExceso(b.id), isFalse);
        ctrl.setProfundidadAutorizada('20');
        expect(ctrl.debePreguntarExceso(b.id), isTrue);
        expect(ctrl.debePreguntarExceso(b.id), isFalse); // una sola vez
        expect(ctrl.validarParaFinalizar(), isNull);
      } finally {
        ctrl.dispose();
      }
    });

    test('un registroId que ya no existe no crea un borrador vacío', () async {
      final ctrl = RegistroInmersionFormController(registroId: 'no-existe');
      await ctrl.init();
      try {
        expect(ctrl.cargado, isFalse);
        expect(ctrl.errorMessage, contains('ya no está'));
        expect(await repo.getBorradores(null), isEmpty);
      } finally {
        ctrl.dispose();
      }
    });

    test('registro sin inspección y vinculación posterior', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'actividad_participantes',
        where: "actividad_id LIKE 'ri-%'",
      );
      await db.delete('personal_externo', where: "id LIKE 'ri-%'");
      await db.insert('actividades_pendientes', {
        'id': 'ri-act-7',
        'usuario_id': 'u1',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'estado_final': 'Aprobado',
        'fecha_realizacion': '2026-07-30T10:00:00',
        'numero_reporte': '777',
        'eliminado': 0,
      });
      for (final p in [
        ['ri-p7', 'Buzo Uno', 'Buzo'],
        ['ri-p8', 'Buzo Dos', 'Buzo'],
      ]) {
        await db.insert('personal_externo', {
          'id': p[0],
          'nombre_completo': p[1],
        });
        await db.insert('actividad_participantes', {
          'actividad_id': 'ri-act-7',
          'personal_id': p[0],
          'rol_en_faena': p[2],
        });
      }

      final ctrl = RegistroInmersionFormController();
      await ctrl.init();
      try {
        expect(ctrl.errorMessage, isNull);
        expect(ctrl.registro.vinculado, isFalse);
        expect(ctrl.buzos, isEmpty);
        // Se agregó a mano a uno que también está en la cuadrilla.
        ctrl.agregarPersona(nombre: 'buzo uno');
        // Dos centros con el mismo nombre en zonas distintas.
        ctrl.centros = [
          {'id': 'c-aysen', 'nombre': 'JESUS 5', 'area_nombre': 'AYSEN'},
          {'id': 'c-melinka', 'nombre': 'JESUS 5', 'area_nombre': 'MELINKA'},
          {'id': 'c-huar', 'nombre': 'Isla Huar', 'area_nombre': 'CALBUCO'},
        ];
        expect(ctrl.centrosPorEtiqueta.keys, [
          'JESUS 5 · AYSEN',
          'JESUS 5 · MELINKA',
          'Isla Huar',
        ]);
        ctrl.setCentro('JESUS 5 · MELINKA');
        expect(ctrl.registro.centroId, 'c-melinka');
        expect(ctrl.registro.centroNombre, 'JESUS 5');
        expect(ctrl.centroEtiquetaActual, 'JESUS 5 · MELINKA');
        ctrl.setCentro('Isla Huar');
        // Contratista escrito a mano: queda sin id.
        ctrl.setContratista('Buzos del Sur');
        expect(ctrl.registro.contratistaNombre, 'Buzos del Sur');
        expect(ctrl.registro.contratistaId, isNull);
        ctrl.registro.usuarioId = 'u1';
        await ctrl.guardarBorradorSilencioso();

        final guardado = await repo.getCompleto(ctrl.registro.id);
        expect(guardado!.registro.actividadId, isNull);
        expect(guardado.registro.centroId, 'c-huar');
        expect(guardado.registro.centroNombre, 'Isla Huar');
        expect(
          (await repo.getRegistrosSinInspeccion('u1')).single['registro_id'],
          ctrl.registro.id,
        );

        expect(await ctrl.vincularInspeccion('ri-act-7'), isNull);
        expect(ctrl.registro.actividadId, 'ri-act-7');
        expect(ctrl.registro.numeroInspeccion, '777');
        expect(ctrl.buzos.map((b) => b.nombre), ['buzo uno', 'Buzo Dos']);
        expect(await ctrl.vincularInspeccion('ri-act-7'), isNotNull);

        expect(await repo.getRegistrosSinInspeccion('u1'), isEmpty);
        final lista = await repo.getInspeccionesBuceoDisponibles('u1');
        final fila = lista.firstWhere((r) => r['actividad_id'] == 'ri-act-7');
        expect(fila['registro_id'], ctrl.registro.id);
      } finally {
        ctrl.dispose();
      }
    });

    test('borradores del usuario y lista del módulo', () async {
      final db = await DatabaseHelper.instance.database;
      for (final a in [
        {'id': 'ri-act-1', 'estado_final': 'Aprobado'},
        {'id': 'ri-act-2', 'estado_final': 'En Progreso'},
        {'id': 'ri-act-3', 'estado_final': 'Aprobado'},
      ]) {
        await db.insert('actividades_pendientes', {
          ...a,
          'usuario_id': 'u1',
          'tipo_actividad': 'INSPECCION_BUCEO',
          'fecha_realizacion': '2026-07-31T10:00:00',
          'eliminado': 0,
        });
      }
      await repo.guardar(
        RegistroInmersion(
          id: 'reg-1',
          actividadId: 'ri-act-1',
          usuarioId: 'u1',
        ),
        const [],
        const [],
      );

      final lista = await repo.getInspeccionesBuceoDisponibles('u1');
      final porId = {for (final r in lista) r['actividad_id']: r};
      // La inspección en progreso no aparece.
      expect(porId.keys.toSet(), {'ri-act-1', 'ri-act-3'});
      expect(porId['ri-act-1']!['registro_id'], 'reg-1');
      expect(porId['ri-act-3']!['registro_id'], isNull);

      expect((await repo.getBorradores('u1')).length, 1);
      expect(await repo.getBorradores('otro'), isEmpty);

      await repo.eliminarBorrador('reg-1');
      expect(await repo.getBorradores('u1'), isEmpty);
      expect(await repo.getRegistroVigentePorActividad('ri-act-1'), isNull);
    });
  });

  test('PDF: RUT con formato y equipo separado', () {
    final data = buildRegistroInmersionPdfData(
      registro: RegistroInmersion(id: 'r8', profundidadAutorizadaM: 20),
      buzos: [
        RegistroInmersionBuzo(
          id: 'b8',
          registroId: 'r8',
          nombre: 'Uno',
          rut: '131677804',
          profundimetroMarca: 'Scubapro',
          profundimetroSerie: '55821',
          dispositivoTipo: kDispositivoSensusUltra,
          dispositivoSerie: 'U18659',
          inmersiones: [
            Inmersion(
              id: 'i8',
              buzoId: 'b8',
              registroId: 'r8',
              profundidadMaximaM: 21,
            ),
          ],
        ),
      ],
      fotos: const [],
      auditor: 'A',
    );
    final b = data.buzos.single;
    expect(b.rut, '13.167.780-4');
    expect(b.profundimetro, 'Scubapro · S/N 55821');
    expect(b.registrador, 'Sensus Ultra · S/N U18659');
    expect(b.excede, isTrue);
  });

  test('PDF se genera con nota y observación muy largas', () async {
    final largo = List.filled(400, 'palabra').join(' ');
    final bytes = await generateRegistroInmersionPdfEntryPoint(
      RegistroInmersionPdfParams(
        data: RegistroInmersionPdfData(
          correlativo: 'RI-0001',
          fecha: '31/07/2026',
          centro: 'Centro',
          contratista: 'Contratista',
          profundidadAutorizada: '20 m',
          auditor: 'A',
          observacionGeneral: largo * 3,
          buzos: [
            RegistroInmersionPdfBuzo(
              numero: 1,
              nombre: 'Nombre muy largo de un buzo con varios apellidos',
              rut: '13.167.780-4',
              cargo: 'Buzo de emergencia',
              realizoInmersion: true,
              marcadoRojo: false,
              excede: true,
              inmersiones: const [],
              profundidadMaxima: '21 m',
              tiempoTotal: '',
              nota: largo,
            ),
          ],
        ),
        fontRegular: File(
          'assets/fonts/OpenSans-Regular.ttf',
        ).readAsBytesSync(),
        fontBold: File('assets/fonts/OpenSans-Bold.ttf').readAsBytesSync(),
      ),
    );
    expect(bytes.length, greaterThan(1000));
  });

  test('PDF sin inspección vinculada no muestra N° de inspección', () {
    final data = buildRegistroInmersionPdfData(
      registro: RegistroInmersion(id: 'r9'),
      buzos: const [],
      fotos: const [],
      auditor: 'A',
      existe: (_) => false,
    );
    expect(data.numeroInspeccion, isNull);
  });

  group('Payloads de Supabase', () {
    test('cabecera sin columnas locales ni del trigger', () {
      final p = registroPayloadSupabase({
        'id': 'r1',
        'numero': 5,
        'correlativo': 'RI-0005',
        'subido': 0,
        'eliminado': 0,
        'pdf_path_local': '/x.pdf',
        'estado_final': 'Finalizado',
      });
      expect(p.keys.toSet(), {'id', 'estado_final'});
    });

    test('booleanos reales en buzos e inmersiones', () {
      final b = buzoPayloadSupabase({
        'id': 'b',
        'realizo_inmersion': 0,
        'excede_autorizada': 1,
        'marcado_rojo': 0,
      });
      expect(b['realizo_inmersion'], false);
      expect(b['excede_autorizada'], true);
      expect(b['marcado_rojo'], false);
      final i = inmersionPayloadSupabase({
        'id': 'i',
        'excede_autorizada': 0,
        'hora_inicio_editada': 1,
      });
      expect(i['excede_autorizada'], false);
      expect(i['hora_inicio_editada'], true);
      expect(i.containsKey('subido'), isFalse);
    });
  });

  group('PDF, Inicio e Historial', () {
    test('datos del PDF: no buceó, rojo y N° pendiente', () {
      final registro = RegistroInmersion(
        id: 'r1',
        actividadId: 'a1',
        profundidadAutorizadaM: 20,
        fechaRealizacion: DateTime(2026, 7, 31),
      );
      final buzos = [
        RegistroInmersionBuzo(
          id: 'b1',
          registroId: 'r1',
          nombre: 'Uno',
          marcadoRojo: true,
          inmersiones: [
            Inmersion(
              id: 'i1',
              buzoId: 'b1',
              registroId: 'r1',
              profundidadMaximaM: 21,
              horaInicio: '09:00',
              horaTermino: '09:45',
            ),
          ],
        ),
        RegistroInmersionBuzo(
          id: 'b2',
          registroId: 'r1',
          nombre: 'Dos',
          cargo: 'Buzo de emergencia',
          realizoInmersion: false,
        ),
      ];
      final data = buildRegistroInmersionPdfData(
        registro: registro,
        buzos: buzos,
        fotos: [
          RegistroInmersionFoto(
            id: 'f1',
            registroId: 'r1',
            tipo: RegistroInmersionFotoTipo.general,
            localPath: '/no/existe.jpg',
          ),
        ],
        auditor: 'Auditor',
        existe: (_) => false,
      );
      expect(data.correlativo, 'Pendiente');
      expect(data.numeroInspeccion, 'Pendiente');
      expect(data.fecha, '31/07/2026');
      expect(data.profundidadAutorizada, '20 m');
      expect(data.buzos[0].marcadoRojo, isTrue);
      expect(data.buzos[0].profundidadMaxima, '21 m');
      expect(data.buzos[0].tiempoTotal, '45 min');
      expect(data.buzos[1].realizoInmersion, isFalse);
      expect(data.buzos[1].inmersiones, isEmpty);
      expect(data.galeriaPaths, isEmpty);
    });

    test('borrador en Inicio y tarjeta del Historial', () {
      final card = DraftCardMapper.fromRegistroInmersiones({
        'id': 'r1',
        'centro_nombre': 'Punta Ganso',
        'created_at': '2026-07-31T10:00:00',
      });
      expect(card.kind, DraftKind.registroInmersiones);
      expect(card.title, 'Registro de inmersiones');
      expect(card.centro, 'Punta Ganso');

      final cfg = HistoryCardConfig.resolve(
        modulo: 'Registro de inmersiones',
        tipoRegistro: 'REGISTRO_INMERSIONES',
        folio: 'RI-0057',
      );
      expect(cfg.titulo, 'Registro de inmersiones RI-0057');
      expect(cfg.tipoChipLabel, 'Inmersiones');
    });
  });
}
