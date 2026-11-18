import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/inspection/domain/formato_inspeccion.dart';
import 'package:jf_innova_app/features/inspection/domain/models/buceo_verificacion_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';
import 'package:jf_innova_app/features/inspection/domain/models/participante_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/pdf/inspection_report_data.dart';
import 'package:jf_innova_app/features/inspection/services/pdf_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FormatoInspeccion.bancoPreguntas', () {
    test('estándar usa el tipo de actividad', () {
      expect(
        FormatoInspeccion.bancoPreguntas('INSPECCION_BUCEO', 'ESTANDAR'),
        'INSPECCION_BUCEO',
      );
    });

    test('Searov usa su banco propio', () {
      expect(
        FormatoInspeccion.bancoPreguntas('INSPECCION_EMBARCACION', 'SEAROV'),
        'INSPECCION_EMBARCACION_SEAROV',
      );
    });
  });

  group('FormatoInspeccion.consolidarPorBuzo', () {
    test('un buzo con No cumple hace No cumple la pregunta', () {
      expect(FormatoInspeccion.consolidarPorBuzo(['C', 'NC', 'C']), 'NC');
    });

    test('todos cumplen o no aplica: Cumple', () {
      expect(FormatoInspeccion.consolidarPorBuzo(['C', 'N/A']), 'C');
    });

    test('solo N/A: N/A', () {
      expect(FormatoInspeccion.consolidarPorBuzo(['N/A', null]), 'N/A');
    });

    test('sin respuestas: null', () {
      expect(FormatoInspeccion.consolidarPorBuzo([]), isNull);
      expect(FormatoInspeccion.consolidarPorBuzo([null]), isNull);
    });
  });

  group('FormatoInspeccion.resultadoPorPotencialidad', () {
    List<({String? potencialidad, String respuesta})> ncs(
      int altas,
      int medias,
    ) => [
      for (var i = 0; i < altas; i++) (potencialidad: 'ALTA', respuesta: 'NC'),
      for (var i = 0; i < medias; i++)
        (potencialidad: 'MEDIA', respuesta: 'NC'),
      (potencialidad: 'ALTA', respuesta: 'C'),
      (potencialidad: 'MEDIA', respuesta: 'N/A'),
    ];

    test('sin incumplimientos: faena autorizada', () {
      final r = FormatoInspeccion.resultadoPorPotencialidad(ncs(0, 0));
      expect(r.resultado, ResultadoEmbarcacion.autorizada);
    });

    test('un incumplimiento ALTA rechaza', () {
      final r = FormatoInspeccion.resultadoPorPotencialidad(ncs(1, 0));
      expect(r.resultado, ResultadoEmbarcacion.rechazada);
      expect(r.incumplimientosAlta, 1);
    });

    test('de 1 a 5 MEDIA: autorizada condicional', () {
      for (final medias in [1, 5]) {
        final r = FormatoInspeccion.resultadoPorPotencialidad(ncs(0, medias));
        expect(r.resultado, ResultadoEmbarcacion.condicional);
        expect(r.incumplimientosMedia, medias);
      }
    });

    test('6 MEDIA rechaza', () {
      final r = FormatoInspeccion.resultadoPorPotencialidad(ncs(0, 6));
      expect(r.resultado, ResultadoEmbarcacion.rechazada);
    });

    test('preguntas sin potencialidad no cuentan', () {
      final r = FormatoInspeccion.resultadoPorPotencialidad([
        (potencialidad: null, respuesta: 'NC'),
      ]);
      expect(r.resultado, ResultadoEmbarcacion.autorizada);
    });
  });

  group('Estado de buceo Searov (sin verificaciones críticas)', () {
    final switchesEnFalse = BuceoVerificacionModel(actividadId: 'a1');

    test('estándar: switches IV–VIII en false suspenden', () {
      expect(
        BuceoVerificacionModel.resolverAprobacionFaena(
          verificaciones: switchesEnFalse,
          totalIntolerables: 0,
        ),
        isFalse,
      );
    });

    test('Searov (sin verificaciones): solo cuentan los intolerables', () {
      expect(
        BuceoVerificacionModel.resolverAprobacionFaena(
          verificaciones: null,
          totalIntolerables: 0,
        ),
        isTrue,
      );
      expect(
        BuceoVerificacionModel.resolverAprobacionFaena(
          verificaciones: null,
          totalIntolerables: 1,
        ),
        isFalse,
      );
    });
  });

  group('Modelos', () {
    test('FormularioItem lee potencialidad y aplica_por_buzo', () {
      final item = FormularioItem.fromJson({
        'id': 'i1',
        'pregunta': 'Traje',
        'categoria': 'Personal',
        'potencialidad': 'ALTA',
        'aplica_por_buzo': 1,
      });
      expect(item.potencialidad, 'ALTA');
      expect(item.aplicaPorBuzo, isTrue);
    });

    test('FormularioItem sin columnas nuevas mantiene valores por defecto', () {
      final item = FormularioItem.fromJson({
        'id': 'i1',
        'pregunta': 'P',
        'categoria': 'C',
      });
      expect(item.potencialidad, isNull);
      expect(item.aplicaPorBuzo, isFalse);
    });

    test('ParticipanteModel ida y vuelta de respuestas por buzo', () {
      final p = ParticipanteModel(
        personalId: 'b1',
        nombreCompleto: 'Buzo Uno',
        rut: '11111111-1',
        cargo: 'Buzo',
        respuestasPersonal: {'i1': 'C', 'i2': 'NC'},
      );
      final leido = ParticipanteModel.fromMap({
        'personal_id': 'b1',
        'respuestas_personal': p.respuestasPersonalJson,
      });
      expect(leido.respuestasPersonal, {'i1': 'C', 'i2': 'NC'});
    });

    test('ParticipanteModel sin respuestas no genera JSON', () {
      final p = ParticipanteModel.fromMap({'personal_id': 'b1'});
      expect(p.respuestasPersonal, isEmpty);
      expect(p.respuestasPersonalJson, isNull);
      expect(ParticipanteModel.decodeRespuestas('no-json'), isEmpty);
    });
  });

  group('PDF Searov', () {
    late Uint8List fontReg;
    late Uint8List fontBold;
    late Uint8List fontItalic;

    setUpAll(() async {
      fontReg = await File('assets/fonts/OpenSans-Regular.ttf').readAsBytes();
      fontBold = await File('assets/fonts/OpenSans-Bold.ttf').readAsBytes();
      fontItalic = await File('assets/fonts/OpenSans-Italic.ttf').readAsBytes();
    });

    Future<Uint8List> generar(InspectionReportData data) =>
        generatePdfEntryPoint(
          PdfIsolateParams(
            data: data,
            fontRegular: fontReg,
            fontBold: fontBold,
            fontItalic: fontItalic,
          ),
        );

    test('buceo con matriz por buzo, sin logo', () async {
      final bytes = await generar(
        _datos(
          tipoFaena: 'INSPECCIÓN DE BUCEO',
          fotoPath: 'assets/images/aquachile.png',
        ),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      expect(bytes.length, greaterThan(2000));
    });

    test('embarcación con potencialidad y acciones correctivas', () async {
      final bytes = await generar(
        _datos(tipoFaena: 'INSPECCIÓN DE EMBARCACIÓN'),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      expect(bytes.length, greaterThan(2000));
    });

    test('pregunta con 3 fotos y observación muy larga no falla', () async {
      final base = _datos(
        tipoFaena: 'INSPECCIÓN DE BUCEO',
        fotoPath: 'assets/images/aquachile.png',
      );
      final bytes = await generar(
        InspectionReportData(
          empresaProveedor: base.empresaProveedor,
          empresaContratista: base.empresaContratista,
          cliente: base.cliente,
          logoUrl: '',
          numeroReporte: '1',
          fecha: base.fecha,
          centro: base.centro,
          area: base.area,
          embarcacion: base.embarcacion,
          matricula: base.matricula,
          appVersion: base.appVersion,
          tipoFaena: base.tipoFaena,
          supervisor: base.supervisor,
          estadoGlobal: 'HABILITADA',
          esAprobado: true,
          formato: FormatoInspeccion.searov,
          compresor2Vigencia: '31/12/2026',
          equipo: const [],
          items: [
            InspectionItemDto(
              categoria: 'Emergencia',
              pregunta: 'Botiquín de primeros auxilios básico',
              respuesta: 'NC',
              criticidad: 'Tolerable',
              comentario: 'Observación larga. ' * 150,
              fotosPaths: List.filled(3, 'assets/images/aquachile.png'),
            ),
          ],
          fotosGeneralesPaths: const [],
          fotosExtraObservaciones: const [],
          totalCumple: 0,
          totalNoCumple: 1,
          totalNoAplica: 0,
          totalIntolerables: 0,
          sumPesoCumple: 0,
          sumPesoNoCumple: 1,
          observacionPrevencionista: 'Sin observaciones.',
          verificacionesBuceo: const {},
        ),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('sin cuadrilla ni items no falla', () async {
      final bytes = await generar(
        _datos(tipoFaena: 'INSPECCIÓN DE BUCEO', vacio: true),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });
  });
}

InspectionReportData _datos({
  required String tipoFaena,
  String? fotoPath,
  bool vacio = false,
}) {
  final esBuceo = tipoFaena.contains('BUCEO');
  return InspectionReportData(
    empresaProveedor: 'SEAROV SPA',
    empresaContratista: 'Contratista Demo',
    cliente: 'Cliente',
    logoUrl: '',
    numeroReporte: '1',
    fecha: '29/10/2026',
    centro: 'Centro Demo',
    area: 'Área Demo',
    embarcacion: 'Nave Demo',
    matricula: 'ABC-123',
    appVersion: 'v0.0.0',
    tipoFaena: tipoFaena,
    supervisor: 'Supervisor Demo',
    estadoGlobal: 'HABILITADA',
    esAprobado: true,
    formato: FormatoInspeccion.searov,
    inspectorNombre: vacio ? null : 'Inspector Demo / Prevencionista',
    recibeNombre: vacio ? null : 'Jefe de Centro Demo',
    firmaInspectorPath: fotoPath,
    compresor1Matricula: vacio ? null : 'CMP-001',
    compresor1Vigencia: vacio ? null : '31/12/2026',
    compresor1PH: vacio ? null : '30/06/2027',
    compresor1Buzos: vacio ? null : '2',
    preguntasPorBuzo: vacio || !esBuceo
        ? {}
        : {'i1': 'Traje de buceo', 'i2': 'Caperuza'},
    equipo: vacio
        ? []
        : [
            PersonalDto(
              nombre: 'Buzo Uno',
              rut: '11111111-1',
              cargo: 'Buzo',
              rolEnFaena: 'Optima',
              respuestasPorItem: {'i1': 'C', 'i2': 'NC'},
            ),
            PersonalDto(
              nombre: 'Buzo Dos',
              rut: '22222222-2',
              cargo: 'Buzo',
              rolEnFaena: 'Optima',
              respuestasPorItem: {'i1': 'C', 'i2': 'C'},
            ),
          ],
    items: vacio
        ? []
        : [
            if (esBuceo) ...[
              InspectionItemDto(
                categoria: 'Personal (por buzo)',
                pregunta: 'Caperuza',
                respuesta: 'NC',
                criticidad: 'Tolerable',
                aplicaPorBuzo: true,
              ),
              InspectionItemDto(
                categoria: 'Emergencia',
                pregunta: 'Botiquín de primeros auxilios básico',
                respuesta: 'NC',
                criticidad: 'Tolerable',
                comentario: 'Sin vendas',
                fotosPaths: [?fotoPath],
              ),
              InspectionItemDto(
                categoria: 'Documentos',
                pregunta: 'Permiso de buceo autorizado por la AAMM',
                respuesta: 'N/A',
                criticidad: 'Tolerable',
              ),
            ] else ...[
              InspectionItemDto(
                categoria: 'Documentación',
                pregunta: 'Certificado de navegabilidad vigente',
                respuesta: 'NC',
                criticidad: 'Tolerable',
                comentario: 'Vencido',
                potencialidad: 'ALTA',
              ),
              InspectionItemDto(
                categoria: 'Seguridad, higiene y emergencias',
                pregunta: 'Luces y balizas operativas',
                respuesta: 'C',
                criticidad: 'Tolerable',
                potencialidad: 'MEDIA',
              ),
            ],
          ],
    fotosGeneralesPaths: fotoPath == null ? [] : [fotoPath],
    fotosExtraObservaciones: const [],
    totalCumple: 1,
    totalNoCumple: 1,
    totalNoAplica: 1,
    totalIntolerables: 0,
    sumPesoCumple: 1,
    sumPesoNoCumple: 1,
    observacionPrevencionista: 'Sin observaciones.',
    verificacionesBuceo: esBuceo ? {'IV. Autorización de la Faena': true} : {},
  );
}
