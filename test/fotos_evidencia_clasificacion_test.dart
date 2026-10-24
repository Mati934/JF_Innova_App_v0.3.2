import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/inspection/domain/models/foto_evidencia_item_id.dart';
import 'package:jf_innova_app/features/inspection/domain/models/mandatory_buceo_photo_slot.dart';
import 'package:jf_innova_app/features/tickets/domain/ticket_reglas.dart';

/// Regresión del bug: las fotos de las VERIFICACIONES CRÍTICAS del estado de
/// la faena (item_id `verif_*`) terminaban clasificadas como "fotos con
/// observación" al recargar el borrador y al armar el PDF diferido, quedando
/// duplicadas en el anexo fotográfico y generando tickets FOTOS_OBSERVACION
/// basura.
void main() {
  const uuidPregunta = '11111111-1111-1111-1111-111111111111';
  const uuidFotoExtra = '22222222-2222-2222-2222-222222222222';
  final idsPreguntas = {uuidPregunta};

  FotoEvidenciaTipo clasificar(String? itemId) =>
      FotoEvidenciaItemId.clasificar(itemId, idsPreguntas: idsPreguntas);

  group('FotoEvidenciaItemId.clasificar', () {
    test('BUG: fotos de verificaciones NO son fotos con observación', () {
      for (final clave in const [
        'autorizacion',
        'induccion',
        'permiso',
        'plan',
        'examenes',
      ]) {
        final itemId = FotoEvidenciaItemId.paraVerificacion(clave);
        expect(
          clasificar(itemId),
          FotoEvidenciaTipo.verificacion,
          reason: '$itemId no debe caer en observacionExtra',
        );
      }
    });

    test('acepta el sufijo con timestamp que agrega saveFoto', () {
      expect(
        clasificar('verif_examenes_1712345678901'),
        FotoEvidenciaTipo.verificacion,
      );
      expect(
        FotoEvidenciaItemId.claveVerificacion('verif_examenes_1712345678901'),
        'examenes',
      );
    });

    test('foto obligatoria de buceo se reconoce por su prefijo', () {
      final itemId = mandatoryPhotoItemId('compresor_general');
      expect(clasificar(itemId), FotoEvidenciaTipo.obligatoria);
      expect(FotoEvidenciaItemId.claveObligatoria(itemId), 'compresor_general');
    });

    test('item_id nulo es galería general', () {
      expect(clasificar(null), FotoEvidenciaTipo.general);
    });

    test('visita_general es galería general, no observación extra', () {
      expect(clasificar('visita_general'), FotoEvidenciaTipo.general);
    });

    test('item_id de una pregunta del formulario es foto de pregunta', () {
      expect(clasificar(uuidPregunta), FotoEvidenciaTipo.pregunta);
    });

    test('UUID libre (agregarFotosConObservacion) sí es observación extra', () {
      expect(clasificar(uuidFotoExtra), FotoEvidenciaTipo.observacionExtra);
    });

    test('claveVerificacion devuelve null si no es foto de verificación', () {
      expect(FotoEvidenciaItemId.claveVerificacion(null), isNull);
      expect(FotoEvidenciaItemId.claveVerificacion(uuidFotoExtra), isNull);
    });
  });

  group('TicketReglas.esObservacionFotoReal con fotos de evidencia', () {
    test('BUG: la descripción de una verificación no genera ticket', () {
      for (final clave in const [
        'autorizacion',
        'induccion',
        'permiso',
        'plan',
        'examenes',
      ]) {
        expect(
          TicketReglas.esObservacionFotoReal(
            FotoEvidenciaItemId.descripcionVerificacion(clave),
          ),
          isFalse,
          reason: 'La foto de verificación "$clave" no es una observación',
        );
      }
      // Datos ya subidos sin tilde.
      expect(
        TicketReglas.esObservacionFotoReal('Verificacion: permiso'),
        isFalse,
      );
    });

    test('los títulos de las fotos obligatorias tampoco generan ticket', () {
      for (final slot in mandatoryBuceoPhotoSlots) {
        expect(
          TicketReglas.esObservacionFotoReal(slot.title),
          isFalse,
          reason: 'La foto obligatoria "${slot.title}" no es una observación',
        );
      }
    });

    test(
      'BUG: foto de pregunta huérfana ("Item <uuid>") no es observación',
      () {
        // 751 filas así en producción (31-08-2026): son fotos del checklist que
        // se subieron sin poder enlazar su inspeccion_respuesta_id.
        expect(
          TicketReglas.esObservacionFotoReal(
            'Item 0ed0e0d1-2ff0-48dd-91d7-2a3a48b627e2',
          ),
          isFalse,
        );
        expect(
          TicketReglas.esObservacionFotoReal(
            '  item 6828BCBF-36C3-4223-963A-880D3C36ACDD  ',
          ),
          isFalse,
        );
      },
    );

    test(
      'BUG: foto anexa sin texto ("Fotografía anexa") no es observación',
      () {
        expect(TicketReglas.esObservacionFotoReal('Fotografía anexa'), isFalse);
        expect(TicketReglas.esObservacionFotoReal('fotografia anexa'), isFalse);
      },
    );

    test('placeholder del anexo de visitas no es observación', () {
      expect(
        TicketReglas.esObservacionFotoReal(
          'Anexo fotográfico de Visita Técnica',
        ),
        isFalse,
      );
    });

    test('una observación real del inspector sigue generando ticket', () {
      expect(
        TicketReglas.esObservacionFotoReal('Manguera con corte visible'),
        isTrue,
      );
      expect(
        TicketReglas.esObservacionFotoReal('Falta verificación de matrícula'),
        isTrue,
      );
      // Casos reales de producción que SÍ deben seguir generando ticket.
      expect(
        TicketReglas.esObservacionFotoReal(
          'Se evidencian niples de acero al carbono (obs pdte 07 08 2026)',
        ),
        isTrue,
      );
      // Empieza con "Item" pero no es el placeholder <uuid>.
      expect(
        TicketReglas.esObservacionFotoReal('Item de la bomba está suelto'),
        isTrue,
      );
    });
  });
}
