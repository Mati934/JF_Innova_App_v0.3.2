import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/inspection/domain/models/pdf/inspection_report_data.dart';
import 'package:jf_innova_app/features/inspection/services/pdf_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List fontReg;
  late Uint8List fontBold;
  late Uint8List fontItalic;
  late String validImagePath;
  late String invalidImagePath;

  setUpAll(() async {
    fontReg = await File('assets/fonts/OpenSans-Regular.ttf').readAsBytes();
    fontBold = await File('assets/fonts/OpenSans-Bold.ttf').readAsBytes();
    fontItalic = await File('assets/fonts/OpenSans-Italic.ttf').readAsBytes();

    final dir = await Directory.systemTemp.createTemp('inspection_pdf_test_');
    validImagePath = 'assets/images/aquachile.png';
    final invalidFile = File('${dir.path}/broken.bin');
    await invalidFile.writeAsBytes([1, 2, 3, 4, 5, 6]);
    invalidImagePath = invalidFile.path;
  });

  PdfIsolateParams paramsFor(InspectionReportData data) {
    return PdfIsolateParams(
      data: data,
      fontRegular: fontReg,
      fontBold: fontBold,
      fontItalic: fontItalic,
      logoBytes: null,
    );
  }

  group('Inspection PDF - Buceo', () {
    test('genera PDF basico sin crash', () async {
      final bytes = await generatePdfEntryPoint(paramsFor(_basicData()));

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      expect(bytes.length, greaterThan(1000));
    });

    test('genera PDF con hallazgos y todos los anexos fotograficos', () async {
      final bytes = await generatePdfEntryPoint(
        paramsFor(_fullData(validImagePath)),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      expect(bytes.length, greaterThan(1500));
    });

    test('genera PDF aunque una foto sea invalida', () async {
      final bytes = await generatePdfEntryPoint(
        paramsFor(_fullData(invalidImagePath)),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test(
      'genera informe extenso con grillas fotograficas y observacion multilinea',
      () async {
        final bytes = await generatePdfEntryPoint(
          paramsFor(_stressData(validImagePath)),
        );

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
        expect(bytes.length, greaterThan(5000));
      },
    );

    test('genera PDF con estado y datos opcionales vacios', () async {
      final bytes = await generatePdfEntryPoint(
        paramsFor(_dataWithEmptyOptionalValues()),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });
  });

  group('Inspection PDF - No Buceo', () {
    test('genera PDF no-buceo sin crash (checklist clasico)', () async {
      final bytes = await generatePdfEntryPoint(paramsFor(_nonBuceoData()));

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      expect(bytes.length, greaterThan(1000));
    });
  });
}

InspectionReportData _basicData() {
  return InspectionReportData(
    empresaProveedor: 'SERVIMAF',
    empresaContratista: 'Brisa Austral',
    cliente: 'AquaChile',
    logoUrl: '',
    numeroReporte: '312',
    fecha: '24/06/2026',
    centro: 'Centro Detif',
    area: 'Area Los Lagos',
    embarcacion: 'Santa Maria',
    matricula: 'S/N',
    esConsecutiva: false,
    appVersion: 'v0.2.0',
    encargadoCentro: 'Encargado Centro',
    profesional: 'Mati',
    tipoFaena: 'INSPECCION DE BUCEO',
    supervisor: 'Harry Falbaum',
    estadoGlobal: 'HABILITADA',
    esAprobado: true,
    equipo: [
      PersonalDto(
        nombre: 'Cristian Loncon',
        rut: '15.289.611-5',
        cargo: 'Buzo',
        matricula: '531191',
        rolEnFaena: 'Optima',
      ),
    ],
    items: [
      InspectionItemDto(
        categoria: 'I. Equipo Personal',
        pregunta: 'Traje de buceo completo',
        respuesta: 'C',
        criticidad: 'Tolerable',
        comentario: '',
        orden: 1,
      ),
    ],
    fotosGeneralesPaths: const [],
    fotosExtraObservaciones: const [],
    totalCumple: 6,
    totalNoCumple: 0,
    totalNoAplica: 0,
    totalIntolerables: 0,
    sumPesoCumple: 6,
    sumPesoNoCumple: 0,
    observacionPrevencionista: 'Sin observaciones.',
    verificacionesBuceo: const {
      'IV. Autorizacion de la Faena': true,
      'V. Induccion Centro de Cultivo': true,
      'VI. Permiso de Buceo (Centro Correcto)': true,
      'VII. Plan de Contingencias': true,
      'VIII. Examenes Ocupacionales Vigentes': true,
    },
    horaInicio: '14:00',
    horaTermino: '15:00',
    compresor1Matricula: 'PMO 4517',
    compresor1Vigencia: '20/11/2026',
    compresor1PH: '12/12/2027',
    compresor1Buzos: '3',
  );
}

InspectionReportData _fullData(String imagePath) {
  return InspectionReportData(
    empresaProveedor: 'SERVIMAF',
    empresaContratista: 'Brisa Austral',
    cliente: 'AquaChile',
    logoUrl: '',
    numeroReporte: '312',
    fecha: '24/06/2026',
    centro: 'Centro Detif',
    area: 'Area Los Lagos',
    embarcacion: 'Santa Maria',
    matricula: 'S/N',
    esConsecutiva: true,
    appVersion: 'v0.2.0',
    encargadoCentro: 'Encargado Centro',
    profesional: 'Mati',
    tipoFaena: 'INSPECCION DE BUCEO',
    supervisor: 'Harry Falbaum',
    estadoGlobal: 'HABILITADA',
    safetyPhotosPaths: {'IV': imagePath, 'V': imagePath},
    safetyObservations: const {
      'IV': 'Autorizacion visible',
      'V': 'Induccion al dia',
    },
    esAprobado: true,
    equipo: [
      PersonalDto(
        nombre: 'Cristian Loncon',
        rut: '15.289.611-5',
        cargo: 'Buzo',
        matricula: '531191',
        rolEnFaena: 'Optima',
      ),
      PersonalDto(
        nombre: 'Harry Falbaum',
        rut: '12.512.704-5',
        cargo: 'Supervisor',
        matricula: '551942',
        rolEnFaena: 'Optima',
      ),
    ],
    items: [
      InspectionItemDto(
        categoria: 'I. Equipo Personal',
        pregunta: 'Traje de buceo completo',
        respuesta: 'C',
        criticidad: 'Tolerable',
        comentario: '',
        orden: 1,
        fotosPaths: [imagePath],
      ),
      InspectionItemDto(
        categoria: 'III. Seguridad y Apoyo',
        pregunta: 'Escalera de ascenso movil instalada',
        respuesta: 'NC',
        criticidad: 'Tolerable',
        comentario: 'Sin escalera portatil.',
        orden: 2,
        fotosPaths: [imagePath],
      ),
    ],
    checklistPhotos: [
      ChecklistPhotoDto(
        numero: 1,
        categoria: 'I. Equipo Personal',
        pregunta: 'Traje de buceo completo',
        respuesta: 'C',
        comentario: '',
        fotosPaths: [imagePath],
      ),
      ChecklistPhotoDto(
        numero: 2,
        categoria: 'III. Seguridad y Apoyo',
        pregunta: 'Escalera de ascenso movil instalada',
        respuesta: 'NC',
        comentario: 'Sin escalera portatil.',
        fotosPaths: [imagePath],
      ),
    ],
    mandatoryPhotos: [
      MandatoryPhotoDto(
        key: 'compresor_general',
        title: 'Compresor General',
        path: imagePath,
      ),
      MandatoryPhotoDto(
        key: 'matriculas_buceo',
        title: 'Matriculas de Buceo',
        path: imagePath,
      ),
      MandatoryPhotoDto(
        key: 'bitacora_compresores',
        title: 'Bitacora de Compresores',
        path: imagePath,
      ),
    ],
    fotosGeneralesPaths: [imagePath, imagePath],
    fotosExtraObservaciones: [
      {'path': imagePath, 'observacion': 'Compresor pintado en rojo.'},
    ],
    totalCumple: 6,
    totalNoCumple: 1,
    totalNoAplica: 0,
    totalIntolerables: 0,
    sumPesoCumple: 6,
    sumPesoNoCumple: 1,
    observacionPrevencionista:
        'Faena de buceo en profundidad menor a 20 metros.',
    verificacionesBuceo: const {
      'IV. Autorizacion de la Faena': true,
      'V. Induccion Centro de Cultivo': true,
      'VI. Permiso de Buceo (Centro Correcto)': true,
      'VII. Plan de Contingencias': true,
      'VIII. Examenes Ocupacionales Vigentes': true,
    },
    horaInicio: '14:00',
    horaTermino: '15:01',
    compresor1Matricula: 'PMO 4517',
    compresor1Vigencia: '20/11/2026',
    compresor1PH: '12/12/2027',
    compresor1Buzos: '3',
  );
}

InspectionReportData _stressData(String imagePath) {
  final items = List.generate(120, (index) {
    final response = index % 11 == 0
        ? 'NC'
        : index % 9 == 0
        ? 'N/A'
        : 'C';
    return InspectionItemDto(
      categoria: 'Categoria ${(index ~/ 12) + 1}',
      pregunta:
          'Verificacion extensa numero ${index + 1} para validar paginacion del informe.',
      respuesta: response,
      criticidad: response == 'NC' ? 'Moderado' : 'Tolerable',
      comentario: response == 'NC' ? 'Hallazgo de prueba para paginacion.' : '',
      orden: index + 1,
      fotosPaths: index % 20 == 0 ? [imagePath] : const [],
    );
  });
  final checklistPhotos = List.generate(12, (index) {
    return ChecklistPhotoDto(
      numero: index + 1,
      categoria: 'Categoria ${(index ~/ 3) + 1}',
      pregunta: 'Evidencia fotografica ${index + 1}',
      respuesta: index % 3 == 0 ? 'NC' : 'C',
      comentario: 'Comentario de evidencia ${index + 1}',
      fotosPaths: [imagePath],
    );
  });

  return InspectionReportData(
    empresaProveedor: 'SERVIMAF',
    empresaContratista: 'Brisa Austral',
    cliente: 'AquaChile',
    logoUrl: '',
    numeroReporte: '999',
    fecha: '24/06/2026',
    centro: 'Centro Detif',
    area: 'Area Los Lagos',
    embarcacion: 'Santa Maria',
    matricula: 'S/N',
    appVersion: 'v0.2.0',
    tipoFaena: 'INSPECCION DE BUCEO',
    supervisor: 'Supervisor',
    estadoGlobal: 'SUSPENDIDA',
    esAprobado: false,
    equipo: const [],
    items: items,
    checklistPhotos: checklistPhotos,
    mandatoryPhotos: [
      MandatoryPhotoDto(
        key: 'compresor_general',
        title: 'Compresor General',
        path: imagePath,
      ),
      MandatoryPhotoDto(
        key: 'matriculas_buceo',
        title: 'Matriculas de Buceo',
        path: imagePath,
      ),
    ],
    fotosGeneralesPaths: [imagePath, imagePath, imagePath, imagePath],
    fotosExtraObservaciones: [
      {'path': imagePath, 'observacion': 'Observacion extensa de prueba.'},
    ],
    totalCumple: 97,
    totalNoCumple: 11,
    totalNoAplica: 12,
    totalIntolerables: 0,
    sumPesoCumple: 97,
    sumPesoNoCumple: 11,
    observacionPrevencionista:
        'Prueba de informe extenso. Esta observacion contiene varias lineas '
        'para verificar que la banda lateral se ajuste a toda la altura del '
        'contenido sin generar una pagina infinita.',
    verificacionesBuceo: const {
      'IV. Autorizacion de la Faena': true,
      'V. Induccion Centro de Cultivo': false,
    },
    horaInicio: '08:00',
    horaTermino: '18:00',
  );
}

InspectionReportData _dataWithEmptyOptionalValues() {
  return InspectionReportData(
    empresaContratista: '',
    cliente: '',
    logoUrl: '',
    numeroReporte: '',
    fecha: '',
    centro: '',
    area: '',
    embarcacion: '',
    matricula: '',
    appVersion: 'v0.2.0',
    tipoFaena: 'INSPECCION DE BUCEO',
    supervisor: '',
    estadoGlobal: '',
    esAprobado: false,
    equipo: const [],
    items: const [],
    fotosGeneralesPaths: const [],
    fotosExtraObservaciones: const [],
    totalCumple: 0,
    totalNoCumple: 0,
    totalNoAplica: 0,
    totalIntolerables: 0,
    sumPesoCumple: 0,
    sumPesoNoCumple: 0,
    observacionPrevencionista: '',
    verificacionesBuceo: const {},
  );
}

InspectionReportData _nonBuceoData() {
  return InspectionReportData(
    empresaProveedor: 'SERVIMAF',
    empresaContratista: 'Empresa Test',
    cliente: 'Cliente Test',
    logoUrl: '',
    numeroReporte: '001',
    fecha: '12/08/2026',
    centro: 'Centro A',
    area: 'Area A',
    embarcacion: 'Embarcacion Test',
    matricula: 'MAT-001',
    esConsecutiva: false,
    appVersion: 'v0.2.0',
    encargadoCentro: 'Encargado',
    profesional: 'Inspector',
    tipoFaena: 'INSPECCION EMBARCACION',
    supervisor: 'Supervisor',
    estadoGlobal: 'HABILITADA',
    esAprobado: true,
    equipo: const [],
    items: [
      InspectionItemDto(
        categoria: 'Estructura',
        pregunta: 'Pasamanos en buen estado',
        respuesta: 'C',
        criticidad: 'Tolerable',
        comentario: '',
        orden: 1,
      ),
      InspectionItemDto(
        categoria: 'Estructura',
        pregunta: 'Escalera de acceso operativa',
        respuesta: 'NC',
        criticidad: 'Moderado',
        comentario: 'Peldaño suelto en parte inferior',
        orden: 2,
      ),
    ],
    fotosGeneralesPaths: const [],
    fotosExtraObservaciones: const [],
    totalCumple: 1,
    totalNoCumple: 1,
    totalNoAplica: 0,
    totalIntolerables: 0,
    sumPesoCumple: 1,
    sumPesoNoCumple: 1,
    observacionPrevencionista: 'Observacion general no buceo.',
    verificacionesBuceo: const {},
  );
}
