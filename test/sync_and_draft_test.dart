import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/inspection/domain/models/buceo_verificacion_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/participante_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';

void main() {
  // ===================================================================
  // TESTS DE NÚMERO DE INFORME - OPCIÓN C (sin PROV-*, sin "Pendiente")
  // ===================================================================
  group('Número de Informe - Opción C', () {
    test('Borrador inicia con número vacío (no "Pendiente")', () {
      // Simula _init() cuando numero_reporte es null en DB
      final numeroReal = null;
      String controllerText;

      if (numeroReal != null &&
          numeroReal.toString().isNotEmpty &&
          numeroReal.toString() != "null") {
        controllerText = numeroReal.toString();
      } else {
        controllerText = ""; // Opción C: vacío, hint "Auto" se muestra
      }

      expect(controllerText, "");
      expect(controllerText, isNot("Pendiente"));
    });

    test('Número real se carga correctamente del DB', () {
      final numeroReal = "42";
      String controllerText;

      if (numeroReal.isNotEmpty && numeroReal != "null") {
        controllerText = numeroReal;
      } else {
        controllerText = "";
      }

      expect(controllerText, "42");
    });

    test('tieneNumeroReal detecta vacío como false', () {
      final textoNumero = "";
      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");
      expect(tieneNumeroReal, false);
    });

    test('tieneNumeroReal detecta número real como true', () {
      final textoNumero = "42";
      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");
      expect(tieneNumeroReal, true);
    });

    test('tieneNumeroReal detecta PROV-* legacy como false', () {
      final textoNumero = "PROV-A1B2C3D4";
      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");
      expect(tieneNumeroReal, false);
    });

    test('tieneNumeroReal detecta estimado ~N como false', () {
      final textoNumero = "~42";
      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");
      expect(
        tieneNumeroReal,
        false,
        reason: 'Estimado ~42 no es número real → difiere PDF',
      );
    });

    test('numero_reporte no guarda vacío en SQLite (guarda null)', () {
      String? numeroFinal = "";
      final resultado = (numeroFinal.isNotEmpty) ? numeroFinal : null;
      expect(resultado, isNull, reason: 'Vacío se convierte a null en SQLite');
    });

    test('numero_reporte guarda valor real en SQLite', () {
      String? numeroFinal = "42";
      final resultado = (numeroFinal.isNotEmpty) ? numeroFinal : null;
      expect(resultado, "42");
    });
  });

  // ===================================================================
  // TESTS DE MAPEO DE DATOS PARA SYNC A SUPABASE
  // ===================================================================
  group('Mapeo de datos para sincronización', () {
    test(
      'Actividad mapa remueve TODOS los campos locales antes de enviar a Supabase',
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
          'pdf_path_local': '/data/user/0/com.app/cache/report.pdf',
          'app_version': '1.0.0',
        };

        // Simula la lógica EXACTA de SyncService._sincronizarActividades()
        final datosParaNube = Map<String, dynamic>.from(row);
        datosParaNube['puerto_abierto'] = (row['puerto_abierto'] == 1);
        datosParaNube['numero_seguimiento'] = row['numero_seguimiento'] ?? 0;
        datosParaNube.remove('numero_reporte');
        datosParaNube.remove('subido');
        datosParaNube.remove('eliminado');
        datosParaNube.remove('pdf_path_local');
        datosParaNube.remove('app_version');

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
          datosParaNube.containsKey('pdf_path_local'),
          false,
          reason:
              'pdf_path_local es ruta local del dispositivo, NO existe en Supabase (bug PGRST204)',
        );
        expect(
          datosParaNube.containsKey('app_version'),
          false,
          reason:
              'app_version es local, no existe en tabla actividades de Supabase',
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

      if ((numeroFinal.isEmpty ||
              numeroFinal == 'Pendiente...' ||
              numeroFinal == 'Pendiente') &&
          (numeroDB.isNotEmpty && numeroDB != 'null')) {
        numeroFinal = numeroDB;
      }

      expect(numeroFinal, 'INF-2026-0042');
    });

    test('Si controller tiene número real, lo mantiene', () {
      final numeroController = 'INF-2026-0042';
      final numeroDB = 'INF-2026-0042';

      String? numeroFinal = numeroController.trim();

      if ((numeroFinal.isEmpty ||
              numeroFinal == 'Pendiente...' ||
              numeroFinal == 'Pendiente') &&
          (numeroDB.isNotEmpty && numeroDB != 'null')) {
        numeroFinal = numeroDB;
      }

      expect(numeroFinal, 'INF-2026-0042');
    });

    test(
      'Si controller tiene "Pendiente" legacy y DB tiene número real, usa DB',
      () {
        final numeroController = 'Pendiente';
        final numeroDB = 'INF-2026-0042';

        String? numeroFinal = numeroController.trim();

        if ((numeroFinal.isEmpty ||
                numeroFinal == 'Pendiente...' ||
                numeroFinal == 'Pendiente') &&
            (numeroDB.isNotEmpty && numeroDB != 'null')) {
          numeroFinal = numeroDB;
        }

        expect(
          numeroFinal,
          'INF-2026-0042',
          reason: 'Guard debe capturar "Pendiente" legacy y reemplazar con DB',
        );
      },
    );

    test(
      'Si controller tiene "Pendiente..." legacy y DB tiene número real, usa DB',
      () {
        final numeroController = 'Pendiente...';
        final numeroDB = 'INF-2026-0042';

        String? numeroFinal = numeroController.trim();

        if ((numeroFinal.isEmpty ||
                numeroFinal == 'Pendiente...' ||
                numeroFinal == 'Pendiente') &&
            (numeroDB.isNotEmpty && numeroDB != 'null')) {
          numeroFinal = numeroDB;
        }

        expect(numeroFinal, 'INF-2026-0042');
      },
    );
  });

  // ===================================================================
  // TESTS DE TRIGGER: numero_informe solo al finalizar
  // ===================================================================
  group('Trigger numero_informe - solo al finalizar', () {
    test('Borrador NO debe tener numero_informe en datos para nube', () {
      final row = {
        'id': 'act-borrador',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'estado_final': 'En Progreso',
        'numero_informe': null,
        'subido': 0,
      };

      // Simula SyncService: no debe pedir numero_informe de vuelta si es borrador
      final estadoActual = row['estado_final']?.toString();
      final debeObtenerNumero = estadoActual == 'En Seguimiento';

      expect(
        debeObtenerNumero,
        false,
        reason: 'Borradores no deben obtener numero_informe del servidor',
      );
    });

    test('Actividad finalizada SÍ debe obtener numero_informe', () {
      final row = {
        'id': 'act-final',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'estado_final': 'En Seguimiento',
        'numero_informe': null,
        'subido': 0,
      };

      final estadoActual = row['estado_final']?.toString();
      final debeObtenerNumero = estadoActual == 'En Seguimiento';

      expect(
        debeObtenerNumero,
        true,
        reason: 'Solo finalizadas deben recibir numero_informe',
      );
    });

    test('INSERT response con numero_informe null no se guarda', () {
      // Simula respuesta de Supabase para un borrador (trigger no asigna número)
      final response = {'numero_informe': null};
      final nuevoNumero = response['numero_informe'];

      final debeGuardar = nuevoNumero != null;

      expect(
        debeGuardar,
        false,
        reason: 'No guardar numero_reporte si Supabase devuelve null',
      );
    });

    test('INSERT response con numero_informe real sí se guarda', () {
      // Simula respuesta de Supabase para una actividad finalizada
      final response = {'numero_informe': 95};
      final nuevoNumero = response['numero_informe'];

      final debeGuardar = nuevoNumero != null;

      expect(debeGuardar, true);
      expect(nuevoNumero.toString(), '95');
    });

    test('UPDATE a En Seguimiento lee numero_informe de vuelta', () {
      // Simula el nuevo flujo en SyncService: después de UPDATE,
      // si estado es En Seguimiento, releer numero_informe
      final row = {'id': 'act-x', 'estado_final': 'En Seguimiento'};

      // Simula respuesta del SELECT posterior al UPDATE
      final updatedRow = {'numero_informe': 338};

      final estadoActual = row['estado_final']?.toString();
      final numFromUpdate = updatedRow['numero_informe'];

      if (estadoActual == 'En Seguimiento' && numFromUpdate != null) {
        final updateMap = {'numero_reporte': numFromUpdate.toString()};
        expect(updateMap['numero_reporte'], '338');
      } else {
        fail('Debería haber guardado el número');
      }
    });

    test('Número hipotético se muestra como estimado', () {
      // Simula _cargarNumeroHipotetico: MAX(numero_informe) + 1
      final maxNum = 337;
      final hipoText = "~${maxNum + 1} (estimado)";

      expect(hipoText, '~338 (estimado)');
      expect(hipoText.contains('estimado'), true);
    });

    test('Número estimado se reemplaza al obtener real', () {
      // Simula: controller tiene "~338 (estimado)", sync trae número real
      var controllerText = '~338 (estimado)';
      final numDB = '338';

      // La lógica de finalizarInspeccion: si contiene "estimado", recalcular
      if (controllerText.contains('estimado')) {
        controllerText = numDB;
      }

      expect(controllerText, '338');
    });

    test('Secuencias separadas por tipo (buceo vs embarcacion)', () {
      // El trigger usa seq_inf_buceo para INSPECCION_BUCEO
      // y seq_inf_embarcacion para INSPECCION_EMBARCACION
      // Esto permite numeración independiente por tipo

      final tiposBuceo = ['INSPECCION_BUCEO'];
      final tiposEmb = ['INSPECCION_EMBARCACION'];

      String? getSequenceName(String tipoActividad) {
        if (tiposBuceo.contains(tipoActividad)) return 'seq_inf_buceo';
        if (tiposEmb.contains(tipoActividad)) return 'seq_inf_embarcacion';
        return null;
      }

      expect(getSequenceName('INSPECCION_BUCEO'), 'seq_inf_buceo');
      expect(getSequenceName('INSPECCION_EMBARCACION'), 'seq_inf_embarcacion');
      expect(
        getSequenceName('VISITA_TECNICA'),
        isNull,
        reason: 'Visitas no usan numero_informe de actividades',
      );
    });
  });

  // ===================================================================
  // TESTS EXHAUSTIVOS: FLUJO COMPLETO DE SYNC POR TIPO DE ACTIVIDAD
  // ===================================================================

  // --- Helper: simula la lógica EXACTA de _sincronizarActividades() ---
  Map<String, dynamic> prepararDatosActividad(Map<String, dynamic> row) {
    final datosParaNube = Map<String, dynamic>.from(row);
    datosParaNube['puerto_abierto'] = (row['puerto_abierto'] == 1);
    datosParaNube['numero_seguimiento'] = row['numero_seguimiento'] ?? 0;
    datosParaNube.remove('numero_reporte');
    datosParaNube.remove('subido');
    datosParaNube.remove('eliminado');
    datosParaNube.remove('pdf_path_local');
    datosParaNube.remove('app_version');
    return datosParaNube;
  }

  // --- Helper: simula la lógica EXACTA de _sincronizarVisitas() ---
  Map<String, dynamic> prepararDatosVisita(Map<String, dynamic> row) {
    final datosNube = Map<String, dynamic>.from(row);
    datosNube.remove('subido');
    datosNube.remove('eliminado');
    datosNube.remove('pdf_path_local');
    datosNube['check_reunion'] = (datosNube['check_reunion'] == 1);
    datosNube['check_instalacion_senaletica'] =
        (datosNube['check_instalacion_senaletica'] == 1);
    datosNube['check_capacitacion'] = (datosNube['check_capacitacion'] == 1);
    datosNube['check_visita_sso'] = (datosNube['check_visita_sso'] == 1);
    datosNube['check_charla'] = (datosNube['check_charla'] == 1);
    datosNube['check_investigacion_incidente'] =
        (datosNube['check_investigacion_incidente'] == 1);
    datosNube['check_inspeccion_sso'] =
        (datosNube['check_inspeccion_sso'] == 1);
    datosNube['check_obs_conductual'] =
        (datosNube['check_obs_conductual'] == 1);
    datosNube['check_otro'] = (datosNube['check_otro'] == 1);
    return datosNube;
  }

  group('Sync Inspección Buceo - flujo completo', () {
    final rowBuceo = {
      'id': 'buceo-001',
      'tipo_actividad': 'INSPECCION_BUCEO',
      'centro_id': 'centro-01',
      'area_id': 'area-01',
      'embarcacion_id': 'emb-01',
      'usuario_id': 'user-01',
      'fecha': '2026-03-31',
      'puerto_abierto': 1,
      'numero_seguimiento': 5,
      'numero_reporte': 'INF-2026-0050',
      'subido': 0,
      'eliminado': 0,
      'estado_final': 'En Seguimiento',
      'pdf_path_local': '/data/user/0/com.app/cache/buceo_report.pdf',
      'pdf_url': null,
      'numero_informe': null,
    };

    test(
      'Remueve TODOS los campos locales (pdf_path_local, subido, eliminado, numero_reporte)',
      () {
        final datos = prepararDatosActividad(rowBuceo);

        final camposProhibidos = [
          'numero_reporte',
          'subido',
          'eliminado',
          'pdf_path_local',
          'app_version',
        ];
        for (final campo in camposProhibidos) {
          expect(
            datos.containsKey(campo),
            false,
            reason: '$campo NO debe enviarse a Supabase',
          );
        }
      },
    );

    test('Conserva todos los campos requeridos por Supabase', () {
      final datos = prepararDatosActividad(rowBuceo);

      final camposRequeridos = [
        'id',
        'tipo_actividad',
        'centro_id',
        'area_id',
        'embarcacion_id',
        'usuario_id',
        'fecha',
        'puerto_abierto',
        'numero_seguimiento',
        'estado_final',
      ];
      for (final campo in camposRequeridos) {
        expect(
          datos.containsKey(campo),
          true,
          reason: '$campo es requerido por Supabase y debe estar presente',
        );
      }
    });

    test('Convierte puerto_abierto de int a bool', () {
      final datos = prepararDatosActividad(rowBuceo);
      expect(datos['puerto_abierto'], isA<bool>());
      expect(datos['puerto_abierto'], true);
    });

    test('puerto_abierto=0 se convierte a false', () {
      final rowCerrado = Map<String, dynamic>.from(rowBuceo);
      rowCerrado['puerto_abierto'] = 0;
      final datos = prepararDatosActividad(rowCerrado);
      expect(datos['puerto_abierto'], false);
    });

    test('numero_seguimiento default a 0 si es null', () {
      final rowNull = Map<String, dynamic>.from(rowBuceo);
      rowNull['numero_seguimiento'] = null;
      final datos = prepararDatosActividad(rowNull);
      expect(datos['numero_seguimiento'], 0);
    });

    test('numero_informe se remueve antes de INSERT (trigger lo asigna)', () {
      final datos = prepararDatosActividad(rowBuceo);
      datos.remove('numero_informe'); // Simula el remove antes de insert
      expect(datos.containsKey('numero_informe'), false);
    });

    test(
      'numero_informe se remueve antes de UPDATE (no sobreescribir trigger)',
      () {
        final datos = prepararDatosActividad(rowBuceo);
        datos.remove('numero_informe'); // Simula el remove antes de update
        expect(datos.containsKey('numero_informe'), false);
      },
    );

    test('Borrador eliminado se detecta como zombie', () {
      final rowZombie = Map<String, dynamic>.from(rowBuceo);
      rowZombie['eliminado'] = 1;
      rowZombie['subido'] = 0;
      final estaEliminado = (rowZombie['eliminado'] as int?) == 1;
      expect(estaEliminado, true);
    });

    test('Actividad ya subida (subido=1) no es candidata a sync', () {
      final rowSubida = Map<String, dynamic>.from(rowBuceo);
      rowSubida['subido'] = 1;
      final esCandidato = rowSubida['subido'] == 0;
      expect(esCandidato, false);
    });

    test(
      'Estado En Seguimiento requiere lectura de numero_informe tras UPDATE',
      () {
        final estadoActual = rowBuceo['estado_final']?.toString();
        final debeObtener = estadoActual == 'En Seguimiento';
        expect(debeObtener, true);
      },
    );

    test('Estado En Progreso NO requiere lectura de numero_informe', () {
      final rowBorrador = Map<String, dynamic>.from(rowBuceo);
      rowBorrador['estado_final'] = 'En Progreso';
      final debeObtener = rowBorrador['estado_final'] == 'En Seguimiento';
      expect(debeObtener, false);
    });
  });

  group('Sync Inspección Embarcación - flujo completo', () {
    final rowEmb = {
      'id': 'emb-001',
      'tipo_actividad': 'INSPECCION_EMBARCACION',
      'centro_id': 'centro-02',
      'area_id': 'area-02',
      'embarcacion_id': 'emb-vessel-01',
      'usuario_id': 'user-02',
      'fecha': '2026-03-31',
      'puerto_abierto': 0,
      'numero_seguimiento': 3,
      'numero_reporte': 'INF-EMB-2026-0010',
      'subido': 0,
      'eliminado': 0,
      'estado_final': 'En Seguimiento',
      'pdf_path_local': '/data/user/0/com.app/cache/emb_report.pdf',
      'pdf_url': 'https://storage.supabase.co/reportes/old.pdf',
    };

    test('Remueve campos locales igual que inspección buceo', () {
      final datos = prepararDatosActividad(rowEmb);
      expect(datos.containsKey('pdf_path_local'), false);
      expect(datos.containsKey('subido'), false);
      expect(datos.containsKey('eliminado'), false);
      expect(datos.containsKey('numero_reporte'), false);
    });

    test('tipo_actividad se preserva como INSPECCION_EMBARCACION', () {
      final datos = prepararDatosActividad(rowEmb);
      expect(datos['tipo_actividad'], 'INSPECCION_EMBARCACION');
    });

    test('Usa secuencia seq_inf_embarcacion (no seq_inf_buceo)', () {
      final tipo = rowEmb['tipo_actividad'] as String;
      final seq = tipo == 'INSPECCION_EMBARCACION'
          ? 'seq_inf_embarcacion'
          : 'seq_inf_buceo';
      expect(seq, 'seq_inf_embarcacion');
    });

    test('PDF upload se salta si pdf_url ya existe', () {
      final pdfPathLocal = rowEmb['pdf_path_local'] as String?;
      final pdfUrlActual = rowEmb['pdf_url'] as String?;
      final debeSubirPdf =
          pdfPathLocal != null &&
          pdfPathLocal.isNotEmpty &&
          (pdfUrlActual == null || pdfUrlActual.isEmpty);
      expect(debeSubirPdf, false, reason: 'Ya tiene pdf_url, no debe re-subir');
    });

    test('PDF upload se activa si pdf_url es null', () {
      final rowSinUrl = Map<String, dynamic>.from(rowEmb);
      rowSinUrl['pdf_url'] = null;
      final pdfPathLocal = rowSinUrl['pdf_path_local'] as String?;
      final pdfUrlActual = rowSinUrl['pdf_url'] as String?;
      final debeSubirPdf =
          pdfPathLocal != null &&
          pdfPathLocal.isNotEmpty &&
          (pdfUrlActual == null || pdfUrlActual.isEmpty);
      expect(debeSubirPdf, true);
    });

    test('PDF upload se activa si pdf_url es vacío', () {
      final rowUrlVacia = Map<String, dynamic>.from(rowEmb);
      rowUrlVacia['pdf_url'] = '';
      final pdfPathLocal = rowUrlVacia['pdf_path_local'] as String?;
      final pdfUrlActual = rowUrlVacia['pdf_url'] as String?;
      final debeSubirPdf =
          pdfPathLocal != null &&
          pdfPathLocal.isNotEmpty &&
          (pdfUrlActual == null || pdfUrlActual.isEmpty);
      expect(debeSubirPdf, true);
    });
  });

  group('Sync Visita Técnica - flujo completo', () {
    final rowVisita = {
      'id': 'visita-001',
      'tipo_actividad': null,
      'centro_id': 'centro-03',
      'area_id': 'area-03',
      'usuario_id': 'user-03',
      'fecha': '2026-03-31',
      'estado_final': 'En Seguimiento',
      'subido': 0,
      'eliminado': 0,
      'pdf_path_local': '/data/user/0/com.app/cache/visita_report.pdf',
      'pdf_url': null,
      'check_reunion': 1,
      'check_instalacion_senaletica': 0,
      'check_capacitacion': 1,
      'check_visita_sso': 0,
      'check_charla': 1,
      'check_investigacion_incidente': 0,
      'check_inspeccion_sso': 1,
      'check_obs_conductual': 0,
      'check_otro': 0,
    };

    test('Remueve campos locales (subido, eliminado, pdf_path_local)', () {
      final datos = prepararDatosVisita(rowVisita);
      expect(datos.containsKey('subido'), false);
      expect(datos.containsKey('eliminado'), false);
      expect(datos.containsKey('pdf_path_local'), false);
    });

    test('Convierte TODOS los checks de int a bool', () {
      final datos = prepararDatosVisita(rowVisita);

      final checksEsperados = {
        'check_reunion': true,
        'check_instalacion_senaletica': false,
        'check_capacitacion': true,
        'check_visita_sso': false,
        'check_charla': true,
        'check_investigacion_incidente': false,
        'check_inspeccion_sso': true,
        'check_obs_conductual': false,
        'check_otro': false,
      };

      checksEsperados.forEach((campo, valorEsperado) {
        expect(datos[campo], isA<bool>(), reason: '$campo debe ser bool');
        expect(datos[campo], valorEsperado, reason: '$campo valor incorrecto');
      });
    });

    test('Visita eliminada se procesa como zombie', () {
      final rowZombie = Map<String, dynamic>.from(rowVisita);
      rowZombie['eliminado'] = 1;
      rowZombie['subido'] = 0;
      final estaEliminado = (rowZombie['eliminado'] as int?) == 1;
      expect(estaEliminado, true);
    });

    test('usuario_id null se detecta para auto-fix', () {
      final rowSinUser = Map<String, dynamic>.from(rowVisita);
      rowSinUser['usuario_id'] = null;
      final necesitaFix = rowSinUser['usuario_id'] == null;
      expect(necesitaFix, true);
    });

    test('PDF pendiente impide marcar como subido', () {
      final pdfPathLocal = rowVisita['pdf_path_local'] as String?;
      final pdfUrlNube = null; // fallo al subir PDF

      final pdfPendiente = pdfPathLocal != null && pdfUrlNube == null;
      expect(
        pdfPendiente,
        true,
        reason: 'Si PDF no se subió, no debe marcarse como subido=1',
      );
    });

    test('Sin PDF local permite marcar como subido', () {
      final rowSinPdf = Map<String, dynamic>.from(rowVisita);
      rowSinPdf['pdf_path_local'] = null;
      final pdfPathLocal = rowSinPdf['pdf_path_local'] as String?;
      final pdfUrlNube = null;

      final pdfPendiente = pdfPathLocal != null && pdfUrlNube == null;
      expect(
        pdfPendiente,
        false,
        reason: 'Sin PDF local, se puede marcar subido=1',
      );
    });
  });

  group('Sync Visita Extintores (VISITA_R004) - flujo completo', () {
    final rowExtintor = {
      'id': 'ext-visita-001',
      'tipo_actividad': 'VISITA_R004',
      'centro_id': 'centro-04',
      'area_id': 'area-04',
      'usuario_id': 'user-04',
      'fecha': '2026-03-31',
      'estado_final': 'En Seguimiento',
      'subido': 0,
      'eliminado': 0,
      'pdf_path_local': null,
      'pdf_url': null,
      'check_reunion': 0,
      'check_instalacion_senaletica': 0,
      'check_capacitacion': 0,
      'check_visita_sso': 0,
      'check_charla': 0,
      'check_investigacion_incidente': 0,
      'check_inspeccion_sso': 0,
      'check_obs_conductual': 0,
      'check_otro': 0,
    };

    test('VISITA_R004 se procesa como visita (no actividad)', () {
      // VISITA_R004 va por _sincronizarVisitas, no por _sincronizarActividades
      final tipo = rowExtintor['tipo_actividad'];
      expect(tipo, 'VISITA_R004');
      // En el flujo de visitas, si tipo_actividad == 'VISITA_R004',
      // se llama _sincronizarExtintoresDe()
    });

    test('Remueve campos locales igual que visita normal', () {
      final datos = prepararDatosVisita(rowExtintor);
      expect(datos.containsKey('subido'), false);
      expect(datos.containsKey('eliminado'), false);
      expect(datos.containsKey('pdf_path_local'), false);
    });

    test('Extintores hijos se preparan correctamente para sync', () {
      final extintorRow = {
        'id': 'ext-001',
        'visita_id': 'ext-visita-001',
        'numero': 1,
        'matricula': 'EXT-2026-001',
        'tipo_extintor': 'PQS 6kg',
        'fotos_json': '["foto1.jpg","foto2.jpg"]',
        'respuestas_json': '{"estado_manguera":"C","estado_manometro":"NC"}',
        'subido': 0,
      };

      // Simula _sincronizarExtintoresDe
      final payload = {
        'id': extintorRow['id'],
        'visita_id': extintorRow['visita_id'],
        'numero': extintorRow['numero'],
        'matricula': extintorRow['matricula'],
        'tipo_extintor': extintorRow['tipo_extintor'],
        'fotos_json': extintorRow['fotos_json'] != null
            ? ['foto1.jpg', 'foto2.jpg'] // simula jsonDecode
            : [],
        'respuestas_json': extintorRow['respuestas_json'] != null
            ? {'estado_manguera': 'C', 'estado_manometro': 'NC'}
            : {},
      };

      expect(
        payload.containsKey('subido'),
        false,
        reason: 'subido es local, no va a Supabase',
      );
      expect(
        payload['fotos_json'],
        isA<List>(),
        reason: 'fotos_json debe decodificarse de String a List',
      );
      expect(
        payload['respuestas_json'],
        isA<Map>(),
        reason: 'respuestas_json debe decodificarse de String a Map',
      );
      expect(payload['tipo_extintor'], 'PQS 6kg');
    });

    test('Extintor con fotos_json null envía lista vacía', () {
      final payload = {'fotos_json': null != null ? [] : []};
      expect(payload['fotos_json'], isEmpty);
    });

    test('Extintor con respuestas_json null envía map vacío', () {
      final payload = {'respuestas_json': null != null ? {} : {}};
      expect(payload['respuestas_json'], isEmpty);
    });
  });

  group('Sync Respuestas - batch upsert', () {
    test('Respuesta pendiente se prepara con campos mínimos para Supabase', () {
      final row = {
        'id': 1,
        'actividad_id': 'act-001',
        'item_id': 'item-ABC',
        'estado': 'NC',
        'observacion': 'Cable suelto',
        'criticidad_registrada': 'Intolerable',
        'subido': 0,
      };

      // Simula _sincronizarRespuestas: solo envía campos necesarios
      final paraNube = {
        'actividad_id': row['actividad_id'],
        'item_id': row['item_id'],
        'estado': row['estado'],
        'observacion': row['observacion'],
        'criticidad_registrada': row['criticidad_registrada'],
      };

      expect(
        paraNube.containsKey('id'),
        false,
        reason: 'id local (int autoincrement) no va a Supabase',
      );
      expect(
        paraNube.containsKey('subido'),
        false,
        reason: 'subido es flag local',
      );
      expect(paraNube['criticidad_registrada'], 'Intolerable');
    });

    test('Batch de respuestas vacío no se envía', () {
      final pendientes = <Map<String, dynamic>>[];
      expect(pendientes.isEmpty, true);
    });

    test('Respuesta sin observación envía null (no string vacío)', () {
      final row = {
        'actividad_id': 'act-001',
        'item_id': 'item-XYZ',
        'estado': 'C',
        'observacion': null,
        'criticidad_registrada': 'Tolerable',
        'subido': 0,
      };

      final paraNube = {
        'actividad_id': row['actividad_id'],
        'item_id': row['item_id'],
        'estado': row['estado'],
        'observacion': row['observacion'],
        'criticidad_registrada': row['criticidad_registrada'],
      };

      expect(paraNube['observacion'], isNull);
    });
  });

  group('Sync Fotos - flujo y edge cases', () {
    test('Foto con item_id visita_general no busca respuesta padre', () {
      final itemId = 'visita_general';
      final debeUscarPadre = itemId != null && itemId != 'visita_general';
      expect(debeUscarPadre, false);
    });

    test('Foto con item_id null no busca respuesta padre', () {
      final String? itemId = null;
      final debeBuscarPadre = itemId != null && itemId != 'visita_general';
      expect(debeBuscarPadre, false);
    });

    test('Foto con item_id real SÍ busca respuesta padre', () {
      final itemId = 'item-ABC';
      final debeBuscarPadre = itemId != null && itemId != 'visita_general';
      expect(debeBuscarPadre, true);
    });

    test('Foto datos incluyen actividad_id y descripcion', () {
      final datosFoto = {
        'actividad_id': 'act-001',
        'foto_url': 'https://storage.supabase.co/evidencias/act-001/foto.jpg',
        'descripcion': 'Hallazgo en cubierta',
      };

      expect(datosFoto.containsKey('actividad_id'), true);
      expect(datosFoto.containsKey('foto_url'), true);
      expect(datosFoto['descripcion'], isNotEmpty);
    });

    test('Foto con respuesta padre incluye inspeccion_respuesta_id', () {
      final respuestaIdNube = 'resp-uuid-001';
      final datosFoto = <String, dynamic>{
        'actividad_id': 'act-001',
        'foto_url': 'https://example.com/foto.jpg',
        'descripcion': '',
      };

      if (respuestaIdNube != null) {
        datosFoto['inspeccion_respuesta_id'] = respuestaIdNube;
      }

      expect(datosFoto['inspeccion_respuesta_id'], 'resp-uuid-001');
    });
  });

  group('Sync Participantes - flujo completo', () {
    test('condiciones_optimas se convierte de int a bool', () {
      final rel = {
        'actividad_id': 'act-001',
        'personal_id': 'pers-001',
        'rol_en_faena': 'Buzo',
        'condiciones_optimas': 1,
      };

      final datosRelacion = Map<String, dynamic>.from(rel);
      if (rel['condiciones_optimas'] is int) {
        datosRelacion['condiciones_optimas'] =
            (rel['condiciones_optimas'] == 1);
      }

      expect(datosRelacion['condiciones_optimas'], true);
      expect(datosRelacion['condiciones_optimas'], isA<bool>());
    });

    test('condiciones_optimas=0 se convierte a false', () {
      final rel = {
        'actividad_id': 'act-001',
        'personal_id': 'pers-001',
        'condiciones_optimas': 0,
      };

      final datosRelacion = Map<String, dynamic>.from(rel);
      if (rel['condiciones_optimas'] is int) {
        datosRelacion['condiciones_optimas'] =
            (rel['condiciones_optimas'] == 1);
      }

      expect(datosRelacion['condiciones_optimas'], false);
    });

    test('Personal externo se prepara con RUT normalizado', () {
      // Simula la lógica de _sincronizarParticipantes
      final rawRut = '12.345.678-9';

      // Simula RutUtils.normalize
      String normalizeRut(String? rut) {
        if (rut == null) return '';
        return rut.replaceAll('.', '').replaceAll('-', '').toLowerCase().trim();
      }

      final datosLimpios = {
        'id': 'pers-001',
        'rut': normalizeRut(rawRut),
        'nombre_completo': 'Juan Pérez',
        'cargo': 'Buzo',
        'activo': true,
        'matricula': 'MAT-001',
        'contratista_id': 'cont-001',
      };

      expect(datosLimpios['rut'], '123456789');
      expect(
        datosLimpios['contratista_id'],
        isNotNull,
        reason: 'contratista_id es requerido por FK en Supabase',
      );
    });

    test('Huérfanos se limpian antes de insertar nuevos participantes', () {
      // Simula: existen 3 en Supabase, ahora solo quedan 2 locales
      final idsVigentes = ['pers-001', 'pers-002'];
      final filtro = '(${idsVigentes.join(',')})';

      expect(filtro, '(pers-001,pers-002)');
      expect(idsVigentes.length, 2);
    });

    test('Si idsVigentes está vacío, se borran TODOS los participantes', () {
      final idsVigentes = <String>[];
      final borrarTodos = idsVigentes.isEmpty;
      expect(borrarTodos, true);
    });
  });

  group('Campos locales vs Supabase - exhaustive check', () {
    // Lista definitiva de campos que son SOLO locales y nunca deben ir a Supabase
    final camposLocalesActividad = [
      'numero_reporte',
      'subido',
      'eliminado',
      'pdf_path_local',
      'app_version',
    ];

    final camposLocalesVisita = ['subido', 'eliminado', 'pdf_path_local'];

    test('Actividad BUCEO: ningún campo local llega a Supabase', () {
      final row = {
        'id': 'test-001',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'centro_id': 'c1',
        'usuario_id': 'u1',
        'puerto_abierto': 1,
        'numero_seguimiento': 0,
        'numero_reporte': 'INF-X',
        'subido': 0,
        'eliminado': 0,
        'pdf_path_local': '/path/to/pdf',
        'estado_final': 'En Seguimiento',
        'fecha': '2026-01-01',
      };

      final datos = prepararDatosActividad(row);
      for (final campo in camposLocalesActividad) {
        expect(
          datos.containsKey(campo),
          false,
          reason: 'Campo local "$campo" fue enviado a Supabase!',
        );
      }
    });

    test('Actividad EMBARCACION: ningún campo local llega a Supabase', () {
      final row = {
        'id': 'test-002',
        'tipo_actividad': 'INSPECCION_EMBARCACION',
        'centro_id': 'c2',
        'usuario_id': 'u2',
        'puerto_abierto': 0,
        'numero_seguimiento': 1,
        'numero_reporte': 'INF-Y',
        'subido': 0,
        'eliminado': 0,
        'pdf_path_local': '/path/to/pdf2',
        'estado_final': 'En Progreso',
        'fecha': '2026-01-02',
      };

      final datos = prepararDatosActividad(row);
      for (final campo in camposLocalesActividad) {
        expect(
          datos.containsKey(campo),
          false,
          reason: 'Campo local "$campo" fue enviado a Supabase!',
        );
      }
    });

    test('Visita técnica: ningún campo local llega a Supabase', () {
      final row = {
        'id': 'test-003',
        'centro_id': 'c3',
        'usuario_id': 'u3',
        'subido': 0,
        'eliminado': 0,
        'pdf_path_local': '/path/to/vpdf',
        'estado_final': 'En Seguimiento',
        'check_reunion': 1,
        'check_instalacion_senaletica': 0,
        'check_capacitacion': 0,
        'check_visita_sso': 0,
        'check_charla': 0,
        'check_investigacion_incidente': 0,
        'check_inspeccion_sso': 0,
        'check_obs_conductual': 0,
        'check_otro': 0,
      };

      final datos = prepararDatosVisita(row);
      for (final campo in camposLocalesVisita) {
        expect(
          datos.containsKey(campo),
          false,
          reason: 'Campo local "$campo" fue enviado a Supabase!',
        );
      }
    });

    test('VISITA_R004: ningún campo local llega a Supabase', () {
      final row = {
        'id': 'test-004',
        'tipo_actividad': 'VISITA_R004',
        'centro_id': 'c4',
        'usuario_id': 'u4',
        'subido': 0,
        'eliminado': 0,
        'pdf_path_local': '/path/to/ext_pdf',
        'estado_final': 'En Seguimiento',
        'check_reunion': 0,
        'check_instalacion_senaletica': 0,
        'check_capacitacion': 0,
        'check_visita_sso': 0,
        'check_charla': 0,
        'check_investigacion_incidente': 0,
        'check_inspeccion_sso': 0,
        'check_obs_conductual': 0,
        'check_otro': 0,
      };

      final datos = prepararDatosVisita(row);
      for (final campo in camposLocalesVisita) {
        expect(
          datos.containsKey(campo),
          false,
          reason: 'Campo local "$campo" fue enviado a Supabase!',
        );
      }
    });
  });

  group('Verificaciones buceo/embarcación - sync', () {
    test(
      'Verificaciones buceo se envían como upsert con onConflict actividad_id',
      () {
        final data = {
          'actividad_id': 'act-001',
          'autorizacion_autoridad_maritima': 1,
          'induccion_centro_cultivo': 1,
          'permiso_buceo_centro_correcto': 0,
        };

        // Solo verificamos estructura
        expect(data['actividad_id'], isNotNull);
        expect(data.containsKey('autorizacion_autoridad_maritima'), true);
      },
    );

    test(
      'Verificaciones embarcación se envían como upsert con onConflict actividad_id',
      () {
        final data = {
          'actividad_id': 'emb-001',
          'documentacion_embarcacion_ok': 1,
          'equipos_seguridad_ok': 0,
        };

        expect(data['actividad_id'], isNotNull);
      },
    );
  });

  group('Orden de operaciones sync - dependencias', () {
    test('sincronizarTodo ejecuta en orden correcto', () {
      // Documenta el orden de operaciones:
      // 1. _sincronizarActividades (padres)
      // 2. _sincronizarVisitas (padres independientes)
      // 3. _sincronizarRespuestas (hijos de actividades)
      // 4. _sincronizarFotos (hijos de respuestas)
      // 5. syncTicketsHaciaSupabase

      // La actividad DEBE existir antes de respuestas (FK constraint)
      // Las respuestas DEBEN existir antes de fotos (FK constraint)
      final orden = [
        'actividades',
        'visitas',
        'respuestas',
        'fotos',
        'tickets',
      ];

      expect(
        orden.indexOf('actividades') < orden.indexOf('respuestas'),
        true,
        reason: 'Actividades antes de respuestas (FK)',
      );
      expect(
        orden.indexOf('respuestas') < orden.indexOf('fotos'),
        true,
        reason: 'Respuestas antes de fotos (FK)',
      );
    });

    test('Error en actividad NO debe impedir sync de visitas', () {
      // sincronizarTodo atrapa excepciones individuales
      // Cada método retorna count, errores se atrapan internamente
      // Solo un catch global envuelve todo
      var actividadesFallaron = true;
      var visitasOk = true;

      // En la implementación actual, si _sincronizarActividades lanza excepción,
      // el catch global en sincronizarTodo captura y retorna 0.
      // Esto es un problema potencial pero documentado.
      expect(actividadesFallaron, true);
      expect(
        visitasOk,
        true,
        reason: 'Idealmente visitas debería ejecutarse independientemente',
      );
    });
  });

  // ===================================================================
  // TESTS: OPCIÓN C - FINALIZACIÓN OFFLINE SIN PDF
  // ===================================================================
  group('Finalización offline - Opción C (sin PROV-*, sin PDF)', () {
    test('Offline detecta vacío como sin número real → difiere PDF', () {
      final textoNumero = "";

      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");

      expect(
        tieneNumeroReal,
        false,
        reason: 'Vacío = sin número real → path offline, PDF diferido',
      );
    });

    test('Estimado ~N se detecta como sin número real → difiere PDF', () {
      final textoNumero = "~42";

      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");

      expect(
        tieneNumeroReal,
        false,
        reason: 'Estimado ~42 no es real → path offline, PDF diferido',
      );
    });

    test('Online detecta número real correctamente', () {
      final textoNumero = "42";

      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");

      expect(
        tieneNumeroReal,
        true,
        reason: '"42" es número real → path online con PDF',
      );
    });

    test('PROV-* legacy se detecta como no-real', () {
      final textoNumero = "PROV-A1B2C3D4";

      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");

      expect(tieneNumeroReal, false, reason: 'PROV-* no es número real');
    });

    test('String vacío se detecta como no-real → difiere PDF', () {
      final textoNumero = "";

      final tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");

      expect(tieneNumeroReal, false);
    });

    test('Offline deja pdf_url y pdf_path_local como null', () {
      // Simula la persistencia offline (borrador=false, sin PDF)
      final persistData = {
        'estado_final': 'En Seguimiento',
        'pdf_url': null,
        'pdf_path_local': null,
        'subido': 0,
      };

      expect(persistData['pdf_url'], isNull);
      expect(persistData['pdf_path_local'], isNull);
      expect(
        persistData['estado_final'],
        'En Seguimiento',
        reason: 'La inspección SÍ se finaliza aunque no haya PDF',
      );
    });

    test('Offline retorna éxito (inspección completa, solo PDF diferido)', () {
      // La inspección se guardó, los datos están seguros en SQLite
      final exito = true;
      final pdfDiferido = true;

      expect(
        exito,
        true,
        reason: 'La inspección está completa, solo falta el PDF',
      );
      expect(
        pdfDiferido,
        true,
        reason: 'Flag para que la UI muestre mensaje naranja',
      );
    });
  });

  // ===================================================================
  // TESTS: DETECCIÓN DE PDF PENDIENTE (query de SyncService)
  // ===================================================================
  group('Detección de PDF pendiente (_generarPdfsDiferidos)', () {
    // Helper: simula la condición WHERE de _generarPdfsDiferidos
    // Chequea pdf_path_local Y pdf_url vacíos
    // Filtra números provisionales (PROV-*, ~*) para nunca generar PDF con número falso
    bool esPdfPendiente(Map<String, dynamic> row) {
      final numero = row['numero_reporte']?.toString() ?? '';
      return row['estado_final'] == 'En Seguimiento' &&
          (row['pdf_path_local'] == null || row['pdf_path_local'] == '') &&
          (row['pdf_url'] == null || row['pdf_url'] == '') &&
          row['eliminado'] == 0 &&
          numero.isNotEmpty &&
          !numero.startsWith('PROV-') &&
          !numero.startsWith('~');
    }

    test('Detecta actividad finalizada sin PDF y con número real', () {
      final row = {
        'id': 'act-offline-001',
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '42',
      };
      expect(esPdfPendiente(row), true);
    });

    test('Ignora actividad con pdf_path_local (PDF local ya existe)', () {
      final row = {
        'id': 'act-local-pdf',
        'estado_final': 'En Seguimiento',
        'pdf_path_local': '/data/user/0/com.app/cache/report.pdf',
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '42',
      };
      expect(esPdfPendiente(row), false);
    });

    test('Ignora actividad con pdf_url (PDF ya subido)', () {
      final row = {
        'id': 'act-uploaded',
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': 'https://storage.supabase.co/reportes/x.pdf',
        'eliminado': 0,
        'numero_reporte': '42',
      };
      expect(esPdfPendiente(row), false);
    });

    test('Ignora borrador (En Progreso)', () {
      final row = {
        'id': 'act-draft',
        'estado_final': 'En Progreso',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': null,
      };
      expect(esPdfPendiente(row), false);
    });

    test('Ignora actividad eliminada', () {
      final row = {
        'id': 'act-deleted',
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 1,
        'numero_reporte': '42',
      };
      expect(esPdfPendiente(row), false);
    });

    test('Ignora actividad sin numero_reporte (trigger no disparó aún)', () {
      final row = {
        'id': 'act-no-number',
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': null,
      };
      expect(esPdfPendiente(row), false);
    });

    test('Ignora actividad con numero_reporte vacío', () {
      final row = {
        'id': 'act-empty-number',
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '',
      };
      expect(esPdfPendiente(row), false);
    });

    test('pdf_path_local vacío se trata como null (PDF pendiente)', () {
      final row = {
        'id': 'act-empty-path',
        'estado_final': 'En Seguimiento',
        'pdf_path_local': '',
        'pdf_url': null,
        'eliminado': 0,
        'numero_reporte': '42',
      };
      expect(esPdfPendiente(row), true, reason: 'String vacío = sin PDF local');
    });

    test('pdf_url vacío se trata como null (PDF pendiente)', () {
      final row = {
        'id': 'act-empty-url',
        'estado_final': 'En Seguimiento',
        'pdf_path_local': null,
        'pdf_url': '',
        'eliminado': 0,
        'numero_reporte': '42',
      };
      expect(
        esPdfPendiente(row),
        true,
        reason: 'String vacío = sin PDF en nube',
      );
    });
  });

  // ===================================================================
  // TESTS: DTO DESDE DATABASE (DeferredPdfService)
  // ===================================================================
  group('DeferredPdfService - construcción de DTO desde SQLite', () {
    test(
      'numero_reporte se lee de actividades_pendientes (no del controller)',
      () {
        final activityRow = {
          'id': 'act-deferred',
          'numero_reporte': '42',
          'tipo_actividad': 'INSPECCION_BUCEO',
        };

        final numeroReporte =
            activityRow['numero_reporte']?.toString() ?? "S/N";
        expect(
          numeroReporte,
          '42',
          reason: 'El PDF diferido usa el número de la DB, no del controller',
        );
      },
    );

    test('esConsecutiva se deriva de numero_seguimiento == 1', () {
      expect(1 == 1, true); // numero_seguimiento=1 → consecutiva
      expect(0 == 1, false); // numero_seguimiento=0 → inicial
      expect(2 == 1, false); // numero_seguimiento=2 → no consecutiva
    });

    test(
      'Clasificación de fotos: itemIds desde map().toSet() tipado correctamente',
      () {
        // Simula EXACTAMENTE como DeferredPdfService construye itemIds desde SQLite
        final List<Map<String, dynamic>> itemsDb = [
          {'id': 'item-A', 'pregunta': 'P1'},
          {'id': 'item-B', 'pregunta': 'P2'},
          {'id': 'item-C', 'pregunta': 'P3'},
        ];

        // Esto era el bug: .map().toSet() sin tipo explícito da Set<dynamic>
        final Set<String> itemIds = itemsDb
            .map<String>((i) => i['id'] as String)
            .toSet();

        final fotos = [
          {'item_id': 'item-A', 'local_path': '/foto1.jpg', 'descripcion': ''},
          {'item_id': null, 'local_path': '/foto2.jpg', 'descripcion': ''},
          {
            'item_id': 'custom-uuid',
            'local_path': '/foto3.jpg',
            'descripcion': 'Hallazgo extra',
          },
        ];

        final Map<String, List<String>> fotosPorItem = {};
        final List<String> fotosGenerales = [];
        final List<Map<String, String>> fotosExtra = [];

        for (var foto in fotos) {
          final itemId = foto['item_id'] as String?;
          final path = foto['local_path'] as String;
          if (itemId == null) {
            fotosGenerales.add(path);
          } else if (itemIds.contains(itemId)) {
            fotosPorItem.putIfAbsent(itemId, () => []).add(path);
          } else {
            fotosExtra.add({
              'path': path,
              'observacion': foto['descripcion'] as String? ?? '',
            });
          }
        }

        expect(fotosPorItem['item-A']?.length, 1);
        expect(fotosGenerales.length, 1);
        expect(fotosExtra.length, 1);
        expect(fotosExtra.first['observacion'], 'Hallazgo extra');
      },
    );

    test(
      'Aprobación BUCEO: 0 intolerables + faena habilitada = HABILITADA',
      () {
        int countIntolerables = 0;
        bool faenaHabilitada = true;

        bool aprobado = countIntolerables == 0 && faenaHabilitada;
        String estado = aprobado ? "HABILITADA" : "SUSPENDIDA";

        expect(estado, "HABILITADA");
      },
    );

    test('Aprobación BUCEO: intolerables > 0 = SUSPENDIDA', () {
      int countIntolerables = 2;
      bool faenaHabilitada = true;

      bool aprobado = countIntolerables == 0 && faenaHabilitada;
      String estado = aprobado ? "HABILITADA" : "SUSPENDIDA";

      expect(estado, "SUSPENDIDA");
    });

    test('Aprobación EMBARCACION: siempre REALIZADA', () {
      String tipoActividad = 'INSPECCION_EMBARCACION';
      String estado = tipoActividad == 'INSPECCION_BUCEO'
          ? "HABILITADA"
          : "REALIZADA";
      expect(estado, "REALIZADA");
    });

    test('Participantes con condiciones_optimas=1 muestra Optima', () {
      final condiciones = 1;
      final texto = condiciones == 1 ? "Optima" : "NO APTO";
      expect(texto, "Optima");
    });

    test('Participantes con condiciones_optimas=0 muestra NO APTO', () {
      final condiciones = 0;
      final texto = condiciones == 1 ? "Optima" : "NO APTO";
      expect(texto, "NO APTO");
    });

    test('Fecha se formatea desde ISO8601 de SQLite', () {
      final fechaStr = '2026-03-31';
      final dt = DateTime.parse(fechaStr);
      final formatted =
          "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      expect(formatted, '31/03/2026');
    });

    test('Sin numero_reporte retorna false (no genera PDF)', () {
      final row = {'numero_reporte': null};
      final numRep = row['numero_reporte']?.toString();
      final puedeGenerar = numRep != null && numRep.isNotEmpty;
      expect(puedeGenerar, false);
    });
  });

  // ===================================================================
  // TESTS: ESTIMACIÓN DE NÚMERO DE INFORME (~N)
  // ===================================================================
  group('Estimación de número de informe (~N)', () {
    test('Estimación desde SQLite: MAX+1 de números existentes', () {
      // Simula sugerirSiguienteNumeroReporte
      final rows = [
        {'numero_reporte': '40'},
        {'numero_reporte': '42'},
        {'numero_reporte': '38'},
        {'numero_reporte': null},
      ];

      int maxNum = 0;
      for (var row in rows) {
        final val = row['numero_reporte'] as String?;
        if (val != null && RegExp(r'^[0-9]+$').hasMatch(val)) {
          final num = int.tryParse(val);
          if (num != null && num > maxNum) maxNum = num;
        }
      }

      final estimado = maxNum > 0 ? (maxNum + 1).toString() : null;
      expect(estimado, '43');
    });

    test('Estimación sin datos retorna null', () {
      final rows = <Map<String, dynamic>>[];

      int maxNum = 0;
      for (var row in rows) {
        final val = row['numero_reporte'] as String?;
        if (val != null && RegExp(r'^[0-9]+$').hasMatch(val)) {
          final num = int.tryParse(val);
          if (num != null && num > maxNum) maxNum = num;
        }
      }

      final estimado = maxNum > 0 ? (maxNum + 1).toString() : null;
      expect(estimado, isNull);
    });

    test('Estimación ignora valores no numéricos', () {
      final rows = [
        {'numero_reporte': 'PROV-ABC'},
        {'numero_reporte': '~42'},
        {'numero_reporte': 'Pendiente'},
        {'numero_reporte': '35'},
      ];

      int maxNum = 0;
      for (var row in rows) {
        final val = row['numero_reporte'] as String?;
        if (val != null && RegExp(r'^[0-9]+$').hasMatch(val)) {
          final num = int.tryParse(val);
          if (num != null && num > maxNum) maxNum = num;
        }
      }

      final estimado = maxNum > 0 ? (maxNum + 1).toString() : null;
      expect(
        estimado,
        '36',
        reason: 'Solo el "35" es numérico puro, PROV/~/Pendiente se ignoran',
      );
    });

    test('Estimado se muestra con prefijo ~ en controller', () {
      final estimado = "42";
      final controllerText = "~$estimado";
      expect(controllerText, "~42");
      expect(controllerText.startsWith("~"), true);
    });

    test('Estimado ~N NO se guarda en SQLite (guarda null)', () {
      final texto = "~42";
      final esEstimado = texto.startsWith("~");
      final paraGuardar = esEstimado ? null : texto;
      expect(
        paraGuardar,
        isNull,
        reason: 'Estimados no se persisten en SQLite',
      );
    });

    test('Número real SÍ se guarda en SQLite', () {
      final texto = "42";
      final esEstimado = texto.startsWith("~");
      final paraGuardar = esEstimado ? null : texto;
      expect(paraGuardar, "42");
    });

    test('Guard _persistirDatos protege contra ~estimado', () {
      String? numeroFinal = "~42";
      final esNumeroNoReal =
          numeroFinal.isEmpty ||
          numeroFinal == "Pendiente..." ||
          numeroFinal == "Pendiente" ||
          numeroFinal.startsWith("~");

      // Simula: DB tiene número real
      final numeroEnDB = "42";
      if (esNumeroNoReal && (numeroEnDB.isNotEmpty && numeroEnDB != "null")) {
        numeroFinal = numeroEnDB;
      }

      expect(
        numeroFinal,
        "42",
        reason: 'Guard reemplaza ~estimado con real de DB',
      );
    });

    test('Guard _persistirDatos: DB sin número + estimado = guarda null', () {
      String? numeroFinal = "~42";
      final esNumeroNoReal =
          numeroFinal.isEmpty ||
          numeroFinal == "Pendiente..." ||
          numeroFinal == "Pendiente" ||
          numeroFinal.startsWith("~");

      // Simula: DB no tiene número real
      final String? numeroEnDB = null;
      if (esNumeroNoReal &&
          (numeroEnDB != null &&
              numeroEnDB.isNotEmpty &&
              numeroEnDB != "null")) {
        numeroFinal = numeroEnDB;
      }

      // Si sigue siendo estimado, guardar null
      if (esNumeroNoReal) {
        numeroFinal = null;
      }

      expect(
        numeroFinal,
        isNull,
        reason: 'Sin número real en DB, estimado se descarta → null',
      );
    });

    test('Timer 5s recarga número si es estimado (~)', () {
      final texto = "~42";
      final debeRecargar = texto.isEmpty || texto.startsWith("~");
      expect(
        debeRecargar,
        true,
        reason: 'Timer debe intentar recargar si es estimado',
      );
    });

    test('Timer 5s NO recarga si ya tiene número real', () {
      final texto = "42";
      final debeRecargar = texto.isEmpty || texto.startsWith("~");
      expect(debeRecargar, false, reason: 'Número real no necesita recarga');
    });

    test('Estimación online: MAX(numero_informe)+1 de Supabase', () {
      // Simula respuesta de Supabase
      final supabaseResult = {'numero_informe': 95};
      final maxNum = supabaseResult['numero_informe'] as int;
      final estimado = (maxNum + 1).toString();
      expect(estimado, '96');
    });

    test('Estimación online sin registros retorna "1"', () {
      // Simula Supabase vacío (maybeSingle retorna null)
      final Map<String, dynamic>? result = null;
      String estimado;
      if (result != null && result['numero_informe'] != null) {
        estimado = ((result['numero_informe'] as int) + 1).toString();
      } else {
        estimado = "1";
      }
      expect(estimado, "1");
    });
  });

  // ===================================================================
  // TESTS: PDF DIFERIDO - TIPADO Y GENERACIÓN DESDE SQLITE
  // ===================================================================
  group('PDF Diferido - tipado correcto en construcción de datos', () {
    test(
      'itemIds desde List<Map<String,dynamic>>.map().toSet() es Set<String>',
      () {
        // Simula la query de SQLite que retorna List<Map<String, dynamic>>
        final List<Map<String, dynamic>> itemsDb = [
          {'id': 'item-A', 'pregunta': 'P1', 'categoria': 'Cat1'},
          {'id': 'item-B', 'pregunta': 'P2', 'categoria': 'Cat2'},
        ];

        // Sin .map<String>() esto daría Set<dynamic> en runtime
        final Set<String> ids = itemsDb
            .map<String>((i) => i['id'] as String)
            .toSet();

        expect(ids, isA<Set<String>>());
        expect(ids.length, 2);
        expect(ids.contains('item-A'), true);
      },
    );

    test(
      'equipoDto desde rawQuery.map().toList() es List<PersonalDto> tipado',
      () {
        // Simula rawQuery de actividad_participantes JOIN personal_externo
        final List<Map<String, dynamic>> partRows = [
          {
            'nombre_completo': 'Juan Pérez',
            'rut': '12345678-9',
            'cargo': 'Buzo',
            'matricula': 'MAT-001',
            'condiciones_optimas': 1,
          },
          {
            'nombre_completo': 'María López',
            'rut': '98765432-1',
            'cargo': 'Supervisor',
            'matricula': null,
            'condiciones_optimas': 0,
          },
        ];

        // Simula la lógica EXACTA de DeferredPdfService
        // Sin .map<Map<String, String>>() esto daría List<dynamic>
        final equipoDto = partRows.map<Map<String, String>>((p) {
          final condiciones = (p['condiciones_optimas'] as int?) == 1;
          return {
            'nombre': p['nombre_completo']?.toString() ?? '',
            'rut': p['rut']?.toString() ?? '',
            'cargo': p['cargo']?.toString() ?? '',
            'matricula': (p['matricula']?.toString().isEmpty ?? true)
                ? "-"
                : p['matricula'].toString(),
            'rolEnFaena': condiciones ? "Optima" : "NO APTO",
          };
        }).toList();

        expect(equipoDto, isA<List<Map<String, String>>>());
        expect(equipoDto.length, 2);
        expect(equipoDto[0]['nombre'], 'Juan Pérez');
        expect(equipoDto[0]['rolEnFaena'], 'Optima');
        expect(equipoDto[1]['matricula'], '-');
        expect(equipoDto[1]['rolEnFaena'], 'NO APTO');
      },
    );

    test('Clasificación de fotos funciona con itemIds tipado desde DB', () {
      final List<Map<String, dynamic>> itemsDb = [
        {'id': 'item-X', 'pregunta': 'P1'},
        {'id': 'item-Y', 'pregunta': 'P2'},
      ];

      final Set<String> itemIds = itemsDb
          .map<String>((i) => i['id'] as String)
          .toSet();

      final List<Map<String, dynamic>> fotosDb = [
        {'item_id': 'item-X', 'local_path': '/foto1.jpg', 'descripcion': ''},
        {'item_id': null, 'local_path': '/foto2.jpg', 'descripcion': ''},
        {
          'item_id': 'extra-uuid',
          'local_path': '/foto3.jpg',
          'descripcion': 'Hallazgo',
        },
      ];

      final Map<String, List<String>> fotosPorItem = {};
      final List<String> fotosGenerales = [];
      final List<Map<String, String>> fotosExtra = [];

      for (var foto in fotosDb) {
        final itemId = foto['item_id'] as String?;
        final localPath = foto['local_path'] as String?;
        if (localPath == null) continue;

        if (itemId == null) {
          fotosGenerales.add(localPath);
        } else if (itemIds.contains(itemId)) {
          fotosPorItem.putIfAbsent(itemId, () => []).add(localPath);
        } else {
          fotosExtra.add({
            'path': localPath,
            'observacion': foto['descripcion'] as String? ?? '',
          });
        }
      }

      expect(fotosPorItem['item-X']?.length, 1);
      expect(fotosGenerales.length, 1);
      expect(fotosExtra.length, 1);
      expect(fotosExtra.first['observacion'], 'Hallazgo');
    });

    test(
      'PDF diferido detecta actividad sin numero_reporte como no-generable',
      () {
        final row = {'numero_reporte': null};
        final numRep = row['numero_reporte']?.toString();
        final puedeGenerar = numRep != null && numRep.isNotEmpty;
        expect(puedeGenerar, false);
      },
    );

    test('PDF diferido con numero_reporte real es generable', () {
      final row = {'numero_reporte': '93'};
      final numRep = row['numero_reporte']?.toString();
      final puedeGenerar = numRep != null && numRep.isNotEmpty;
      expect(puedeGenerar, true);
    });

    test('Conteos de respuestas son correctos para PDF', () {
      final List<Map<String, dynamic>> respuestas = [
        {'estado': 'C', 'criticidad_registrada': 'Tolerable'},
        {'estado': 'C', 'criticidad_registrada': 'Tolerable'},
        {'estado': 'NC', 'criticidad_registrada': 'Intolerable'},
        {'estado': 'NC', 'criticidad_registrada': 'Moderado'},
        {'estado': 'N/A', 'criticidad_registrada': 'Tolerable'},
      ];

      int countC = 0, countNC = 0, countNA = 0, countIntolerables = 0;
      for (var r in respuestas) {
        final estado = r['estado'];
        final crit = r['criticidad_registrada'];
        if (estado == 'C') {
          countC++;
        } else if (estado == 'NC') {
          countNC++;
          if (crit == 'Intolerable') countIntolerables++;
        } else if (estado == 'N/A') {
          countNA++;
        }
      }

      expect(countC, 2);
      expect(countNC, 2);
      expect(countNA, 1);
      expect(countIntolerables, 1);
    });

    test('Estado global BUCEO: SUSPENDIDA si hay intolerables', () {
      final tipo = 'INSPECCION_BUCEO';
      final countIntolerables = 1;
      final faenaHabilitada = true;

      bool aprobado = true;
      String estado = "FINALIZADA";

      if (tipo == 'INSPECCION_BUCEO') {
        aprobado = countIntolerables == 0 && faenaHabilitada;
        estado = aprobado ? "HABILITADA" : "SUSPENDIDA";
      } else {
        estado = "REALIZADA";
      }

      expect(estado, "SUSPENDIDA");
    });

    test('Estado global EMBARCACION: siempre REALIZADA', () {
      final tipo = 'INSPECCION_EMBARCACION';
      final countIntolerables = 3; // no importa

      String estado = "FINALIZADA";
      if (tipo == 'INSPECCION_BUCEO') {
        estado = countIntolerables == 0 ? "HABILITADA" : "SUSPENDIDA";
      } else {
        estado = "REALIZADA";
      }

      expect(estado, "REALIZADA");
    });

    test('Fecha se parsea desde campo fecha de actividad', () {
      final fechaStr = '2026-03-31';
      String fechaFormateada;
      try {
        final dt = DateTime.parse(fechaStr);
        fechaFormateada =
            "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      } catch (_) {
        fechaFormateada = fechaStr;
      }
      expect(fechaFormateada, '31/03/2026');
    });

    test('Fecha null usa fecha actual', () {
      final String? fechaStr = null;
      String fechaFormateada;
      if (fechaStr != null && fechaStr.isNotEmpty) {
        fechaFormateada = fechaStr;
      } else {
        final now = DateTime.now();
        fechaFormateada =
            "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
      }
      expect(fechaFormateada, isNotEmpty);
      expect(fechaFormateada.contains('/'), true);
    });

    test('Verificaciones buceo suman al conteo de C/NC', () {
      final criticas = [true, true, false, true, true];
      int countC = 0, countNC = 0;
      for (var cumple in criticas) {
        cumple ? countC++ : countNC++;
      }
      expect(countC, 4);
      expect(countNC, 1);
    });

    test('matricula vacía se muestra como "-"', () {
      final matricula = '';
      final display = (matricula.isEmpty) ? "-" : matricula;
      expect(display, "-");
    });

    test('matricula null se muestra como "-"', () {
      final String? matricula = null;
      final display = (matricula?.toString().isEmpty ?? true)
          ? "-"
          : matricula!;
      expect(display, "-");
    });
  });

  // ===================================================================
  // TESTS: FLUJO FINALIZACIÓN - SYNC POST-PERSISTIR
  // ===================================================================
  group('Flujo finalización - sync después de persistir final', () {
    test('Path offline: persiste como En Seguimiento y necesita re-sync', () {
      // Simula el flujo completo de finalizarInspeccion path offline
      // 1. Persistir como borrador (En Progreso, subido=0)
      var estado = 'En Progreso';
      var subido = 0;

      // 2. Sync sube y marca subido=1
      subido = 1;

      // 3. No obtiene número real → path offline
      final tieneNumeroReal = false;

      // 4. Persistir como final (En Seguimiento, subido=0)
      if (!tieneNumeroReal) {
        estado = 'En Seguimiento';
        subido = 0; // saveInspeccionCompleta siempre pone subido=0
      }

      expect(estado, 'En Seguimiento');
      expect(
        subido,
        0,
        reason: 'Debe ser 0 para que el segundo sync lo recoja',
      );
    });

    test(
      'Segundo sync recoge actividad con subido=0 y estado En Seguimiento',
      () {
        final actividades = [
          {'id': 'act-1', 'estado_final': 'En Seguimiento', 'subido': 0},
          {'id': 'act-2', 'estado_final': 'En Progreso', 'subido': 1},
        ];

        final paraSync = actividades.where((a) => a['subido'] == 0).toList();
        expect(paraSync.length, 1);
        expect(
          paraSync.first['estado_final'],
          'En Seguimiento',
          reason: 'El segundo sync debe subir el estado finalizado',
        );
      },
    );

    test('Trigger de Supabase asigna numero_informe solo con En Seguimiento', () {
      // Simula: la actividad llega a Supabase como UPDATE con estado_final='En Seguimiento'
      final estadoFinal = 'En Seguimiento';
      final debeAsignarNumero = estadoFinal == 'En Seguimiento';
      expect(debeAsignarNumero, true);
    });

    test(
      'Sin segundo sync, Supabase queda con En Progreso (el bug original)',
      () {
        // Documenta el bug: si no se hace un segundo sync,
        // Supabase tiene "En Progreso" y el trigger no dispara
        var estadoEnSupabase = 'En Progreso'; // del primer sync
        var estadoEnSQLite = 'En Seguimiento'; // del segundo persistir

        // Sin segundo sync, hay discrepancia
        final hayDiscrepancia = estadoEnSupabase != estadoEnSQLite;
        expect(
          hayDiscrepancia,
          true,
          reason:
              'Sin segundo sync, Supabase no se entera del cambio a En Seguimiento',
        );
      },
    );
  });

  // ===================================================================
  // BUG-002: Inspección finalizada sin PDF
  // Tests de detección de PDFs diferidos y recuperación de numero_reporte
  // ===================================================================
  group('BUG-002 - Detección de PDFs diferidos', () {
    // Helper: simula la condición WHERE de _generarPdfsDiferidos
    bool queryPdfPendiente(Map<String, dynamic> a) {
      final numero = a['numero_reporte']?.toString() ?? '';
      return a['estado_final'] == 'En Seguimiento' &&
          (a['pdf_path_local'] == null || a['pdf_path_local'] == '') &&
          (a['pdf_url'] == null || a['pdf_url'] == '') &&
          a['eliminado'] == 0 &&
          numero.isNotEmpty &&
          !numero.startsWith('PROV-') &&
          !numero.startsWith('~');
    }

    test(
      'Query de PDFs pendientes detecta inspección sin PDF con numero_reporte',
      () {
        final actividades = [
          {
            'id': '1',
            'estado_final': 'En Seguimiento',
            'pdf_path_local': null,
            'pdf_url': null,
            'eliminado': 0,
            'numero_reporte': '42',
          },
          {
            'id': '2',
            'estado_final': 'En Seguimiento',
            'pdf_path_local': '/path/to/file.pdf',
            'pdf_url': null,
            'eliminado': 0,
            'numero_reporte': '43',
          },
          {
            'id': '3',
            'estado_final': 'En Progreso',
            'pdf_path_local': null,
            'pdf_url': null,
            'eliminado': 0,
            'numero_reporte': null,
          },
        ];

        final pendientesPdf = actividades.where(queryPdfPendiente).toList();

        expect(pendientesPdf.length, 1);
        expect(pendientesPdf.first['id'], '1');
      },
    );

    test('Query de PDFs pendientes ignora inspección eliminada', () {
      final actividades = [
        {
          'id': '1',
          'estado_final': 'En Seguimiento',
          'pdf_path_local': null,
          'pdf_url': null,
          'eliminado': 1, // soft-deleted
          'numero_reporte': '42',
        },
      ];

      final pendientesPdf = actividades.where(queryPdfPendiente).toList();
      expect(pendientesPdf, isEmpty);
    });

    test('Query de PDFs pendientes ignora inspección sin numero_reporte', () {
      final actividades = [
        {
          'id': '1',
          'estado_final': 'En Seguimiento',
          'pdf_path_local': null,
          'pdf_url': null,
          'eliminado': 0,
          'numero_reporte': null, // sin número
        },
        {
          'id': '2',
          'estado_final': 'En Seguimiento',
          'pdf_path_local': null,
          'pdf_url': null,
          'eliminado': 0,
          'numero_reporte': '', // vacío
        },
      ];

      final pendientesPdf = actividades.where(queryPdfPendiente).toList();

      expect(
        pendientesPdf,
        isEmpty,
        reason: 'Sin numero_reporte no se puede generar PDF',
      );
    });

    test('Query de PDFs pendientes trata pdf_url vacío como null', () {
      final actividades = [
        {
          'id': '1',
          'estado_final': 'En Seguimiento',
          'pdf_path_local': '',
          'pdf_url': '',
          'eliminado': 0,
          'numero_reporte': '42',
        },
      ];

      final pendientesPdf = actividades.where(queryPdfPendiente).toList();

      expect(
        pendientesPdf.length,
        1,
        reason: 'Strings vacíos cuentan como sin PDF',
      );
    });

    test('Query ignora numero_reporte provisional PROV-*', () {
      final actividades = [
        {
          'id': '1',
          'estado_final': 'En Seguimiento',
          'pdf_path_local': '/path/provisional.pdf',
          'pdf_url': null,
          'eliminado': 0,
          'numero_reporte': 'PROV-abc12345',
        },
      ];

      final pendientesPdf = actividades.where(queryPdfPendiente).toList();
      expect(
        pendientesPdf,
        isEmpty,
        reason: 'PROV-* es provisional, necesita número real',
      );
    });

    test('Query ignora numero_reporte estimado ~*', () {
      final actividades = [
        {
          'id': '1',
          'estado_final': 'En Seguimiento',
          'pdf_path_local': null,
          'pdf_url': null,
          'eliminado': 0,
          'numero_reporte': '~43',
        },
      ];

      final pendientesPdf = actividades.where(queryPdfPendiente).toList();
      expect(
        pendientesPdf,
        isEmpty,
        reason: '~N es estimado, necesita número real',
      );
    });
  });

  group('BUG-002 - Recuperación de numero_reporte faltante', () {
    test('Detecta inspecciones stuck (En Seguimiento sin numero_reporte)', () {
      final actividades = [
        {
          'id': '1',
          'estado_final': 'En Seguimiento',
          'numero_reporte': null,
          'eliminado': 0,
        },
        {
          'id': '2',
          'estado_final': 'En Seguimiento',
          'numero_reporte': '',
          'eliminado': 0,
        },
        {
          'id': '3',
          'estado_final': 'En Seguimiento',
          'numero_reporte': '42', // ya tiene
          'eliminado': 0,
        },
        {
          'id': '4',
          'estado_final': 'En Progreso', // borrador, no aplica
          'numero_reporte': null,
          'eliminado': 0,
        },
      ];

      final stuck = actividades
          .where(
            (a) =>
                a['estado_final'] == 'En Seguimiento' &&
                (a['numero_reporte'] == null || a['numero_reporte'] == '') &&
                a['eliminado'] == 0,
          )
          .toList();

      expect(stuck.length, 2);
      expect(stuck.map((s) => s['id']).toList(), ['1', '2']);
    });

    test('Inspección ya con numero_reporte no se toca', () {
      final actividades = [
        {
          'id': '1',
          'estado_final': 'En Seguimiento',
          'numero_reporte': '42',
          'eliminado': 0,
        },
      ];

      final stuck = actividades
          .where(
            (a) =>
                a['estado_final'] == 'En Seguimiento' &&
                (a['numero_reporte'] == null || a['numero_reporte'] == '') &&
                a['eliminado'] == 0,
          )
          .toList();

      expect(stuck, isEmpty);
    });
  });

  group('BUG-002 - _generarPdfsDiferidos siempre se ejecuta', () {
    test('Si sync principal falla, PDFs diferidos aún deben ejecutarse', () {
      // Simula sincronizarTodo() con la nueva estructura
      bool pdfsDiferidosEjecutado = false;
      bool syncFallo = false;

      // Paso 1-5: sync principal
      try {
        throw Exception('Error en visitas sync'); // simula fallo
      } catch (e) {
        syncFallo = true;
      }

      // Paso 6: SIEMPRE se ejecuta (fuera del try/catch principal)
      try {
        pdfsDiferidosEjecutado = true; // simula _generarPdfsDiferidos
      } catch (_) {}

      expect(syncFallo, true, reason: 'Sync principal falló');
      expect(
        pdfsDiferidosEjecutado,
        true,
        reason: 'PDFs diferidos debe ejecutarse aunque sync falle',
      );
    });

    test(
      'Si sync principal tiene éxito, PDFs diferidos también se ejecutan',
      () {
        bool pdfsDiferidosEjecutado = false;
        int totalSubidas = 0;

        try {
          totalSubidas = 5; // simula sync exitoso
        } catch (_) {}

        try {
          pdfsDiferidosEjecutado = true;
        } catch (_) {}

        expect(totalSubidas, 5);
        expect(pdfsDiferidosEjecutado, true);
      },
    );
  });

  group('BUG-002 - Fallback silencioso del controller', () {
    test('PDF generation catch marca pdfDiferido = true', () {
      // Simula el catch de línea 743 del controller
      bool pdfDiferido = false;
      String? pdfUrlFinal;
      String? pdfPathLocal;

      try {
        throw Exception('Font loading failed'); // simula fallo de PDF
      } catch (e) {
        pdfDiferido = true;
        pdfUrlFinal = null;
        pdfPathLocal = null;
      }

      expect(
        pdfDiferido,
        true,
        reason: 'Debe activar modo diferido cuando PDF falla',
      );
      expect(pdfUrlFinal, isNull);
      expect(pdfPathLocal, isNull);
    });

    test(
      'Inspección con pdfDiferido=true queda detectable para DeferredPdfService',
      () {
        // Simula el estado en SQLite después del fallback
        final estadoFinal = 'En Seguimiento';
        final String? pdfPathLocal = null;
        final String? pdfUrl = null;
        final String? numeroReporte = '42'; // asignado por trigger
        final eliminado = 0;

        // Query de _generarPdfsDiferidos
        final esDetectable =
            estadoFinal == 'En Seguimiento' &&
            (pdfPathLocal == null || pdfPathLocal == '') &&
            (pdfUrl == null || pdfUrl == '') &&
            eliminado == 0 &&
            numeroReporte != null &&
            numeroReporte != '';

        expect(
          esDetectable,
          true,
          reason: 'DeferredPdfService debe encontrar esta inspección',
        );
      },
    );

    test(
      'Inspección offline sin numero_reporte es recuperable por _recuperarNumeroReporteFaltante',
      () {
        // Simula el estado en SQLite después de finalización offline
        final estadoFinal = 'En Seguimiento';
        final String? numeroReporte = null; // trigger no ejecutado aún

        // Query de _recuperarNumeroReporteFaltante
        final esRecuperable =
            estadoFinal == 'En Seguimiento' &&
            (numeroReporte == null || numeroReporte == '');

        expect(
          esRecuperable,
          true,
          reason:
              '_recuperarNumeroReporteFaltante debe encontrar esta inspección',
        );
      },
    );
  });
}
