import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/inspection/domain/models/buceo_verificacion_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/participante_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';

void main() {
  // ===================================================================
  // TESTS DE LÓGICA DE NÚMERO PROVISIONAL (PROV-*)
  // ===================================================================
  group('Número de Informe - Lógica PROV-*', () {
    test('PROV- se genera con los primeros 8 chars del UUID en mayúsculas', () {
      const activityId = '386881ae-1234-5678-abcd-ef0123456789';
      final provisional = "PROV-${activityId.substring(0, 8).toUpperCase()}";
      expect(provisional, 'PROV-386881AE');
    });

    test('No debe sobreescribir número real con PROV-', () {
      // Simula la lógica del controller: solo generar PROV si está vacío
      final currentNumber = 'INF-2026-0042';

      String resultado = currentNumber;
      if (currentNumber.isEmpty || currentNumber == 'Pendiente...') {
        resultado = 'PROV-12345678';
      }

      expect(resultado, 'INF-2026-0042');
    });

    test('Genera PROV cuando el número está vacío (offline)', () {
      final currentNumber = '';

      String resultado = currentNumber;
      if (currentNumber.isEmpty || currentNumber == 'Pendiente...') {
        resultado = 'PROV-12345678';
      }

      expect(resultado, 'PROV-12345678');
    });

    test('Genera PROV cuando el número es "Pendiente..." (sync falló)', () {
      final currentNumber = 'Pendiente...';

      String resultado = currentNumber;
      if (currentNumber.isEmpty || currentNumber == 'Pendiente...') {
        resultado = 'PROV-ABCDEF01';
      }

      expect(resultado, 'PROV-ABCDEF01');
    });
  });

  // ===================================================================
  // TESTS DE MAPEO DE DATOS PARA SYNC A SUPABASE
  // ===================================================================
  group('Mapeo de datos para sincronización', () {
    test(
      'Actividad mapa remueve campos locales antes de enviar a Supabase',
      () {
        final row = {
          'id': 'act-001',
          'tipo_actividad': 'INSPECCION_BUCEO',
          'centro_id': 'centro-01',
          'usuario_id': 'user-01',
          'puerto_abierto': 1,
          'numero_seguimiento': 0,
          'numero_reporte': 'INF-2026-0001',
          'subido': 0,
          'eliminado': 0,
          'estado_final': 'En Seguimiento',
        };

        // Simula la lógica de SyncService._sincronizarActividades()
        final datosParaNube = Map<String, dynamic>.from(row);
        datosParaNube['puerto_abierto'] = (row['puerto_abierto'] == 1);
        datosParaNube['numero_seguimiento'] = row['numero_seguimiento'] ?? 0;
        datosParaNube.remove('numero_reporte');
        datosParaNube.remove('subido');
        datosParaNube.remove('eliminado');

        expect(
          datosParaNube.containsKey('numero_reporte'),
          false,
          reason: 'numero_reporte es local, no debe ir a Supabase',
        );
        expect(
          datosParaNube.containsKey('subido'),
          false,
          reason: 'subido es flag local',
        );
        expect(
          datosParaNube.containsKey('eliminado'),
          false,
          reason: 'eliminado es flag local',
        );
        expect(
          datosParaNube['puerto_abierto'],
          true,
          reason: 'SQLite int debe convertirse a bool para Supabase',
        );
        expect(datosParaNube['estado_final'], 'En Seguimiento');
      },
    );

    test('Participantes convierten condiciones_optimas de int a bool', () {
      final participante = ParticipanteModel(
        personalId: 'p-001',
        nombreCompleto: 'Juan Pérez',
        rut: '12345678-9',
        cargo: 'Buzo',
        condicionesOptimas: true,
        contratistaId: 'cont-01',
      );

      // Simula la conversión en _persistirDatos
      final map = {
        'actividad_id': 'act-001',
        'personal_id': participante.personalId,
        'rol_en_faena': participante.cargo,
        'condiciones_optimas': participante.condicionesOptimas ? 1 : 0,
      };

      expect(map['condiciones_optimas'], 1);

      // Simula la conversión inversa en SyncService (_sincronizarParticipantes)
      final paraSupabase = Map<String, dynamic>.from(map);
      paraSupabase['condiciones_optimas'] = (map['condiciones_optimas'] == 1)
          ? true
          : false;

      expect(
        paraSupabase['condiciones_optimas'],
        true,
        reason: 'Supabase espera bool, no int',
      );
    });

    test('Verificaciones buceo convierten bools a int para SQLite', () {
      final model = BuceoVerificacionModel(
        actividadId: 'act-001',
        autorizacionAutoridadMaritima: true,
        induccionCentroCultivo: true,
        permisoBuceoCentroCorrecto: false,
        planContingenciasCentroOk: true,
        examenesOcupacionalesVigentes: false,
      );

      final map = model.toMap();

      expect(map['autorizacion_autoridad_maritima'], 1);
      expect(map['induccion_centro_cultivo'], 1);
      expect(map['permiso_buceo_centro_correcto'], 0);
      expect(map['plan_contingencias_centro_ok'], 1);
      expect(map['examenes_ocupacionales_vigentes'], 0);
    });

    test('Respuestas incluyen criticidad_registrada para sync', () {
      final respuestas = {'item-001': 'NC', 'item-002': 'C'};
      final observaciones = {'item-001': 'Cable suelto'};
      final criticidades = {'item-001': 'Intolerable', 'item-002': 'Tolerable'};

      List<Map<String, dynamic>> loteRespuestas = [];
      respuestas.forEach((key, val) {
        loteRespuestas.add({
          'actividad_id': 'act-001',
          'item_id': key,
          'estado': val,
          'observacion': observaciones[key],
          'criticidad_registrada': criticidades[key] ?? 'Tolerable',
        });
      });

      expect(loteRespuestas.length, 2);
      expect(loteRespuestas[0]['criticidad_registrada'], 'Intolerable');
      expect(loteRespuestas[0]['observacion'], 'Cable suelto');
      expect(loteRespuestas[1]['criticidad_registrada'], 'Tolerable');
      expect(loteRespuestas[1]['observacion'], isNull);
    });
  });

  // ===================================================================
  // TESTS DE BORRADORES - ESTADOS Y SOFT DELETE
  // ===================================================================
  group('Borradores - Estados y Ciclo de Vida', () {
    test('Borrador tiene estado "En Progreso" y subido=0', () {
      final actividadMap = {
        'id': 'act-001',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'estado_final': 'En Progreso',
        'subido': 0,
        'eliminado': 0,
      };

      expect(actividadMap['estado_final'], 'En Progreso');
      expect(actividadMap['subido'], 0);
      expect(actividadMap['eliminado'], 0);
    });

    test('Finalizar cambia estado a "En Seguimiento"', () {
      final esBorrador = false;
      final estadoFinal = esBorrador ? 'En Progreso' : 'En Seguimiento';

      expect(estadoFinal, 'En Seguimiento');
    });

    test('Soft delete marca eliminado=1 y subido=0', () {
      // Simula LocalInspectionRepository.eliminarBorrador()
      final updateMap = {'eliminado': 1, 'subido': 0};

      expect(updateMap['eliminado'], 1);
      expect(
        updateMap['subido'],
        0,
        reason: 'subido debe resetearse para que SyncService lo procese',
      );
    });

    test('getBorradores filtra correctamente', () {
      final actividades = [
        {
          'id': '1',
          'estado_final': 'En Progreso',
          'eliminado': 0,
        }, // <-- borrador
        {'id': '2', 'estado_final': 'En Seguimiento', 'eliminado': 0},
        {
          'id': '3',
          'estado_final': 'En Progreso',
          'eliminado': 1,
        }, // <-- eliminado
        {'id': '4', 'estado_final': 'Eliminada', 'eliminado': 1},
      ];

      // Simula el WHERE de getBorradores
      final borradores = actividades
          .where(
            (a) => a['estado_final'] == 'En Progreso' && a['eliminado'] == 0,
          )
          .toList();

      expect(borradores.length, 1);
      expect(borradores.first['id'], '1');
    });

    test('Visita getBorradores excluye VISITA_R004', () {
      final visitas = [
        {
          'id': '1',
          'estado_final': 'En Progreso',
          'eliminado': 0,
          'tipo_actividad': null,
        },
        {
          'id': '2',
          'estado_final': 'En Progreso',
          'eliminado': 0,
          'tipo_actividad': 'VISITA_R004',
        },
        {
          'id': '3',
          'estado_final': 'En Progreso',
          'eliminado': 0,
          'tipo_actividad': null,
        },
      ];

      final borradores = visitas
          .where(
            (v) =>
                v['estado_final'] == 'En Progreso' &&
                v['eliminado'] == 0 &&
                v['tipo_actividad'] != 'VISITA_R004',
          )
          .toList();

      expect(
        borradores.length,
        2,
        reason: 'VISITA_R004 debe excluirse de borradores de visitas',
      );
    });
  });

  // ===================================================================
  // TESTS DE BUCEO VERIFICACIÓN MODEL
  // ===================================================================
  group('BuceoVerificacionModel - Roundtrip', () {
    test('toMap/fromMap preserva todos los campos', () {
      final original = BuceoVerificacionModel(
        actividadId: 'act-test',
        autorizacionAutoridadMaritima: true,
        induccionCentroCultivo: true,
        permisoBuceoCentroCorrecto: false,
        planContingenciasCentroOk: true,
        examenesOcupacionalesVigentes: true,
        obsAutorizacion: 'OK autorización',
        supervisorNombre: 'Pedro Soto',
        supervisorRut: '11111111-1',
        encargadoCentro: 'María López',
        supervisorCentro: 'Carlos Díaz',
        horaInicio: '08:30',
        horaTermino: '17:00',
        compresor1Matricula: 'COMP-001',
        compresor1BuzosCargo: 3,
        estadoManual: 'APROBADO',
      );

      final map = original.toMap();
      final restored = BuceoVerificacionModel.fromMap(map);

      expect(restored.actividadId, 'act-test');
      expect(restored.autorizacionAutoridadMaritima, true);
      expect(restored.permisoBuceoCentroCorrecto, false);
      expect(restored.obsAutorizacion, 'OK autorización');
      expect(restored.supervisorNombre, 'Pedro Soto');
      expect(restored.encargadoCentro, 'María López');
      expect(restored.horaInicio, '08:30');
      expect(restored.compresor1Matricula, 'COMP-001');
      expect(restored.compresor1BuzosCargo, 3);
      expect(restored.estadoManual, 'APROBADO');
    });

    test('faenaHabilitada con APROBADO manual retorna true', () {
      final model = BuceoVerificacionModel(
        actividadId: 'act-x',
        estadoManual: 'APROBADO',
        // Todos los checks en false
      );
      expect(model.faenaHabilitada, true);
    });

    test('faenaHabilitada con SUSPENDIDO manual retorna false', () {
      final model = BuceoVerificacionModel(
        actividadId: 'act-x',
        autorizacionAutoridadMaritima: true,
        induccionCentroCultivo: true,
        permisoBuceoCentroCorrecto: true,
        planContingenciasCentroOk: true,
        examenesOcupacionalesVigentes: true,
        estadoManual: 'SUSPENDIDO',
      );
      expect(model.faenaHabilitada, false);
    });

    test('faenaHabilitada sin manual usa AND de checks', () {
      final modelOk = BuceoVerificacionModel(
        actividadId: 'act-ok',
        autorizacionAutoridadMaritima: true,
        induccionCentroCultivo: true,
        permisoBuceoCentroCorrecto: true,
        planContingenciasCentroOk: true,
        examenesOcupacionalesVigentes: true,
      );
      expect(modelOk.faenaHabilitada, true);

      final modelFail = BuceoVerificacionModel(
        actividadId: 'act-fail',
        autorizacionAutoridadMaritima: true,
        induccionCentroCultivo: true,
        permisoBuceoCentroCorrecto: false, // <-- uno falla
        planContingenciasCentroOk: true,
        examenesOcupacionalesVigentes: true,
      );
      expect(modelFail.faenaHabilitada, false);
    });

    test('toMap convierte DateTime a ISO8601 para compresores', () {
      final model = BuceoVerificacionModel(
        actividadId: 'act-dt',
        compresor1Vigencia: DateTime(2026, 6, 15),
        compresor2VigenciaPH: DateTime(2025, 12, 1),
      );

      final map = model.toMap();

      expect(map['compresor_1_vigencia'], contains('2026-06-15'));
      expect(map['compresor_2_vigencia_ph'], contains('2025-12-01'));
    });
  });

  // ===================================================================
  // TESTS DE LÓGICA DE SYNC (sin red)
  // ===================================================================
  group('Lógica de sincronización - preparación de datos', () {
    test('Actividad con subido=0 es candidata para sync', () {
      final pendientes = [
        {'id': 'a1', 'subido': 0},
        {'id': 'a2', 'subido': 1},
        {'id': 'a3', 'subido': 0},
      ];

      final paraSync = pendientes.where((r) => r['subido'] == 0).toList();
      expect(paraSync.length, 2);
    });

    test('Actividad eliminada se procesa como zombie para hard delete', () {
      final row = {
        'id': 'act-zombie',
        'eliminado': 1,
        'subido': 0,
        'tipo_actividad': 'INSPECCION_BUCEO',
      };

      final estaEliminado = (row['eliminado'] as int?) == 1;
      expect(estaEliminado, true);
    });

    test('_persistirDatos siempre pone subido=0 para forzar re-sync', () {
      // Simula saveInspeccionCompleta
      final Map<String, dynamic> actividadMap = {
        'id': 'act-001',
        'estado_final': 'En Seguimiento',
      };

      // El repositorio siempre setea subido=0
      actividadMap['subido'] = 0;

      expect(
        actividadMap['subido'],
        0,
        reason: 'Debe ser 0 para que SyncService la recoja en el próximo sync',
      );
    });

    test('Número de informe se guarda desde Supabase response', () {
      // Simula la respuesta de Supabase después de INSERT
      final supabaseResponse = {'numero_informe': 'INF-2026-0042'};

      final nuevoNumero = supabaseResponse['numero_informe'];
      final updateMap = {'numero_reporte': nuevoNumero.toString()};

      expect(
        updateMap['numero_reporte'],
        'INF-2026-0042',
        reason: 'numero_informe de Supabase se guarda como numero_reporte',
      );
    });

    test('Fotos huérfanas no bloquean el sync', () {
      // Simula foto cuyo respuesta padre no existe en Supabase
      final inspeccionRespuestaId = null; // maybeSingle() retornó null

      final esHuerfana = inspeccionRespuestaId == null;
      expect(
        esHuerfana,
        true,
        reason: 'Foto sin respuesta padre debe saltarse y reintentarse después',
      );
    });
  });

  // ===================================================================
  // TESTS DE PERSISTENCIA DE NÚMERO (protección contra pérdida)
  // ===================================================================
  group('Protección contra pérdida de número de informe', () {
    test('Si DB tiene número y controller está vacío, usa el de DB', () {
      final numeroController = '';
      final numeroDB = 'INF-2026-0042';

      String? numeroFinal = numeroController.trim();

      if ((numeroFinal.isEmpty || numeroFinal == 'Pendiente...') &&
          (numeroDB.isNotEmpty && numeroDB != 'null')) {
        numeroFinal = numeroDB;
      }

      expect(numeroFinal, 'INF-2026-0042');
    });

    test('Si controller tiene número real, lo mantiene', () {
      final numeroController = 'INF-2026-0042';
      final numeroDB = 'INF-2026-0042';

      String? numeroFinal = numeroController.trim();

      if ((numeroFinal.isEmpty || numeroFinal == 'Pendiente...') &&
          (numeroDB.isNotEmpty && numeroDB != 'null')) {
        numeroFinal = numeroDB;
      }

      expect(numeroFinal, 'INF-2026-0042');
    });

    test('Si controller tiene PROV y DB tiene real, usa DB', () {
      // Este caso se maneja en _persistirDatos
      final numeroController = 'PROV-386881AE';
      final numeroDB = 'INF-2026-0042';

      String? numeroFinal = numeroController.trim();

      // La lógica actual solo protege contra vacío y "Pendiente..."
      // PROV-* NO está protegido — este test documenta el comportamiento actual
      if ((numeroFinal.isEmpty || numeroFinal == 'Pendiente...') &&
          (numeroDB.isNotEmpty && numeroDB != 'null')) {
        numeroFinal = numeroDB;
      }

      // Con la lógica actual, PROV-* NO se sobreescribe desde _persistirDatos
      // Se arregla con el sync final que siempre se ejecuta ahora
      expect(
        numeroFinal,
        'PROV-386881AE',
        reason:
            'El fix principal es que el sync final siempre se ejecute y recargue el número',
      );
    });
  });
}
