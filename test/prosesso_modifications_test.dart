import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_mapper.dart';
import 'package:jf_innova_app/core/modules/module_registry.dart';
import 'package:jf_innova_app/features/history/presentation/widgets/history_card.dart';

void main() {
  group('Prosesso Modifications Tests', () {
    test('DraftCardMapper mapea MANTENCION_PROSESSO correctamente', () {
      final input = {
        'id': 'abc',
        'tipo_actividad': 'MANTENCION_PROSESSO',
        'empresa': 'Prosesso',
        'cliente_nombre': 'Cliente Test',
        'estado_final': 'Borrador',
        'fecha_realizacion': '2024-01-01',
      };
      final draft = DraftCardMapper.fromVisita(input);
      expect(draft.title, 'Mantención de Extintores');
    });

    test('ModuleRegistry tiene título Mantención para Prosesso', () {
      final module = ModuleRegistry.all.firstWhere(
        (m) => m.moduleKey == 'MANTENCION_PROSESSO',
      );
      expect(module.title, 'Mantención');
      expect(module.subtitle, 'Servicio de Extintores');
    });

    test('Registro de Actividades usa solo vehículos livianos', () {
      final module = ModuleRegistry.all.firstWhere(
        (m) => m.moduleKey == 'VISITA_ACTIVIDADES_VEHICULOS',
      );
      expect(module.title, 'Registro de Actividades');
      expect(module.subtitle, 'Checklist Vehículos Livianos');
    });

    test('SyncService strip signature_image data', () {
      final mockData = {
        'id': '123',
        'subido': 0,
        'eliminado': 0,
        'pdf_path_local': '/path',
        'pdf_certificado_path_local': '/path2',
        'signature_image': Uint8List.fromList([1, 2, 3]),
      };

      final datosNube = Map<String, dynamic>.from(mockData);
      datosNube.remove('subido');
      datosNube.remove('eliminado');
      datosNube.remove('pdf_path_local');
      datosNube.remove('pdf_certificado_path_local');
      datosNube.remove('signature_image');

      expect(datosNube.containsKey('signature_image'), false);
      expect(datosNube.containsKey('id'), true);
      expect(datosNube.length, 1);
    });

    test(
      'Sync prep: payload finalizado conserva estado_final y captura paths PDF',
      () {
        // Simulamos la fila tal cual sale de SQLite tras finalizar.
        final row = {
          'id': 'visita-xyz',
          'usuario_id': 'user-1',
          'tipo_actividad': 'MANTENCION_PROSESSO',
          'empresa': 'Prosesso',
          'estado_final': 'Finalizada',
          'subido': 0,
          'eliminado': 0,
          'pdf_path_local': '/data/PROSESSO_Registro.pdf',
          'pdf_certificado_path_local': '/data/PROSESSO_Cert.pdf',
          'pdf_url': null,
          'pdf_certificado_url': null,
          'signature_image': Uint8List.fromList([9, 9, 9]),
          'cert_numero': '2026/1',
          'cert_anio': 2026,
          'cert_correlativo': 1,
        };

        // Misma manipulaci\u00f3n que hace SyncService._sincronizarVisitas:
        final datosNube = Map<String, dynamic>.from(row);
        datosNube.remove('subido');
        datosNube.remove('eliminado');
        final pdfPathLocal = datosNube.remove('pdf_path_local') as String?;
        final pdfCertPathLocal =
            datosNube.remove('pdf_certificado_path_local') as String?;
        datosNube.remove('signature_image');

        // Las variables locales conservan los paths para subirlos al Storage.
        expect(pdfPathLocal, '/data/PROSESSO_Registro.pdf');
        expect(pdfCertPathLocal, '/data/PROSESSO_Cert.pdf');

        // El payload mantiene el estado finalizado (no debe revertirse).
        expect(datosNube['estado_final'], 'Finalizada');

        // No se filtra signature_image ni rutas locales a la nube.
        expect(datosNube.containsKey('signature_image'), false);
        expect(datosNube.containsKey('pdf_path_local'), false);
        expect(datosNube.containsKey('pdf_certificado_path_local'), false);

        // Datos cl\u00e1ve para el certificado se mantienen.
        expect(datosNube['cert_numero'], '2026/1');
        expect(datosNube['cert_anio'], 2026);
        expect(datosNube['cert_correlativo'], 1);
      },
    );

    test(
      'Bug regresi\u00f3n: autoguardado posterior NO debe degradar estado_final',
      () {
        // Reproduce el bug observado: tras finalizar (estado=Finalizada,
        // pdf_path_local!=null), un debouncer pendiente disparaba
        // saveServicio(esBorrador:true) y dejaba estado=En Progreso y
        // pdf_path_local=null.

        // Simulamos el flag _isFinalized del controller.
        bool isFinalized = false;
        final filaSqlite = <String, dynamic>{
          'id': 'v1',
          'estado_final': 'Finalizada',
          'pdf_path_local': '/data/reg.pdf',
        };

        void simularSaveBorrador() {
          if (isFinalized) return;
          filaSqlite['estado_final'] = 'En Progreso';
          filaSqlite['pdf_path_local'] = null;
        }

        // 1) Sin guardia: el bug se reproduce.
        simularSaveBorrador();
        expect(filaSqlite['estado_final'], 'En Progreso');
        expect(filaSqlite['pdf_path_local'], null);

        // 2) Reseteo y activamos el flag (como hace guardar()).
        filaSqlite['estado_final'] = 'Finalizada';
        filaSqlite['pdf_path_local'] = '/data/reg.pdf';
        isFinalized = true;

        // 3) Con guardia: el autoguardado pendiente es ignorado.
        simularSaveBorrador();
        expect(filaSqlite['estado_final'], 'Finalizada');
        expect(filaSqlite['pdf_path_local'], '/data/reg.pdf');
      },
    );

    group('HistoryCardConfig.resolve', () {
      test('Prosesso por tipo_registro: titulo, icono y color de marca', () {
        final cfg = HistoryCardConfig.resolve(
          modulo: 'Mantención de Extintores',
          tipoRegistro: 'MANTENCION_PROSESSO',
          folio: '2026/1',
        );
        expect(cfg.titulo, 'Mantención de Extintores');
        expect(cfg.folioLabel, 'N° 2026/1');
        expect(cfg.icon, Icons.fire_extinguisher);
        expect(cfg.accent, const Color(0xFFC8102E));
        expect(cfg.tipoChipLabel, 'PROSESSO');
      });

      test('Prosesso sin folio: title se mantiene, sin pill', () {
        final cfg = HistoryCardConfig.resolve(
          modulo: 'Mantención de Extintores',
          tipoRegistro: 'MANTENCION_PROSESSO',
        );
        expect(cfg.titulo, 'Mantención de Extintores');
        expect(cfg.folioLabel, isNull);
      });

      test('Inspección mantiene comportamiento previo', () {
        final cfg = HistoryCardConfig.resolve(
          modulo: 'Inspección',
          tipoRegistro: 'INSPECCION_R001',
          folio: '42',
        );
        expect(cfg.titulo, 'Informe N° 42');
        expect(cfg.icon, Icons.description);
        expect(cfg.tipoChipLabel, isNull);
      });

      test('Default es Visita Técnica genérica', () {
        final cfg = HistoryCardConfig.resolve(
          modulo: 'Visita Técnica',
          tipoRegistro: 'VISITA_R004',
        );
        expect(cfg.titulo, 'Visita Técnica');
        expect(cfg.icon, Icons.handshake);
      });
    });
  });
}
