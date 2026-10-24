import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/visits/domain/visit_checklist_labels.dart';

void main() {
  group('visitChecklistLabel', () {
    test('traduce los nuevos codigos de checklist', () {
      expect(
        visitChecklistLabel('VISITA_CHEQUEO_HERRAMIENTAS_MANUALES'),
        'Chequeo de Herramientas Manuales',
      );
      expect(
        visitChecklistLabel('VISITA_CHEQUEO_SOLDADORA_AL_ARCO'),
        'Chequeo de Soldadora al Arco',
      );
      expect(
        visitChecklistLabel('VISITA_CHEQUEO_TALADRO_DESTORNILLADOR'),
        'Chequeo de Taladro Destornillador',
      );
      expect(
        visitChecklistLabel('VISITA_CHEQUEO_ESMERIL_ANGULAR'),
        'Chequeo de Esmeril Angular',
      );
      expect(
        visitChecklistLabel('VISITA_CHEQUEO_EXTENSION_ELECTRICA'),
        'Chequeo de Extensión Eléctrica',
      );

      // Alias cortos conservados para registros creados durante el desarrollo.
      expect(
        visitChecklistLabel('VISITA_R013'),
        'Chequeo de Herramientas Manuales',
      );
      expect(
        visitChecklistLabel('VISITA_R014'),
        'Chequeo de Soldadora al Arco',
      );
      expect(
        visitChecklistLabel('VISITA_R015'),
        'Chequeo de Taladro Destornillador',
      );
      expect(visitChecklistLabel('VISITA_R016'), 'Chequeo de Esmeril Angular');
      expect(
        visitChecklistLabel('VISITA_R017'),
        'Chequeo de Extensión Eléctrica',
      );
    });

    test('mantiene las etiquetas existentes y un fallback legible', () {
      expect(visitChecklistLabel('VISITA_R004'), 'Inspección Extintores');
      expect(visitChecklistLabel('VISITA_R999'), 'VISITA R999');
      expect(visitChecklistLabel(null), '');
    });
  });
}
