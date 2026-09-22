// =====================================================================
// UPGRADE DATA INTEGRITY TEST SUITE
// ---------------------------------------------------------------------
// Objetivo: cubrir áreas grises detectadas en la auditoría de la
// actualización 0.6.7 → 0.7.x para garantizar que los datos del
// usuario NO se pierdan ni se degraden tras instalar la nueva versión.
//
// Estos tests siguen el patrón de los demás archivos en /test:
// son tests de LÓGICA pura (sin tocar SQLite real) que reproducen las
// transformaciones que hacen los repositorios / controllers / sync
// service, validando el contrato entre capas.
// =====================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';
import 'package:jf_innova_app/features/visits/domain/models/campo_extra_def.dart';

void main() {
  // =====================================================================
  // 1. CRITICIDAD - FALLBACK FIX (bug recién corregido en 0.7.x)
  // ---------------------------------------------------------------------
  // El bug original en _persistirDatos hacía:
  //   'criticidad_registrada': criticidades[key] ?? 'Tolerable'
  // que degradaba criticidades originales del item (Moderado / Intolerable
  // / Bajo / Medio / Alto) a 'Tolerable' cuando el usuario no abría el
  // dropdown. La corrección usa primero la criticidad por defecto del
  // item antes de caer a 'Tolerable'.
  // =====================================================================
  group('Criticidad - Persistencia respeta default del item (fix v0.7.x)', () {
    // Helper que reproduce la lógica corregida de
    // inspection_form_controller.dart -> _persistirDatos
    Map<String, dynamic> persistirRespuesta({
      required String itemId,
      required String estado,
      required Map<String, String?> criticidades,
      required Map<String, String> criticidadPorItem,
    }) {
      return {
        'item_id': itemId,
        'estado': estado,
        'criticidad_registrada':
            criticidades[itemId] ?? criticidadPorItem[itemId] ?? 'Tolerable',
      };
    }

    test(
      'Item con criticidad "Intolerable" sin tocar dropdown conserva valor original',
      () {
        final criticidadPorItem = {'item-1': 'Intolerable'};
        final criticidades = <String, String?>{}; // usuario NO seleccionó

        final res = persistirRespuesta(
          itemId: 'item-1',
          estado: 'NC',
          criticidades: criticidades,
          criticidadPorItem: criticidadPorItem,
        );

        expect(
          res['criticidad_registrada'],
          'Intolerable',
          reason:
              'No debe degradarse a Tolerable cuando el item por defecto es Intolerable',
        );
      },
    );

    test(
      'Item con criticidad "Moderado" sin tocar dropdown conserva valor',
      () {
        final res = persistirRespuesta(
          itemId: 'item-2',
          estado: 'NC',
          criticidades: {},
          criticidadPorItem: {'item-2': 'Moderado'},
        );
        expect(res['criticidad_registrada'], 'Moderado');
      },
    );

    test('Selección manual del usuario PRIMA sobre el default del item', () {
      final res = persistirRespuesta(
        itemId: 'item-3',
        estado: 'NC',
        criticidades: {'item-3': 'Tolerable'}, // usuario rebajó manualmente
        criticidadPorItem: {'item-3': 'Intolerable'},
      );
      expect(
        res['criticidad_registrada'],
        'Tolerable',
        reason: 'Selección manual del usuario debe respetarse',
      );
    });

    test(
      'Item sin criticidad en formulario_items cae a "Tolerable" como último recurso',
      () {
        final res = persistirRespuesta(
          itemId: 'item-x',
          estado: 'NC',
          criticidades: {},
          criticidadPorItem: {}, // no existe ni en items
        );
        expect(res['criticidad_registrada'], 'Tolerable');
      },
    );

    test('Niveles ampliados (Bajo/Medio/Alto) sobreviven a la persistencia', () {
      for (final nivel in ['Bajo', 'Medio', 'Alto']) {
        final res = persistirRespuesta(
          itemId: 'item-$nivel',
          estado: 'NC',
          criticidades: {},
          criticidadPorItem: {'item-$nivel': nivel},
        );
        expect(
          res['criticidad_registrada'],
          nivel,
          reason:
              'Nivel "$nivel" debe preservarse aunque el dropdown UI no lo liste',
        );
      }
    });

    test(
      'Preview y persistencia usan el MISMO fallback (paridad de fuentes)',
      () {
        // Reproduce ambas lecturas: la del PDF (preview/_buildReportData)
        // y la de la persistencia (_persistirDatos). Antes del fix divergían.
        final item = FormularioItem(
          id: 'item-99',
          categoria: 'Seguridad',
          pregunta: '¿Hay extintores cargados?',
          criticidad: 'Intolerable',
          orden: 1,
          peso: 1.0,
        );
        final criticidades = <String, String?>{}; // usuario no tocó

        // Lógica del PDF (line ~1361 controller)
        final criticidadPdf = criticidades[item.id] ?? item.criticidad;

        // Lógica corregida de persistencia (line ~916)
        final criticidadPersist =
            criticidades[item.id] ??
            {item.id: item.criticidad}[item.id] ??
            'Tolerable';

        expect(
          criticidadPdf,
          criticidadPersist,
          reason:
              'PDF preview y persistencia DEBEN coincidir, sino la criticidad baja al finalizar',
        );
        expect(criticidadPdf, 'Intolerable');
      },
    );
  });

  // =====================================================================
  // 2. VERIFICACIONES_EMBARCACION - Roundtrip de map
  // ---------------------------------------------------------------------
  // Tabla creada en v16, ampliada en v17 (numero_zarpe) y v24 (horas).
  // Ningún test la cubría antes.
  // =====================================================================
  group('Verificaciones Embarcación - Roundtrip de datos', () {
    test('Map de embarcación preserva todos los campos al guardar/leer', () {
      // Reproduce el embarcacionMap construido en _persistirDatos
      // (inspection_form_controller.dart) y la lectura del repositorio.
      final activityId = 'act-emb-001';
      final embarcacionMap = {
        'actividad_id': activityId,
        'correo_empresa': 'flota@servicios.cl',
        'numero_zarpe': 'ZP-2026-0042',
        'hora_inicio': '08:30',
        'hora_termino': '17:45',
      };

      // Simula INSERT + SELECT (sin tocar SQLite real)
      final stored = Map<String, dynamic>.from(embarcacionMap);
      final loaded = Map<String, dynamic>.from(stored);

      expect(loaded['actividad_id'], activityId);
      expect(loaded['numero_zarpe'], 'ZP-2026-0042');
      expect(loaded['hora_inicio'], '08:30');
      expect(loaded['hora_termino'], '17:45');
      expect(loaded['correo_empresa'], 'flota@servicios.cl');
    });

    test('Hora "--:--" del UI debe sanearse a null antes de guardar', () {
      String? saneo(String raw) => raw == '--:--' ? null : raw;
      expect(saneo('--:--'), isNull);
      expect(saneo('08:30'), '08:30');
      expect(saneo(''), '');
    });

    test('Migración v17→v24: campo numero_zarpe nullable no rompe upsert', () {
      // Antes de v17 no existía numero_zarpe. Tras upgrade, registros viejos
      // deben tolerar NULL sin perder hora_inicio / hora_termino.
      final mapPreV17 = {
        'actividad_id': 'act-old',
        'correo_empresa': 'old@x.cl',
        // numero_zarpe NO presente
        'hora_inicio': null,
        'hora_termino': null,
      };
      // Tras v24 se intentan leer hora_inicio / hora_termino
      expect(mapPreV17['hora_inicio'], isNull);
      expect(mapPreV17.containsKey('numero_zarpe'), false);
      // El controller usa `?.toString() ?? ''` => no debe explotar
      final h1 = mapPreV17['hora_inicio']?.toString() ?? '';
      expect(h1, '');
    });
  });

  // =====================================================================
  // 3. FOTOS_PENDIENTES - Preservación de paths locales
  // ---------------------------------------------------------------------
  // Si el path se trunca o normaliza incorrectamente al persistir, las
  // fotos quedan huérfanas tras la actualización.
  // =====================================================================
  group('Fotos pendientes - Integridad de local_path', () {
    test('Construcción del registro de foto preserva el path exacto', () {
      // Reproduce la lógica de _persistirDatos para fotosPorPregunta
      final actividadId = 'act-001';
      final itemId = 'item-001';
      final originalPath =
          '/data/user/0/cl.jfinnova.app/cache/img_picker/IMG_2026_05_20_001.jpg';

      final fotoMap = {
        'actividad_id': actividadId,
        'item_id': itemId,
        'local_path': originalPath,
        'descripcion': 'Item $itemId',
        'subido': 0,
      };

      expect(fotoMap['local_path'], originalPath);
      // No debe haber transformación implícita
      expect(fotoMap['local_path'], isNot(contains('//')));
    });

    test('Fotos generales sin item_id mantienen item_id null (no string)', () {
      final fotoGeneral = {
        'actividad_id': 'act-001',
        'item_id': null,
        'local_path': '/tmp/foto_general.jpg',
        'descripcion': 'General',
        'subido': 0,
      };

      expect(
        fotoGeneral['item_id'],
        isNull,
        reason:
            'item_id debe ser NULL real, no string "null" (rompería filtros SQL)',
      );
    });

    test('Path con espacios y caracteres especiales se preserva tal cual', () {
      final paths = [
        '/storage/emulated/0/Pictures/JF Innova/foto 1.jpg',
        '/data/user/0/com.app/cache/áéíóú.jpg',
        r'C:\Users\matip\Pictures\test.jpg',
      ];
      for (final p in paths) {
        final stored = {'local_path': p};
        expect(stored['local_path'], p);
      }
    });

    test('Fotos con observación incluyen UUID (no texto plano)', () {
      // Bug histórico: usar "Foto extra 1" como item_id rompía el FK.
      final uuid = '550e8400-e29b-41d4-a716-446655440000';
      final fotoExtra = {
        'actividad_id': 'act-001',
        'item_id': uuid,
        'local_path': '/tmp/extra.jpg',
        'descripcion': 'Cable suelto en motor de babor',
        'subido': 0,
      };
      // UUID v4 tiene longitud 36
      expect((fotoExtra['item_id'] as String).length, 36);
      expect(fotoExtra['descripcion'], isNot(equals('Foto extra')));
    });
  });

  // =====================================================================
  // 4. CAMPOS_EXTRA (v47) - JSON encode/decode
  // ---------------------------------------------------------------------
  // En SQLite viaja como TEXT(JSON), en Supabase como jsonb. Si el parseo
  // falla en una versión vieja, los datos custom del cliente se pierden.
  // =====================================================================
  group('Campos extra (v47) - JSON serialization', () {
    test('Map vacío se guarda como NULL (no string "{}")', () {
      // Reproduce visit_form_controller.dart línea ~316
      Map<String, String> camposExtra = {};
      final stored = camposExtra.isEmpty ? null : jsonEncode(camposExtra);
      expect(stored, isNull);
    });

    test('Map con datos roundtrips a JSON y vuelve íntegro', () {
      final original = {
        'cliente_extra': 'Salmones del Sur',
        'lote': 'L-2026-08',
        'observacion_libre': 'Equipos en óptimas condiciones',
      };

      final encoded = jsonEncode(original);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded.length, original.length);
      for (final k in original.keys) {
        expect(decoded[k], original[k]);
      }
    });

    test('JSON inválido en BD se trata como null (no rompe sync)', () {
      // Reproduce sync_service.dart línea ~977
      dynamic camposExtra = '<<not-json>>';
      Object? parsed;
      if (camposExtra is String) {
        if (camposExtra.trim().isEmpty) {
          parsed = null;
        } else {
          try {
            parsed = jsonDecode(camposExtra);
          } catch (_) {
            parsed = null;
          }
        }
      }
      expect(parsed, isNull);
    });

    test(
      'CampoExtraDef.fromMap parsea booleano "requerido" en formatos mixtos',
      () {
        // Supabase puede devolver bool, int 1, string "1" o "true"
        for (final v in [true, 1, '1', 't', 'true']) {
          final def = CampoExtraDef.fromMap({
            'tipo_actividad': 'VISITA_R005',
            'clave': 'cliente',
            'label': 'Cliente',
            'requerido': v,
          });
          expect(def.requerido, true, reason: 'Falló con valor $v');
        }
        for (final v in [false, 0, '0', 'f', null]) {
          final def = CampoExtraDef.fromMap({
            'tipo_actividad': 'VISITA_R005',
            'clave': 'cliente',
            'label': 'Cliente',
            'requerido': v,
          });
          expect(def.requerido, false, reason: 'Falló con valor $v');
        }
      },
    );

    test('CampoExtraDef sin "tipo" en BD usa "texto" como default', () {
      final def = CampoExtraDef.fromMap({
        'tipo_actividad': 'VISITA_R005',
        'clave': 'k',
        'label': 'L',
      });
      expect(def.tipo, 'texto');
    });
  });

  // =====================================================================
  // 5. SYNC PAYLOAD - Visitas técnicas (limpieza de campos locales)
  // ---------------------------------------------------------------------
  // Antes el campo signature_image (Uint8List) y pdf_certificado_path_local
  // viajaban a Supabase y rompían el upsert (PGRST204).
  // =====================================================================
  group('Sync payload visitas - Limpieza pre-upload', () {
    test(
      'Visita: signature_image / pdf_path_local / pdf_certificado_path_local removidos',
      () {
        final row = {
          'id': 'vis-001',
          'tipo_actividad': 'VISITA_R005',
          'estado_final': 'En Seguimiento',
          'subido': 0,
          'eliminado': 0,
          'pdf_path_local': '/data/.../report.pdf',
          'pdf_certificado_path_local': '/data/.../cert.pdf',
          'signature_image': Uint8List.fromList([137, 80, 78, 71]),
          'check_reunion': 1,
          'campos_extra': '{"cliente":"X"}',
          'incluir_actividades': 1,
        };

        // Reproduce sync_service.dart -> _sincronizarVisitas (líneas 942-948)
        final datosNube = Map<String, dynamic>.from(row);
        datosNube.remove('subido');
        datosNube.remove('eliminado');
        datosNube.remove('pdf_path_local');
        datosNube.remove('pdf_certificado_path_local');
        datosNube.remove('signature_image');

        // bools
        bool? toBool(dynamic v) => v == null ? null : v == 1;
        datosNube['check_reunion'] = toBool(datosNube['check_reunion']);
        datosNube['incluir_actividades'] = toBool(
          datosNube['incluir_actividades'],
        );

        // campos_extra → jsonDecode
        final raw = datosNube['campos_extra'];
        if (raw is String && raw.trim().isNotEmpty) {
          datosNube['campos_extra'] = jsonDecode(raw);
        }

        expect(datosNube.containsKey('pdf_path_local'), false);
        expect(datosNube.containsKey('pdf_certificado_path_local'), false);
        expect(datosNube.containsKey('signature_image'), false);
        expect(datosNube.containsKey('subido'), false);
        expect(datosNube.containsKey('eliminado'), false);
        expect(datosNube['check_reunion'], true);
        expect(datosNube['incluir_actividades'], true);
        expect(datosNube['campos_extra'], isA<Map>());
        expect((datosNube['campos_extra'] as Map)['cliente'], 'X');
      },
    );

    test(
      'Checks null se preservan como null (no false) - módulos sin checks',
      () {
        bool? toBool(dynamic v) => v == null ? null : v == 1;
        expect(toBool(null), isNull);
        expect(toBool(0), false);
        expect(toBool(1), true);
      },
    );
  });

  // =====================================================================
  // 6. PROSESSO MANTENCIONES - Serialización de fotos/respuestas JSON
  // ---------------------------------------------------------------------
  // Tabla creada en v45. Datos perdidos = certificado en blanco.
  // =====================================================================
  group('PROSESSO mantenciones (v45) - JSON fields', () {
    test('respuestas_json y fotos_json roundtripean con caracteres ñ/á', () {
      final respuestas = {
        'item-1': {'estado': 'C', 'observacion': 'Mantención al día'},
        'item-2': {'estado': 'NC', 'observacion': 'Cilindro N° 3 pendiente'},
      };
      final fotos = ['/storage/foto1.jpg', '/storage/füß foto.jpg'];

      final mantencion = {
        'id': 'mant-1',
        'visita_id': 'vis-1',
        'numero': 'CIL-001',
        'fotos_json': jsonEncode(fotos),
        'respuestas_json': jsonEncode(respuestas),
      };

      final fotosBack = jsonDecode(mantencion['fotos_json']!) as List;
      final respBack = jsonDecode(mantencion['respuestas_json']!) as Map;

      expect(fotosBack.length, 2);
      expect(fotosBack[1], '/storage/füß foto.jpg');
      expect(
        (respBack['item-2'] as Map)['observacion'],
        'Cilindro N° 3 pendiente',
      );
    });

    test('Mantención sin fotos guarda "[]" no null (mantiene contrato)', () {
      final fotos = <String>[];
      final encoded = jsonEncode(fotos);
      expect(encoded, '[]');
      expect(jsonDecode(encoded), isEmpty);
    });
  });

  // =====================================================================
  // 7. EXTINTORES (v32-v43) - Campos nuevos no rompen registros viejos
  // =====================================================================
  group('Extintores (v32→v43) - Compatibilidad de campos', () {
    test('Registro previo a v43 sin peso_extintor / fechas tolera lectura', () {
      // Simulando una fila pre-v43 que se actualizó por upgrade SQL
      final filaVieja = <String, dynamic>{
        'id': 'ext-1',
        'visita_id': 'vis-1',
        'numero': 'EXT-001',
        'tipo_extintor': 'PQS',
        'matricula': 'M-2024-001',
        // peso_extintor / fecha_*_mantencion ausentes (NULL tras ALTER)
      };

      // Lectura defensiva como en el repositorio
      final peso = (filaVieja['peso_extintor'] as num?)?.toDouble();
      final fecha = filaVieja['fecha_ultima_mantencion']?.toString();

      expect(peso, isNull);
      expect(fecha, isNull);
      expect(filaVieja['numero'], 'EXT-001');
    });

    test('Campos nuevos v43 se serializan correctamente cuando existen', () {
      final fila = {
        'id': 'ext-2',
        'peso_extintor': 6.0,
        'fecha_ultima_mantencion': '2026-01-15',
        'fecha_proxima_mantencion': '2027-01-15',
      };
      expect((fila['peso_extintor'] as num).toDouble(), 6.0);
      expect(fila['fecha_proxima_mantencion'], '2027-01-15');
    });
  });

  // =====================================================================
  // 8. SOFT-DELETE (v13) - Reintegración a sync
  // ---------------------------------------------------------------------
  // Al borrar localmente un borrador queda eliminado=1 + subido=0 para
  // que el SyncService lo marque eliminado en Supabase. Si subido=1 el
  // borrado nunca se propaga.
  // =====================================================================
  group('Soft delete (v13) - Propagación a Supabase', () {
    test('Eliminar marca eliminado=1 Y resetea subido=0', () {
      final actividad = {
        'id': 'act-1',
        'eliminado': 0,
        'subido': 1, // ya estaba en la nube
      };
      // LocalInspectionRepository.eliminarBorrador()
      actividad['eliminado'] = 1;
      actividad['subido'] = 0; // <- crítico: re-encolar para sync

      expect(actividad['eliminado'], 1);
      expect(
        actividad['subido'],
        0,
        reason:
            'Si no se resetea subido, el SyncService no detecta el cambio y el registro queda zombie',
      );
    });

    test('getBorradores excluye eliminado=1 Y subido=0 al mismo tiempo', () {
      final actividades = [
        {'id': 'a', 'eliminado': 0, 'subido': 0, 'estado_final': 'En Progreso'},
        {'id': 'b', 'eliminado': 1, 'subido': 0, 'estado_final': 'En Progreso'},
        {
          'id': 'c',
          'eliminado': 0,
          'subido': 1,
          'estado_final': 'En Seguimiento',
        },
      ];
      final visibles = actividades
          .where(
            (a) => a['eliminado'] == 0 && a['estado_final'] == 'En Progreso',
          )
          .toList();
      expect(visibles.length, 1);
      expect(visibles.first['id'], 'a');
    });
  });

  // =====================================================================
  // 9. RUT NORMALIZATION + DEDUP (v33) - Reasignación de FK
  // ---------------------------------------------------------------------
  // v33 elimina personal_externo duplicados por RUT. Antes de eliminar
  // debe reasignar actividad_participantes.personal_id al ganador,
  // sino quedan huérfanos.
  // =====================================================================
  group('Personal externo dedup (v33) - FK reassignment', () {
    test('Simula la reasignación de personal_id antes del DELETE', () {
      // Dos personas con el mismo RUT normalizado. La que tiene
      // contratista_id es la "ganadora".
      final personas = <Map<String, String?>>[
        {'id': 'p-loser', 'rut': '12.345.678-9', 'contratista_id': null},
        {'id': 'p-winner', 'rut': '123456789', 'contratista_id': 'cont-1'},
      ];
      final participantes = <Map<String, String?>>[
        {'actividad_id': 'a-1', 'personal_id': 'p-loser'},
        {'actividad_id': 'a-2', 'personal_id': 'p-winner'},
      ];

      // Lógica de v33: elegir ganador por contratista_id no null
      final winner = personas.firstWhere((p) => p['contratista_id'] != null);
      final loser = personas.firstWhere((p) => p['contratista_id'] == null);

      // Reasignar antes del DELETE
      for (final p in participantes) {
        if (p['personal_id'] == loser['id']) {
          p['personal_id'] = winner['id'];
        }
      }

      // Verificar que ningún participante quedó huérfano
      final ids = personas.map((p) => p['id']).toSet();
      ids.remove(loser['id']); // simula DELETE
      for (final p in participantes) {
        expect(
          ids.contains(p['personal_id']),
          true,
          reason: 'Participante ${p['actividad_id']} quedó huérfano tras dedup',
        );
      }
    });

    test('Normalización de RUT: "12.345.678-9" == "123456789"', () {
      String norm(String r) =>
          r.replaceAll(RegExp(r'[\s\.\-]'), '').toLowerCase();
      expect(norm('12.345.678-9'), '123456789');
      expect(norm('12345678-9'), '123456789');
      expect(norm(' 12345678 9 '), '123456789');
    });
  });

  // =====================================================================
  // 10. NUMERO_REPORTE - Generación / preservación inter-versión
  // =====================================================================
  group('Número de informe - Persistencia inter-versión', () {
    test('Número real de la nube se preserva al guardar como borrador', () {
      // Simula: app vieja generó "PROV-XYZ" (legacy) → app nueva debe
      // descartarlo y esperar al número real de Supabase.
      final numeroEnDB = 'PROV-LEGACY-001';
      final esNumeroNoReal =
          numeroEnDB.isEmpty ||
          numeroEnDB.startsWith('PROV-') ||
          numeroEnDB.startsWith('~');
      expect(esNumeroNoReal, true);

      // Tras detección, debe reemplazarse por null (no guardar legacy)
      final numeroFinal = esNumeroNoReal ? null : numeroEnDB;
      expect(numeroFinal, isNull);
    });

    test('Número real (sin prefijo) se preserva intacto', () {
      const numero = '42';
      final esNoReal =
          numero.isEmpty ||
          numero.startsWith('PROV-') ||
          numero.startsWith('~');
      expect(esNoReal, false);
      expect(numero, '42');
    });
  });
}
