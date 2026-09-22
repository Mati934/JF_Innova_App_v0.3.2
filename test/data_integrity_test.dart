import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

// Models
import 'package:jf_innova_app/features/visits/domain/models/visita_respuesta.dart';
import 'package:jf_innova_app/features/visits/domain/models/visit_model.dart';
import 'package:jf_innova_app/features/visits/domain/models/pdf/visit_report_data.dart';
import 'package:jf_innova_app/features/inspection/domain/models/participante_model.dart';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';

void main() {
  group('VisitaRespuesta - Integridad de datos', () {
    test('toMap/fromMap roundtrip preserva todos los campos', () {
      final original = VisitaRespuesta(
        id: 'resp-001',
        visitaId: 'visita-abc',
        itemId: 'item-xyz',
        estado: 'NC',
        observacion: 'Cable pelado en sector norte',
        criticidad: 'Intolerable',
        fotoPath: '/data/fotos/foto_001.jpg',
      );

      final map = original.toMap();
      final restored = VisitaRespuesta.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.visitaId, original.visitaId);
      expect(restored.itemId, original.itemId);
      expect(restored.estado, original.estado);
      expect(restored.observacion, original.observacion);
      expect(restored.criticidad, original.criticidad);
      expect(restored.fotoPath, original.fotoPath);
    });

    test('toMap/fromMap con campos opcionales null', () {
      final original = VisitaRespuesta(
        id: 'resp-002',
        visitaId: 'visita-def',
        itemId: 'item-abc',
        estado: 'C',
        observacion: '',
        criticidad: null,
        fotoPath: null,
      );

      final map = original.toMap();
      final restored = VisitaRespuesta.fromMap(map);

      expect(restored.estado, 'C');
      expect(restored.criticidad, isNull);
      expect(restored.fotoPath, isNull);
    });
  });

  group('Checklist JSON - Integridad de datos', () {
    test('jsonEncode/jsonDecode roundtrip preserva todas las respuestas', () {
      final respuestasMap = {
        'item-1': {
          'id': 'r1',
          'visita_id': 'v1',
          'item_id': 'item-1',
          'estado': 'C',
          'observacion': '',
          'criticidad': 'Tolerable',
          'foto_path': null,
          'subido': 0,
        },
        'item-2': {
          'id': 'r2',
          'visita_id': 'v1',
          'item_id': 'item-2',
          'estado': 'NC',
          'observacion': 'Falla en cable principal',
          'criticidad': 'Intolerable',
          'foto_path': '/img/foto1.jpg',
          'subido': 0,
        },
        'item-3': {
          'id': 'r3',
          'visita_id': 'v1',
          'item_id': 'item-3',
          'estado': 'N/A',
          'observacion': 'No aplica en este centro',
          'criticidad': null,
          'foto_path': null,
          'subido': 0,
        },
      };

      // Simular guardado en SQLite (encode a JSON string)
      final jsonString = jsonEncode(respuestasMap);

      // Simular carga desde SQLite (decode de JSON string)
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded.keys.length, 3);

      // Verificar respuesta CUMPLE
      expect(decoded['item-1']['estado'], 'C');
      expect(decoded['item-1']['criticidad'], 'Tolerable');

      // Verificar respuesta NO CUMPLE con foto
      expect(decoded['item-2']['estado'], 'NC');
      expect(decoded['item-2']['observacion'], 'Falla en cable principal');
      expect(decoded['item-2']['criticidad'], 'Intolerable');
      expect(decoded['item-2']['foto_path'], '/img/foto1.jpg');

      // Verificar respuesta N/A
      expect(decoded['item-3']['estado'], 'N/A');
      expect(decoded['item-3']['criticidad'], isNull);
    });

    test('JSON vacío no pierde tipo de checklist', () {
      final checklistRow = {
        'tipo_checklist': 'VISITA_005',
        'respuestas': jsonEncode({}),
      };

      final tipo = checklistRow['tipo_checklist'];
      final respuestas =
          jsonDecode(checklistRow['respuestas']!) as Map<String, dynamic>;

      expect(tipo, 'VISITA_005');
      expect(respuestas, isEmpty);
    });
  });

  group('ParticipanteModel - Integridad cuadrilla', () {
    test('fromMap incluye contratista_id (fix del bug de borrado)', () {
      final map = {
        'personal_id': 'pers-001',
        'nombre_completo': 'Juan Pérez',
        'rut': '12345678-9',
        'matricula': 'MAT-001',
        'contratista_id': 'cont-abc',
        'rol_en_faena': 'Buzo',
        'condiciones_optimas': 1,
      };

      final modelo = ParticipanteModel.fromMap(map);

      expect(modelo.personalId, 'pers-001');
      expect(modelo.nombreCompleto, 'Juan Pérez');
      expect(modelo.rut, '12345678-9');
      expect(modelo.matricula, 'MAT-001');
      expect(
        modelo.contratistaId,
        'cont-abc',
        reason: 'contratista_id debe preservarse en el roundtrip',
      );
      expect(modelo.cargo, 'Buzo');
      expect(modelo.condicionesOptimas, true);
    });

    test('fromMap con contratista_id null no crashea', () {
      final map = {
        'personal_id': 'pers-002',
        'nombre_completo': 'Pedro López',
        'rut': '98765432-1',
        'matricula': '',
        'contratista_id': null,
        'rol_en_faena': 'Supervisor',
        'condiciones_optimas': 0,
      };

      final modelo = ParticipanteModel.fromMap(map);

      expect(modelo.contratistaId, isNull);
      expect(modelo.condicionesOptimas, false);
    });

    test('fromMap sin contratista_id en el mapa usa null', () {
      // Simula el caso ANTES del fix (query sin contratista_id)
      final map = {
        'personal_id': 'pers-003',
        'nombre_completo': 'María García',
        'rut': '11111111-1',
        'matricula': 'MAT-003',
        'rol_en_faena': 'Asistente',
        'condiciones_optimas': 1,
      };

      final modelo = ParticipanteModel.fromMap(map);

      expect(
        modelo.contratistaId,
        isNull,
        reason: 'Sin contratista_id en el mapa, debe ser null (no crashear)',
      );
    });
  });

  group('FormularioItem - Integridad de preguntas', () {
    test('fromJson preserva todos los campos incluyendo info_adicional', () {
      final json = {
        'id': 'fi-001',
        'pregunta': 'Cable en buen estado?',
        'categoria': 'ELECTRICO',
        'criticidad': 'Alto',
        'info_adicional': 'Revisar terminales y conexiones',
        'url_imagen_referencia': 'https://example.com/ref.png',
      };

      final item = FormularioItem.fromJson(json);

      expect(item.id, 'fi-001');
      expect(item.pregunta, 'Cable en buen estado?');
      expect(item.categoria, 'ELECTRICO');
      expect(item.criticidad, 'Alto');
      expect(item.infoAdicional, 'Revisar terminales y conexiones');
      expect(item.urlImagenReferencia, 'https://example.com/ref.png');
    });

    test('fromJson con campos opcionales null usa defaults', () {
      final json = {
        'id': 'fi-002',
        'pregunta': 'Tablero protegido?',
        'categoria': 'SEGURIDAD',
      };

      final item = FormularioItem.fromJson(json);

      expect(
        item.criticidad,
        'Tolerable',
        reason: 'criticidad default debe ser Tolerable (escala inspecciones)',
      );
      expect(item.infoAdicional, isNull);
      expect(item.urlImagenReferencia, isNull);
    });
  });

  group('VisitModel - Backward compatibility', () {
    test('fromMap con datos sin checklist no crashea', () {
      final map = {
        'id': 'visit-001',
        'region': 'X REGION',
        'lugar_visita': 'CENTRO ACUICOLA 1',
        'jefatura_a_cargo': 'Jefe de Área',
        'check_reunion': 1,
        'check_instalacion_senaletica': 0,
        'check_capacitacion': 1,
        'check_visita_sso': 0,
        'check_charla': 0,
        'check_investigacion_incidente': 0,
        'check_inspeccion_sso': 0,
        'check_obs_conductual': 0,
        'check_otro': 0,
      };

      final model = VisitModel.fromMap(map);

      expect(model.activityId, 'visit-001');
      expect(model.region, 'X REGION');
      expect(model.centro, 'CENTRO ACUICOLA 1');
      expect(model.checkReunion, true);
      expect(model.checkCapacitacion, true);
      expect(model.checkSenaletica, false);
    });

    test('fromMap preserva signature_image como Uint8List', () {
      final fakeSignature = Uint8List.fromList([1, 2, 3, 4, 5]);
      final map = {
        'id': 'visit-002',
        'signature_image': fakeSignature,
        'check_reunion': 0,
        'check_instalacion_senaletica': 0,
        'check_capacitacion': 0,
        'check_visita_sso': 0,
        'check_charla': 0,
        'check_investigacion_incidente': 0,
        'check_inspeccion_sso': 0,
        'check_obs_conductual': 0,
        'check_otro': 0,
      };

      final model = VisitModel.fromMap(map);

      expect(model.signatureImage, isNotNull);
    });
  });

  group('VisitChecklistItemDto - Datos del PDF', () {
    test('DTO lleva todos los datos necesarios para el PDF', () {
      final dto = VisitChecklistItemDto(
        categoria: 'ELECTRICO',
        pregunta: 'Tablero protegido?',
        respuesta: 'NC',
        criticidad: 'Moderado',
        observacion: 'Sin tapa de protección',
      );

      expect(dto.categoria, 'ELECTRICO');
      expect(dto.pregunta, 'Tablero protegido?');
      expect(dto.respuesta, 'NC');
      expect(dto.criticidad, 'Moderado');
      expect(dto.observacion, 'Sin tapa de protección');
    });

    test('DTO con campos opcionales null no pierde datos requeridos', () {
      final dto = VisitChecklistItemDto(
        categoria: 'SEGURIDAD',
        pregunta: 'Extintor presente?',
        respuesta: 'C',
      );

      expect(dto.categoria, 'SEGURIDAD');
      expect(dto.respuesta, 'C');
      expect(dto.criticidad, isNull);
      expect(dto.observacion, isNull);
    });
  });
}
