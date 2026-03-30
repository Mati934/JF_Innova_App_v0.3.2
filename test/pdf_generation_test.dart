import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

// Extintores
import 'package:jf_innova_app/features/extintores/domain/models/extintor_report_data.dart';
import 'package:jf_innova_app/features/extintores/services/extintor_pdf_generator_service.dart';

// Visitas
import 'package:jf_innova_app/features/visits/domain/models/pdf/visit_report_data.dart';
import 'package:jf_innova_app/features/visits/services/visit_pdf_generator_service.dart';

/// Carga una fuente TTF desde assets/ (sin rootBundle).
Uint8List _loadFont(String name) =>
    File('assets/fonts/$name').readAsBytesSync();

/// Genera datos dummy de ExtintorReportData con N extintores.
ExtintorReportData _extintorData({
  int cantidadExtintores = 1,
  bool conNC = false,
  bool conFotos = false,
  bool conActividades = false,
  bool conObservaciones = false,
}) {
  final extintores = List.generate(cantidadExtintores, (i) {
    final puntosNC = conNC
        ? [
            PuntoNCResumen(
              pregunta: 'Extintor con sello de seguridad',
              observacion: 'Sello roto',
            ),
            PuntoNCResumen(
              pregunta: 'Extintor con presion adecuada',
              observacion: null,
            ),
          ]
        : <PuntoNCResumen>[];
    return ExtintorResumenItem(
      numero: i + 1,
      matricula: i == 0 ? 'MAT-${i + 1}' : null,
      tipoExtintor: i.isEven ? 'PQS 6kg' : 'CO2 5kg',
      todosCumplen: !conNC,
      totalPuntos: 18,
      puntosNC: puntosNC,
      fotoPaths: conFotos ? ['fake/path.jpg'] : [],
    );
  });

  return ExtintorReportData(
    empresa: 'Empresa Test',
    region: 'MAGALLANES',
    oficina: 'PUNTA ARENAS',
    lugarInspeccion: 'BODEGA CENTRAL',
    profesional: 'Juan Perez',
    fonoProfesional: '+56912345678',
    correoProfesional: 'juan@test.cl',
    jefaturaCargo: 'Maria Lopez',
    origenVisita: 'Programa SSO',
    fecha: '30-03-2026',
    horaInicio: '09:00',
    horaTermino: '12:00',
    emailEmpresa1: 'contacto@empresa.cl',
    emailEmpresa2: conObservaciones ? 'otro@empresa.cl' : '',
    checkReunion: conActividades,
    checkSenaletica: false,
    checkCapacitacion: conActividades,
    checkVisitaSso: false,
    checkCharla: false,
    checkInvestigacion: false,
    checkInspeccionSso: conActividades,
    checkObsConductual: false,
    checkOtro: conActividades,
    otroActividadTexto: conActividades ? 'Revision general' : '',
    apuntesObservaciones: conObservaciones
        ? 'Observacion general de la inspeccion.'
        : '',
    extintores: extintores,
  );
}

/// Genera datos dummy de VisitReportData.
VisitReportData _visitData({bool conChecklist = true}) {
  return VisitReportData(
    profesional: 'Pedro Inspector',
    fonoProfesional: '+56987654321',
    correoProfesional: 'pedro@test.cl',
    empresa: 'Empresa ABC',
    region: 'MAGALLANES',
    centro: 'PUNTA ARENAS',
    jefaturaCargo: 'Jefe SSO',
    origenVisita: 'Programa',
    fecha: '30-03-2026',
    horaInicio: '08:00',
    horaTermino: '11:30',
    emailEmpresa1: 'empresa@test.cl',
    emailEmpresa2: '',
    checkReunion: true,
    checkSenaletica: false,
    checkCapacitacion: true,
    checkVisitaSso: false,
    checkCharla: false,
    checkInvestigacion: false,
    checkInspeccionSso: true,
    checkObsConductual: false,
    checkOtro: false,
    otroActividadTexto: '',
    tipoChecklist: conChecklist ? 'VISITA_005' : null,
    checklistItems: conChecklist
        ? [
            VisitChecklistItemDto(
              categoria: 'ELECTRICO',
              pregunta: 'Tableros electricos cerrados',
              respuesta: 'C',
              criticidad: null,
              observacion: '',
            ),
            VisitChecklistItemDto(
              categoria: 'ELECTRICO',
              pregunta: 'Cables en buen estado',
              respuesta: 'NC',
              criticidad: 'Moderado',
              observacion: 'Cable pelado sector norte',
            ),
          ]
        : [],
    apuntesObservaciones: 'Sin observaciones adicionales.',
    signatureImage: null,
    fotosPaths: [],
  );
}

void main() {
  late Uint8List fontReg;
  late Uint8List fontBold;

  setUpAll(() {
    fontReg = _loadFont('OpenSans-Regular.ttf');
    fontBold = _loadFont('OpenSans-Bold.ttf');
  });

  // ===================================================================
  // EXTINTORES PDF TESTS
  // ===================================================================
  group('PDF Extintores - Generacion', () {
    test('genera PDF basico con 1 extintor conforme', () async {
      final params = ExtintorPdfIsolateParams(
        data: _extintorData(),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
      // Verificar que es un PDF valido (empieza con %PDF)
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF con multiples extintores conformes', () async {
      final params = ExtintorPdfIsolateParams(
        data: _extintorData(cantidadExtintores: 5),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF con extintores con hallazgos NC', () async {
      final params = ExtintorPdfIsolateParams(
        data: _extintorData(cantidadExtintores: 3, conNC: true),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF con actividades realizadas', () async {
      final params = ExtintorPdfIsolateParams(
        data: _extintorData(conActividades: true),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF con observaciones', () async {
      final params = ExtintorPdfIsolateParams(
        data: _extintorData(conObservaciones: true),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF completo (NC + actividades + observaciones)', () async {
      final params = ExtintorPdfIsolateParams(
        data: _extintorData(
          cantidadExtintores: 5,
          conNC: true,
          conActividades: true,
          conObservaciones: true,
        ),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF con logo', () async {
      Uint8List? logoBytes;
      final logoFile = File('assets/images/LogoJFInnova2.png');
      if (logoFile.existsSync()) {
        logoBytes = logoFile.readAsBytesSync();
      }

      final params = ExtintorPdfIsolateParams(
        data: _extintorData(cantidadExtintores: 2, conNC: true),
        fontRegular: fontReg,
        fontBold: fontBold,
        logoBytes: logoBytes,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF con campos vacios (caso minimo)', () async {
      final data = ExtintorReportData(
        empresa: '',
        region: '',
        oficina: '',
        lugarInspeccion: '',
        profesional: '',
        fonoProfesional: '',
        correoProfesional: '',
        jefaturaCargo: '',
        origenVisita: '',
        fecha: '01-01-2026',
        horaInicio: '--:--',
        horaTermino: '--:--',
        emailEmpresa1: '',
        emailEmpresa2: '',
        checkReunion: false,
        checkSenaletica: false,
        checkCapacitacion: false,
        checkVisitaSso: false,
        checkCharla: false,
        checkInvestigacion: false,
        checkInspeccionSso: false,
        checkObsConductual: false,
        checkOtro: false,
        apuntesObservaciones: '',
        extintores: [
          ExtintorResumenItem(
            numero: 1,
            todosCumplen: true,
            totalPuntos: 0,
            puntosNC: [],
            fotoPaths: [],
          ),
        ],
      );

      final params = ExtintorPdfIsolateParams(
        data: data,
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF con caracteres especiales en texto', () async {
      final data = ExtintorReportData(
        empresa: 'Empresa con acentos: arbol compania',
        region: 'REGION DE MAGALLANES Y ANTARTICA',
        oficina: 'OFICINA #1 - SECTOR A/B',
        lugarInspeccion: 'BODEGA CENTRAL (PISO 2)',
        profesional: 'Jose Maria Garcia',
        fonoProfesional: '+56912345678',
        correoProfesional: 'jose@test.cl',
        jefaturaCargo: 'Maria del Carmen',
        origenVisita: 'Programa SSO 2026',
        fecha: '30-03-2026',
        horaInicio: '09:00',
        horaTermino: '17:30',
        emailEmpresa1: 'test@empresa.cl',
        emailEmpresa2: '',
        checkReunion: true,
        checkSenaletica: true,
        checkCapacitacion: true,
        checkVisitaSso: true,
        checkCharla: true,
        checkInvestigacion: true,
        checkInspeccionSso: true,
        checkObsConductual: true,
        checkOtro: true,
        otroActividadTexto: 'Actividad especial con numeros 123',
        apuntesObservaciones:
            'Linea 1\nLinea 2\nContenido con parentesis (algo) y barras /abc/ y brackers [test]',
        extintores: [
          ExtintorResumenItem(
            numero: 1,
            matricula: 'MAT-001/A',
            tipoExtintor: 'PQS 6kg (ABC)',
            todosCumplen: false,
            totalPuntos: 18,
            puntosNC: [
              PuntoNCResumen(
                pregunta: 'Punto con "comillas" y porcentaje 100%',
                observacion: 'Obs con & y # especiales',
              ),
            ],
            fotoPaths: [],
          ),
        ],
      );

      final params = ExtintorPdfIsolateParams(
        data: data,
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateExtintorPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });
  });

  // ===================================================================
  // VISITAS PDF TESTS
  // ===================================================================
  group('PDF Visitas - Generacion', () {
    test('genera PDF basico de visita con checklist', () async {
      final params = VisitPdfIsolateParams(
        data: _visitData(),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateVisitPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF de visita sin checklist', () async {
      final params = VisitPdfIsolateParams(
        data: _visitData(conChecklist: false),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateVisitPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF de visita con campos minimos', () async {
      final data = VisitReportData(
        profesional: '',
        fonoProfesional: '',
        correoProfesional: '',
        empresa: '',
        region: '',
        centro: '',
        jefaturaCargo: '',
        origenVisita: '',
        fecha: '01-01-2026',
        horaInicio: '--:--',
        horaTermino: '--:--',
        emailEmpresa1: '',
        emailEmpresa2: '',
        checkReunion: false,
        checkSenaletica: false,
        checkCapacitacion: false,
        checkVisitaSso: false,
        checkCharla: false,
        checkInvestigacion: false,
        checkInspeccionSso: false,
        checkObsConductual: false,
        checkOtro: false,
        otroActividadTexto: '',
        tipoChecklist: null,
        checklistItems: [],
        apuntesObservaciones: '',
        signatureImage: null,
        fotosPaths: [],
      );

      final params = VisitPdfIsolateParams(
        data: data,
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final bytes = await generateVisitPdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });
  });

  // ===================================================================
  // EXTINTORES - TEST DE MODELOS
  // ===================================================================
  group('ExtintorReportData - Modelos', () {
    test('ExtintorResumenItem detecta todosCumplen correctamente', () {
      final conforme = ExtintorResumenItem(
        numero: 1,
        todosCumplen: true,
        totalPuntos: 18,
        puntosNC: [],
        fotoPaths: [],
      );
      expect(conforme.todosCumplen, isTrue);
      expect(conforme.puntosNC, isEmpty);

      final noConforme = ExtintorResumenItem(
        numero: 2,
        todosCumplen: false,
        totalPuntos: 18,
        puntosNC: [PuntoNCResumen(pregunta: 'Sello roto')],
        fotoPaths: [],
      );
      expect(noConforme.todosCumplen, isFalse);
      expect(noConforme.puntosNC, hasLength(1));
    });

    test('PuntoNCResumen maneja observacion nullable', () {
      final conObs = PuntoNCResumen(pregunta: 'Test', observacion: 'Detalle');
      expect(conObs.observacion, 'Detalle');

      final sinObs = PuntoNCResumen(pregunta: 'Test');
      expect(sinObs.observacion, isNull);
    });
  });
}
