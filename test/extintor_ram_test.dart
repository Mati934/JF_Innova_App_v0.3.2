import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:jf_innova_app/features/extintores/domain/models/extintor_state.dart';
import 'package:jf_innova_app/features/extintores/domain/models/extintor_report_data.dart';
import 'package:jf_innova_app/features/extintores/services/extintor_pdf_generator_service.dart';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';

Uint8List _loadFont(String name) =>
    File('assets/fonts/$name').readAsBytesSync();

/// Crea N items dummy de checklist simulando los 18 puntos de inspeccion.
List<FormularioItem> _crearChecklistItems(int count) => List.generate(
  count,
  (i) => FormularioItem(
    id: 'item-$i',
    categoria: 'CAT-${i ~/ 6}',
    pregunta: 'Punto de inspeccion numero ${i + 1}',
    criticidad: 'Moderado',
  ),
);

/// Crea N ExtintorState con checklist items y estados variados.
List<ExtintorState> _crearExtintores(int count, List<FormularioItem> items) =>
    List.generate(count, (i) {
      final ext = ExtintorState.nuevo(numero: i + 1, items: items);
      // Marcar algunos puntos como NC para tests realistas.
      final puntosModificados = ext.puntos.asMap().entries.map((e) {
        if (e.key % 5 == 0) {
          return e.value.copyWith(estado: EstadoExtintor.noCumple);
        }
        return e.value.copyWith(estado: EstadoExtintor.cumple);
      }).toList();
      return ext.copyWith(
        matricula: 'MAT-${i + 1}',
        tipoExtintor: i.isEven ? 'PQS 6kg' : 'CO2 5kg',
        puntos: puntosModificados,
      );
    });

/// Crea ExtintorReportData con N extintores.
ExtintorReportData _reportDataConN(int count) {
  final items = _crearChecklistItems(18);
  final extintores = _crearExtintores(count, items);
  return ExtintorReportData(
    empresa: 'Empresa Stress Test',
    region: 'MAGALLANES',
    oficina: 'OFICINA TEST',
    lugarInspeccion: 'BODEGA CENTRAL',
    profesional: 'Inspector Test',
    fonoProfesional: '+56912345678',
    correoProfesional: 'test@test.cl',
    jefaturaCargo: 'Jefe Test',
    origenVisita: 'Programa SSO',
    fecha: '30-03-2026',
    horaInicio: '09:00',
    horaTermino: '17:00',
    emailEmpresa1: 'e1@test.cl',
    emailEmpresa2: 'e2@test.cl',
    checkReunion: true,
    checkSenaletica: true,
    checkCapacitacion: true,
    checkVisitaSso: true,
    checkCharla: true,
    checkInvestigacion: true,
    checkInspeccionSso: true,
    checkObsConductual: true,
    checkOtro: true,
    otroActividadTexto: 'Actividad especial',
    apuntesObservaciones: 'Observaciones generales del test de carga.',
    extintores: extintores.map(ExtintorResumenItem.fromState).toList(),
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
  // TESTS DE MODELO CON MUCHOS EXTINTORES
  // ===================================================================
  group('ExtintorState - Escala y RAM', () {
    test('crear 10 extintores con 18 puntos cada uno', () {
      final items = _crearChecklistItems(18);
      final extintores = _crearExtintores(10, items);

      expect(extintores.length, 10);
      expect(extintores.first.puntos.length, 18);
      expect(extintores.last.numero, 10);
    });

    test('crear 50 extintores con 18 puntos cada uno', () {
      final items = _crearChecklistItems(18);
      final extintores = _crearExtintores(50, items);

      expect(extintores.length, 50);
      // Total de PuntoExtintorState en memoria = 50 * 18 = 900
      final totalPuntos = extintores.fold<int>(
        0,
        (s, e) => s + e.puntos.length,
      );
      expect(totalPuntos, 900);
    });

    test('crear 100 extintores con 18 puntos cada uno', () {
      final items = _crearChecklistItems(18);
      final extintores = _crearExtintores(100, items);

      expect(extintores.length, 100);
      final totalPuntos = extintores.fold<int>(
        0,
        (s, e) => s + e.puntos.length,
      );
      expect(totalPuntos, 1800);
    });

    test('serializar/deserializar 50 extintores via toDbRow/fromDb', () {
      final items = _crearChecklistItems(18);
      final extintores = _crearExtintores(50, items);

      for (final ext in extintores) {
        final row = ext.toDbRow('visita-test');
        final restored = ExtintorState.fromDb(row: row, items: items);

        expect(restored.numero, ext.numero);
        expect(restored.matricula, ext.matricula);
        expect(restored.tipoExtintor, ext.tipoExtintor);
        expect(restored.puntos.length, ext.puntos.length);
      }
    });

    test('clonarEstados entre extintores preserva integridad', () {
      final items = _crearChecklistItems(18);
      final origen = _crearExtintores(1, items).first;
      final destino = ExtintorState.nuevo(numero: 2, items: items);

      final clonado = destino.clonarEstados(origen);

      expect(clonado.numero, destino.numero); // Mantiene su numero
      expect(clonado.matricula, isNull); // destino no tenia matricula
      for (var i = 0; i < clonado.puntos.length; i++) {
        expect(clonado.puntos[i].estado, origen.puntos[i].estado);
      }
    });
  });

  // ===================================================================
  // TESTS DE GENERACION PDF CON MUCHOS EXTINTORES
  // ===================================================================
  group('PDF Extintores - Carga y escalabilidad', () {
    test('PDF con 10 extintores (caso tipico grande)', () async {
      final params = ExtintorPdfIsolateParams(
        data: _reportDataConN(10),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final sw = Stopwatch()..start();
      final bytes = await generateExtintorPdfEntryPoint(params);
      sw.stop();

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      // PDF de 10 extintores deberia generarse en menos de 5 segundos
      expect(sw.elapsedMilliseconds, lessThan(5000));
      // Reportar tamano para referencia
      // ignore: avoid_print
      print(
        '  10 extintores: ${bytes.length} bytes, ${sw.elapsedMilliseconds}ms',
      );
    });

    test('PDF con 20 extintores (caso extremo realista)', () async {
      final params = ExtintorPdfIsolateParams(
        data: _reportDataConN(20),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final sw = Stopwatch()..start();
      final bytes = await generateExtintorPdfEntryPoint(params);
      sw.stop();

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      expect(sw.elapsedMilliseconds, lessThan(10000));
      // ignore: avoid_print
      print(
        '  20 extintores: ${bytes.length} bytes, ${sw.elapsedMilliseconds}ms',
      );
    });

    test('PDF con 50 extintores (stress test)', () async {
      final params = ExtintorPdfIsolateParams(
        data: _reportDataConN(50),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final sw = Stopwatch()..start();
      final bytes = await generateExtintorPdfEntryPoint(params);
      sw.stop();

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      expect(sw.elapsedMilliseconds, lessThan(30000));
      // ignore: avoid_print
      print(
        '  50 extintores: ${bytes.length} bytes, ${sw.elapsedMilliseconds}ms',
      );
    });

    test('PDF con 100 extintores (limite extremo)', () async {
      final params = ExtintorPdfIsolateParams(
        data: _reportDataConN(100),
        fontRegular: fontReg,
        fontBold: fontBold,
      );

      final sw = Stopwatch()..start();
      final bytes = await generateExtintorPdfEntryPoint(params);
      sw.stop();

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
      // Puede tardar mas, pero debe completarse
      expect(sw.elapsedMilliseconds, lessThan(60000));
      // ignore: avoid_print
      print(
        '  100 extintores: ${bytes.length} bytes, ${sw.elapsedMilliseconds}ms',
      );
    });
  });

  // ===================================================================
  // TESTS DE REPORTE DE DATOS
  // ===================================================================
  group('ExtintorReportData - Estadisticas con muchos extintores', () {
    test('conteo de NC es correcto con 50 extintores', () {
      final data = _reportDataConN(50);

      final conformes = data.extintores.where((e) => e.todosCumplen).length;
      final conNC = data.extintores.length - conformes;
      final totalNC = data.extintores.fold<int>(
        0,
        (s, e) => s + e.puntosNC.length,
      );

      // Cada extintor tiene 18 puntos, cada 5to es NC => 4 NC por extintor
      // (indices 0, 5, 10, 15)
      expect(totalNC, 50 * 4);
      expect(conNC, 50); // Todos tienen al menos 1 NC
      expect(conformes, 0);
    });

    test('fromState preserva datos con muchos extintores', () {
      final items = _crearChecklistItems(18);
      final extintores = _crearExtintores(30, items);

      final resumenes = extintores.map(ExtintorResumenItem.fromState).toList();

      for (var i = 0; i < resumenes.length; i++) {
        expect(resumenes[i].numero, extintores[i].numero);
        expect(resumenes[i].matricula, extintores[i].matricula);
        expect(resumenes[i].tipoExtintor, extintores[i].tipoExtintor);
        expect(resumenes[i].totalPuntos, 18);
        expect(resumenes[i].puntosNC.length, extintores[i].puntosNC.length);
      }
    });
  });
}
