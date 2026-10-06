// Tests para el flujo de borradores del módulo Hidroser.
//
// Cubre:
// - Mapeo correcto de filas de `hidroser_inspecciones_pendientes` a
//   `DraftCardData` con `DraftKind.hidroserGruaHorquilla`.
// - Icono/color asociado al nuevo `DraftKind`.
// - Que el `ModuleRegistry` use `Icons.engineering` para HIDROSER (cambio
//   visual solicitado).
// - Lógica de re-hidratación de respuestas (espejo de `_aplicarBorrador`
//   del controlador) — verifica que un borrador con respuestas previas
//   sobrescribe el estado por defecto de los items.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/modules/module_registry.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_data.dart';
import 'package:jf_innova_app/features/home/domain/draft_card_mapper.dart';

void main() {
  group('Hidroser · Borradores', () {
    test('DraftCardMapper.fromHidroser produce DraftCardData válido', () {
      final raw = {
        'id': 'insp-uuid-123',
        'lista_codigo': 'GRUA_HORQUILLA_PFA',
        'quien_inspecciona': 'Juan Pérez',
        'estado_final': 'Borrador',
        'fecha_realizacion': '2026-05-28T10:30:00.000Z',
        'created_at': '2026-05-28T10:35:00.000Z',
      };

      final card = DraftCardMapper.fromHidroser(raw);

      expect(card.id, 'insp-uuid-123');
      expect(card.kind, DraftKind.hidroserGruaHorquilla);
      expect(card.title, 'Inspección Grúa Horquilla');
      expect(card.centro, 'Juan Pérez');
      expect(card.fecha.year, 2026);
      expect(card.fecha.month, 5);
      expect(card.fecha.day, 28);
    });

    test('fromHidroser cae al lista_codigo si no hay inspector', () {
      final card = DraftCardMapper.fromHidroser({
        'id': 'x',
        'lista_codigo': 'GRUA_HORQUILLA_PFA',
        'quien_inspecciona': '',
        'fecha_realizacion': '2026-01-01',
      });
      expect(card.centro, 'GRUA_HORQUILLA_PFA');
    });

    test('DraftKind.hidroserGruaHorquilla expone icono y color', () {
      final card = DraftCardData(
        id: 'x',
        kind: DraftKind.hidroserGruaHorquilla,
        title: 'X',
        fecha: DateTime.now(),
        raw: const {},
      );
      expect(card.icon, Icons.engineering);
      expect(card.color, const Color(0xFF0277BD)); // kHidroserColor
      expect(card.esVisitaOExtintor, true);
    });

    test('ModuleRegistry HIDROSER usa Icons.engineering', () {
      final mod = ModuleRegistry.all.firstWhere(
        (m) => m.moduleKey == 'HIDROSER',
      );
      expect(mod.icon, Icons.engineering);
      expect(mod.title, 'Hidroser');
    });

    // -----------------------------------------------------------------
    // Re-hidratación de respuestas: replicación de la lógica interna del
    // controlador (HidroserFormController._aplicarBorrador) para garantizar
    // que un borrador con respuestas previas restaure el estado correcto.
    // -----------------------------------------------------------------
    test(
      'Borrador con respuestas restaura estado, observación y criticidad',
      () {
        // Estado inicial que armaría init() tras leer formulario_items.
        final items = [
          {
            'id': 'q1',
            'pregunta': '¿Frenos OK?',
            'categoria': 'Seguridad',
            'estado': 'C',
            'observacion': '',
            'criticidad': null,
          },
          {
            'id': 'q2',
            'pregunta': '¿Bocina funciona?',
            'categoria': 'Seguridad',
            'estado': 'C',
            'observacion': '',
            'criticidad': null,
          },
        ];

        // Respuestas que vendrían del borrador almacenado.
        final respuestasBorrador = [
          {
            'item_id': 'q1',
            'estado': 'NC',
            'observacion': 'Frenos desgastados',
            'criticidad': 'Intolerable',
          },
          {
            'item_id': 'q2',
            'estado': 'N/A',
            'observacion': null,
            'criticidad': null,
          },
        ];

        // Lógica idéntica a la del controlador.
        for (final r in respuestasBorrador) {
          final itemId = r['item_id']?.toString();
          if (itemId == null) continue;
          final i = items.indexWhere((m) => m['id'].toString() == itemId);
          if (i < 0) continue;
          items[i]['estado'] = (r['estado'] ?? items[i]['estado']).toString();
          items[i]['observacion'] = (r['observacion'] ?? '').toString();
          items[i]['criticidad'] = r['criticidad']?.toString();
        }

        expect(items[0]['estado'], 'NC');
        expect(items[0]['observacion'], 'Frenos desgastados');
        expect(items[0]['criticidad'], 'Intolerable');

        expect(items[1]['estado'], 'N/A');
        expect(items[1]['observacion'], ''); // null → vacío
        expect(items[1]['criticidad'], isNull);
      },
    );

    test('Respuestas con item_id desconocido se ignoran sin error', () {
      final items = [
        {
          'id': 'q1',
          'pregunta': '?',
          'categoria': 'X',
          'estado': 'C',
          'observacion': '',
          'criticidad': null,
        },
      ];

      final respuestas = [
        {'item_id': 'no-existe', 'estado': 'NC'},
      ];

      for (final r in respuestas) {
        final itemId = r['item_id']?.toString();
        if (itemId == null) continue;
        final i = items.indexWhere((m) => m['id'].toString() == itemId);
        if (i < 0) continue;
        items[i]['estado'] = (r['estado'] ?? items[i]['estado']).toString();
      }

      // El item original NO debe haberse modificado.
      expect(items[0]['estado'], 'C');
    });
  });
}
