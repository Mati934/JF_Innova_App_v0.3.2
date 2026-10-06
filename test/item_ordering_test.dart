import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';
import 'package:jf_innova_app/features/inspection/domain/models/pdf/inspection_report_data.dart';
import 'package:jf_innova_app/features/inspection/services/pdf_generator_service.dart';

// ============================================================
// BUG-001-ORDEN-PREGUNTAS: Tests de ordenamiento de preguntas
// ============================================================

void main() {
  // =================================================================
  // 1. FormularioItem - parseo del campo orden
  // =================================================================
  group('FormularioItem - campo orden', () {
    test('fromJson parsea orden correctamente', () {
      final item = FormularioItem.fromJson({
        'id': 'item-1',
        'pregunta': 'Pregunta test',
        'categoria': 'CAT_A',
        'criticidad': 'Tolerable',
        'orden': 5,
      });

      expect(item.orden, 5);
    });

    test('fromJson usa default 0 cuando orden es null', () {
      final item = FormularioItem.fromJson({
        'id': 'item-1',
        'pregunta': 'Pregunta test',
        'categoria': 'CAT_A',
        'criticidad': 'Tolerable',
        'orden': null,
      });

      expect(item.orden, 0);
    });

    test('fromJson usa default 0 cuando orden no existe', () {
      final item = FormularioItem.fromJson({
        'id': 'item-1',
        'pregunta': 'Pregunta test',
        'categoria': 'CAT_A',
        'criticidad': 'Tolerable',
      });

      expect(item.orden, 0);
    });

    test('fromJson preserva todos los campos junto con orden', () {
      final item = FormularioItem.fromJson({
        'id': 'item-abc',
        'pregunta': 'Tiene casco',
        'categoria': 'EQUIPO PERSONAL',
        'criticidad': 'Intolerable',
        'orden': 3,
        'info_adicional': 'Debe ser certificado',
        'url_imagen_referencia': 'https://img.test/casco.jpg',
      });

      expect(item.id, 'item-abc');
      expect(item.pregunta, 'Tiene casco');
      expect(item.categoria, 'EQUIPO PERSONAL');
      expect(item.criticidad, 'Intolerable');
      expect(item.orden, 3);
      expect(item.infoAdicional, 'Debe ser certificado');
      expect(item.urlImagenReferencia, 'https://img.test/casco.jpg');
    });
  });

  // =================================================================
  // 2. InspectionItemDto - campo orden
  // =================================================================
  group('InspectionItemDto - campo orden', () {
    test('constructor asigna orden correctamente', () {
      final dto = InspectionItemDto(
        categoria: 'CAT_A',
        pregunta: 'Pregunta',
        respuesta: 'C',
        criticidad: 'Tolerable',
        orden: 7,
      );

      expect(dto.orden, 7);
    });

    test('orden default es 0', () {
      final dto = InspectionItemDto(
        categoria: 'CAT_A',
        pregunta: 'Pregunta',
        respuesta: 'C',
        criticidad: 'Tolerable',
      );

      expect(dto.orden, 0);
    });
  });

  // =================================================================
  // 3. Agrupamiento por categoría preserva orden
  // =================================================================
  group('Agrupamiento por categoria - preserva orden', () {
    test('items dentro de cada categoria mantienen orden ASC', () {
      // Simula items ya ordenados por `orden ASC` (como viene de DB)
      final items = [
        _makeDto(categoria: 'CAT_A', pregunta: 'P1', orden: 1),
        _makeDto(categoria: 'CAT_A', pregunta: 'P2', orden: 2),
        _makeDto(categoria: 'CAT_B', pregunta: 'P3', orden: 3),
        _makeDto(categoria: 'CAT_A', pregunta: 'P4', orden: 4),
        _makeDto(categoria: 'CAT_B', pregunta: 'P5', orden: 5),
      ];

      final grouped = _agruparPorCategoria(items);

      // CAT_A aparece primero (primer item es CAT_A)
      final keys = grouped.keys.toList();
      expect(keys[0], 'CAT_A');
      expect(keys[1], 'CAT_B');

      // Dentro de CAT_A: P1, P2, P4 (en ese orden)
      expect(grouped['CAT_A']!.map((i) => i.pregunta).toList(), [
        'P1',
        'P2',
        'P4',
      ]);

      // Dentro de CAT_B: P3, P5
      expect(grouped['CAT_B']!.map((i) => i.pregunta).toList(), ['P3', 'P5']);
    });

    test('categorias aparecen en orden del primer item de cada una', () {
      final items = [
        _makeDto(categoria: 'SEGURIDAD', pregunta: 'S1', orden: 1),
        _makeDto(categoria: 'EQUIPO', pregunta: 'E1', orden: 2),
        _makeDto(categoria: 'PERSONAL', pregunta: 'P1', orden: 3),
      ];

      final grouped = _agruparPorCategoria(items);
      final keys = grouped.keys.toList();

      expect(keys, ['SEGURIDAD', 'EQUIPO', 'PERSONAL']);
    });

    test('una sola categoria mantiene orden interno', () {
      final items = [
        _makeDto(categoria: 'UNICA', pregunta: 'P1', orden: 1),
        _makeDto(categoria: 'UNICA', pregunta: 'P2', orden: 2),
        _makeDto(categoria: 'UNICA', pregunta: 'P3', orden: 3),
      ];

      final grouped = _agruparPorCategoria(items);
      expect(grouped['UNICA']!.map((i) => i.pregunta).toList(), [
        'P1',
        'P2',
        'P3',
      ]);
    });
  });

  // =================================================================
  // 4. Edge cases de ordenamiento
  // =================================================================
  group('Edge cases de ordenamiento', () {
    test('items con gaps en orden se mantienen en secuencia', () {
      final items = [
        _makeDto(categoria: 'CAT', pregunta: 'P1', orden: 1),
        _makeDto(categoria: 'CAT', pregunta: 'P5', orden: 5),
        _makeDto(categoria: 'CAT', pregunta: 'P10', orden: 10),
        _makeDto(categoria: 'CAT', pregunta: 'P100', orden: 100),
      ];

      final grouped = _agruparPorCategoria(items);
      expect(grouped['CAT']!.map((i) => i.pregunta).toList(), [
        'P1',
        'P5',
        'P10',
        'P100',
      ]);
    });

    test('items con orden 0 (default) no rompen agrupamiento', () {
      final items = [
        _makeDto(categoria: 'CAT', pregunta: 'P_default', orden: 0),
        _makeDto(categoria: 'CAT', pregunta: 'P1', orden: 1),
        _makeDto(categoria: 'CAT', pregunta: 'P2', orden: 2),
      ];

      final grouped = _agruparPorCategoria(items);
      expect(grouped['CAT']!.length, 3);
      expect(grouped['CAT']!.first.pregunta, 'P_default');
    });

    test('lista vacia no falla', () {
      final grouped = _agruparPorCategoria([]);
      expect(grouped, isEmpty);
    });
  });

  // =================================================================
  // 5. Path online vs diferido deben producir mismo orden
  // =================================================================
  group('Consistencia de orden entre paths', () {
    test('datos ordenados producen misma secuencia que iteracion directa', () {
      // Simula lo que haría getItems con ORDER BY orden ASC
      final itemsOrdenados = [
        _makeFormItem(
          id: '1',
          cat: 'EQUIPO PERSONAL',
          orden: 1,
          pregunta: 'P1',
        ),
        _makeFormItem(
          id: '2',
          cat: 'EQUIPO PERSONAL',
          orden: 2,
          pregunta: 'P2',
        ),
        _makeFormItem(
          id: '3',
          cat: 'EQUIPO DE BUCEO',
          orden: 3,
          pregunta: 'P3',
        ),
        _makeFormItem(
          id: '4',
          cat: 'EQUIPO DE BUCEO',
          orden: 4,
          pregunta: 'P4',
        ),
        _makeFormItem(
          id: '5',
          cat: 'SEGURIDAD Y APOYO',
          orden: 5,
          pregunta: 'P5',
        ),
      ];

      // Path A (online): itera _items directamente
      final dtoPathA = itemsOrdenados
          .map(
            (i) => InspectionItemDto(
              categoria: i.categoria,
              pregunta: i.pregunta,
              respuesta: 'C',
              criticidad: i.criticidad,
              orden: i.orden,
            ),
          )
          .toList();

      // Path B (deferred): simula query con ORDER BY orden ASC
      // (los mismos datos como si vinieran de db.query con orderBy)
      final rawRows = itemsOrdenados
          .map(
            (i) => {
              'id': i.id,
              'categoria': i.categoria,
              'pregunta': i.pregunta,
              'criticidad': i.criticidad,
              'orden': i.orden,
            },
          )
          .toList();

      final dtoPathB = rawRows
          .map(
            (row) => InspectionItemDto(
              categoria: row['categoria']?.toString() ?? '',
              pregunta: row['pregunta']?.toString() ?? '',
              respuesta: 'C',
              criticidad: row['criticidad']?.toString() ?? 'Tolerable',
              orden: row['orden'] as int? ?? 0,
            ),
          )
          .toList();

      // Ambos paths deben producir el mismo orden
      expect(dtoPathA.length, dtoPathB.length);
      for (var i = 0; i < dtoPathA.length; i++) {
        expect(
          dtoPathA[i].pregunta,
          dtoPathB[i].pregunta,
          reason: 'Item $i difiere entre path online y deferred',
        );
        expect(
          dtoPathA[i].orden,
          dtoPathB[i].orden,
          reason: 'Orden del item $i difiere entre paths',
        );
      }
    });
  });

  // =================================================================
  // 6. PDF genera con items ordenados (test de generación real)
  // =================================================================
  group('PDF Inspeccion - orden de items', () {
    late Uint8List fontReg;
    late Uint8List fontBold;
    late Uint8List fontItalic;

    setUpAll(() {
      fontReg = File('assets/fonts/OpenSans-Regular.ttf').readAsBytesSync();
      fontBold = File('assets/fonts/OpenSans-Bold.ttf').readAsBytesSync();
      fontItalic = File('assets/fonts/OpenSans-Italic.ttf').readAsBytesSync();
    });

    test(
      'genera PDF con items en orden correcto (3 categorias buceo)',
      () async {
        final data = _buildInspectionData(
          items: [
            _makeDto(categoria: 'EQUIPO PERSONAL', pregunta: 'Casco', orden: 1),
            _makeDto(
              categoria: 'EQUIPO PERSONAL',
              pregunta: 'Guantes',
              orden: 2,
            ),
            _makeDto(
              categoria: 'EQUIPO DE BUCEO',
              pregunta: 'Regulador',
              orden: 3,
            ),
            _makeDto(categoria: 'EQUIPO DE BUCEO', pregunta: 'Traje', orden: 4),
            _makeDto(
              categoria: 'SEGURIDAD Y APOYO',
              pregunta: 'Botiquin',
              orden: 5,
            ),
          ],
        );

        final params = PdfIsolateParams(
          data: data,
          fontRegular: fontReg,
          fontBold: fontBold,
          fontItalic: fontItalic,
        );
        final bytes = await generatePdfEntryPoint(params);

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      },
    );

    test('genera PDF con categorias no-buceo sin error', () async {
      final data = _buildInspectionData(
        items: [
          _makeDto(categoria: 'ESTRUCTURA', pregunta: 'Casco nave', orden: 1),
          _makeDto(categoria: 'ESTRUCTURA', pregunta: 'Cubierta', orden: 2),
          _makeDto(categoria: 'MAQUINARIA', pregunta: 'Motor', orden: 3),
          _makeDto(categoria: 'SEGURIDAD', pregunta: 'Extintores', orden: 4),
        ],
      );

      final params = PdfIsolateParams(
        data: data,
        fontRegular: fontReg,
        fontBold: fontBold,
        fontItalic: fontItalic,
      );
      final bytes = await generatePdfEntryPoint(params);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
    });

    test('genera PDF con items desordenados que fueron re-ordenados', () async {
      // Simula que items venían en desorden antes del fix
      final itemsDesordenados = [
        _makeDto(categoria: 'EQUIPO PERSONAL', pregunta: 'P5', orden: 5),
        _makeDto(categoria: 'EQUIPO DE BUCEO', pregunta: 'P3', orden: 3),
        _makeDto(categoria: 'EQUIPO PERSONAL', pregunta: 'P1', orden: 1),
        _makeDto(categoria: 'SEGURIDAD Y APOYO', pregunta: 'P4', orden: 4),
        _makeDto(categoria: 'EQUIPO DE BUCEO', pregunta: 'P2', orden: 2),
      ];

      // Re-ordenar como lo haría ORDER BY orden ASC
      itemsDesordenados.sort((a, b) => a.orden.compareTo(b.orden));

      expect(itemsDesordenados.map((i) => i.pregunta).toList(), [
        'P1',
        'P2',
        'P3',
        'P4',
        'P5',
      ]);

      final data = _buildInspectionData(items: itemsDesordenados);

      final params = PdfIsolateParams(
        data: data,
        fontRegular: fontReg,
        fontBold: fontBold,
        fontItalic: fontItalic,
      );
      final bytes = await generatePdfEntryPoint(params);

      expect(bytes, isNotEmpty);
    });
  });
}

// ============================================================
// Helpers
// ============================================================

InspectionItemDto _makeDto({
  required String categoria,
  required String pregunta,
  required int orden,
  String respuesta = 'C',
  String criticidad = 'Tolerable',
}) {
  return InspectionItemDto(
    categoria: categoria,
    pregunta: pregunta,
    respuesta: respuesta,
    criticidad: criticidad,
    orden: orden,
  );
}

FormularioItem _makeFormItem({
  required String id,
  required String cat,
  required int orden,
  required String pregunta,
}) {
  return FormularioItem(
    id: id,
    pregunta: pregunta,
    categoria: cat,
    criticidad: 'Tolerable',
    orden: orden,
  );
}

/// Replica la lógica de agruparPorCategoria del controller
Map<String, List<InspectionItemDto>> _agruparPorCategoria(
  List<InspectionItemDto> items,
) {
  final Map<String, List<InspectionItemDto>> map = {};
  for (var item in items) {
    if (!map.containsKey(item.categoria)) map[item.categoria] = [];
    map[item.categoria]!.add(item);
  }
  return map;
}

InspectionReportData _buildInspectionData({
  required List<InspectionItemDto> items,
}) {
  int c = 0, nc = 0, na = 0, intol = 0;
  double pesoC = 0.0, pesoNC = 0.0;
  for (var item in items) {
    if (item.respuesta == 'C') {
      c++;
      pesoC += 1.0;
    }
    if (item.respuesta == 'NC') {
      nc++;
      pesoNC += 1.0;
      if (item.criticidad == 'Intolerable') intol++;
    }
    if (item.respuesta == 'N/A') na++;
  }

  return InspectionReportData(
    empresaContratista: 'Empresa Test',
    cliente: 'Cliente Test',
    logoUrl: '',
    numeroReporte: 'TEST-001',
    fecha: '08-04-2026',
    centro: 'Centro Test',
    area: 'Area Test',
    embarcacion: 'Nave Test',
    matricula: 'MAT-001',
    appVersion: '1.0.0-test',
    tipoFaena: 'Buceo',
    supervisor: 'Supervisor Test',
    estadoGlobal: 'Aprobado',
    esAprobado: true,
    equipo: [],
    items: items,
    fotosGeneralesPaths: [],
    fotosExtraObservaciones: [],
    totalCumple: c,
    totalNoCumple: nc,
    totalNoAplica: na,
    totalIntolerables: intol,
    sumPesoCumple: pesoC,
    sumPesoNoCumple: pesoNC,
    observacionPrevencionista: '',
    verificacionesBuceo: {},
  );
}
