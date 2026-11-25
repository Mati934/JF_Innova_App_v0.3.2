import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/utils/embarcacion_opciones.dart';

void main() {
  final filas = <Map<String, dynamic>>[
    {
      'id': '1',
      'nombre': 'SANTA MARIA',
      'contratista_id': 'brisa',
      'contratista_nombre': 'BRISA AUSTRAL LTDA',
    },
    {
      'id': '2',
      'nombre': 'LM SANTA MARIA',
      'contratista_id': 'redmar',
      'contratista_nombre': 'REDMAR CORDILLERA LTDA',
    },
    {
      'id': '3',
      'nombre': 'SANTA MARIA',
      'contratista_id': 'emp',
      'contratista_nombre': 'EMP. SERV. BRISA AUSTRAL',
    },
    {
      'id': '4',
      'nombre': 'ESCARPADA III',
      'contratista_id': 'redmar',
      'contratista_nombre': 'REDMAR CORDILLERA LTDA',
    },
    {
      'id': '5',
      'nombre': 'N/A',
      'contratista_id': null,
      'contratista_nombre': null,
    },
  ];

  test(
    'salen todas: primero las del servicio elegido (solo nombre), después las demás con su servicio',
    () {
      final o = opcionesEmbarcacion(filas, 'redmar');
      expect(o.length, 5);
      expect(o.map((e) => e['etiqueta']).toList(), [
        'ESCARPADA III',
        'LM SANTA MARIA',
        'N/A · sin servicio',
        'SANTA MARIA · BRISA AUSTRAL LTDA',
        'SANTA MARIA · EMP. SERV. BRISA AUSTRAL',
      ]);
    },
  );

  test(
    'sin servicio elegido, todas llevan su servicio y las etiquetas no se repiten',
    () {
      final o = opcionesEmbarcacion(filas, null);
      final etiquetas = o.map((e) => e['etiqueta']).toList();
      expect(etiquetas.toSet().length, etiquetas.length);
      expect(etiquetas.first, 'ESCARPADA III · REDMAR CORDILLERA LTDA');
    },
  );

  test('el nombre real no se toca (es lo que se guarda en el AST)', () {
    final o = opcionesEmbarcacion(filas, 'brisa');
    expect(o.first['nombre'], 'SANTA MARIA');
    expect(o.first['etiqueta'], 'SANTA MARIA');
    expect(o.first['id'], '1');
  });
}
