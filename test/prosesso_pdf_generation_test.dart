import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/prosesso/services/prosesso_pdf_service.dart';
import 'package:jf_innova_app/features/prosesso/domain/models/prosesso_report_data.dart';
import 'package:jf_innova_app/features/prosesso/domain/models/prosesso_extintor_state.dart';

/// Tests de generación de PDFs de Prosesso. Detectan errores de
/// renderizado del paquete `pdf` (asserts internos como
/// `borderRadius == null`, fuentes sin Unicode, etc.) sin necesidad
/// de levantar la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> _loadFont(String name) async {
    final f = File('assets/fonts/$name');
    return f.readAsBytes();
  }

  Future<ProsessoPdfIsolateParams> _buildParams({
    required bool conNc,
    required bool conFirma,
    int extintores = 1,
  }) async {
    final fontReg = await _loadFont('OpenSans-Regular.ttf');
    final fontBold = await _loadFont('OpenSans-Bold.ttf');

    final puntos = List.generate(
      9,
      (i) => PuntoEstadoResumenProsesso(
        pregunta: 'Punto ${i + 1}',
        estado: (conNc && i == 2)
            ? EstadoPuntoProsesso.noCumple
            : EstadoPuntoProsesso.cumple,
        observacion: (conNc && i == 2) ? 'Falla detectada' : null,
      ),
    );

    final exts = List.generate(
      extintores,
      (i) => ExtintorProsessoResumen(
        numero: i + 1,
        planta: 'Planta A',
        ubicacion: 'Sala $i',
        ubicacionSector: 'Sector A',
        certificado: 'CERT-${i + 1}',
        anio: 2025,
        tipo: 'PQS',
        peso: '6',
        kg: 'KG',
        fechaVencimiento: '2026-12-31',
        observaciones: i == 0
            ? 'Observación de prueba con tildes: áéíóú ñ'
            : null,
        puntos: puntos,
        fotoPaths: const [],
      ),
    );

    final data = ProsessoReportData(
      visitaId: 'visita-123',
      certNumero: '2026/1',
      fechaServicio: '08-05-2026',
      clienteNombre: 'Cliente Prueba',
      clienteDireccion: 'Calle Falsa 123',
      realizadoPor: 'Técnico Pérez',
      fechaRegistro: '08-05-2026',
      extintores: exts,
      signatureBytes: conFirma ? Uint8List.fromList(_pngTransparente()) : null,
    );

    return ProsessoPdfIsolateParams(
      data: data,
      fontRegular: fontReg,
      fontBold: fontBold,
      logoBytes: null,
      firmaBytes: data.signatureBytes,
      fotosBytes: const {},
    );
  }

  group('Prosesso PDF Service - Generación', () {
    test('genera registro y certificado SIN hallazgos (caso simple)', () async {
      final params = await _buildParams(conNc: false, conFirma: false);
      final bundle = await generateProsessoPdfsEntryPoint(params);
      expect(bundle.registroBytes.length, greaterThan(1000));
      expect(bundle.certificadoBytes.length, greaterThan(1000));
    });

    test(
      'genera registro y certificado CON hallazgos NC (banner activo)',
      () async {
        final params = await _buildParams(conNc: true, conFirma: false);
        final bundle = await generateProsessoPdfsEntryPoint(params);
        expect(bundle.registroBytes.length, greaterThan(1000));
        expect(bundle.certificadoBytes.length, greaterThan(1000));
      },
    );

    test('genera con varios extintores (3) sin crash', () async {
      final params = await _buildParams(
        conNc: true,
        conFirma: false,
        extintores: 3,
      );
      final bundle = await generateProsessoPdfsEntryPoint(params);
      expect(bundle.registroBytes.length, greaterThan(2000));
      expect(bundle.certificadoBytes.length, greaterThan(1000));
    });
  });
}

// PNG 1×1 transparente válido para evitar fallos al cargar firma vacía.
List<int> _pngTransparente() => const [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];
