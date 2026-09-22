import 'dart:convert';

/// Definición de un campo extra del encabezado de una lista Hidroser
/// (por ej. conductor, número de grúa, horómetro, etc.).
class HidroserCampoExtraDef {
  final String clave;
  final String label;
  final String tipo; // texto | numero | fecha
  final bool requerido;
  final int orden;

  const HidroserCampoExtraDef({
    required this.clave,
    required this.label,
    required this.tipo,
    required this.requerido,
    required this.orden,
  });

  factory HidroserCampoExtraDef.fromMap(Map<String, dynamic> m) {
    return HidroserCampoExtraDef(
      clave: (m['clave'] ?? '').toString(),
      label: (m['label'] ?? '').toString(),
      tipo: (m['tipo'] ?? 'texto').toString(),
      requerido: m['requerido'] == true || m['requerido'] == 1,
      orden: (m['orden'] is num) ? (m['orden'] as num).toInt() : 0,
    );
  }
}

/// Cabecera (catálogo) de una lista de chequeo del módulo Hidroser.
class HidroserLista {
  final String codigo;
  final String nombre;
  final String? subtitulo;
  final String tipoFormularioItems;
  final String? icono;
  final int orden;
  final bool activo;
  final List<HidroserCampoExtraDef> camposExtra;

  const HidroserLista({
    required this.codigo,
    required this.nombre,
    required this.tipoFormularioItems,
    this.subtitulo,
    this.icono,
    this.orden = 0,
    this.activo = true,
    this.camposExtra = const [],
  });

  factory HidroserLista.fromMap(Map<String, dynamic> m) {
    final rawDefs = m['campos_extra_definicion'];
    List<HidroserCampoExtraDef> defs = const [];
    try {
      final decoded = rawDefs is String ? jsonDecode(rawDefs) : rawDefs;
      if (decoded is List) {
        defs =
            decoded
                .whereType<Map>()
                .map(
                  (e) => HidroserCampoExtraDef.fromMap(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
              ..sort((a, b) => a.orden.compareTo(b.orden));
      }
    } catch (_) {
      defs = const [];
    }

    return HidroserLista(
      codigo: (m['codigo'] ?? '').toString(),
      nombre: (m['nombre'] ?? '').toString(),
      subtitulo: m['subtitulo']?.toString(),
      tipoFormularioItems: (m['tipo_formulario_items'] ?? '').toString(),
      icono: m['icono']?.toString(),
      orden: (m['orden'] is num) ? (m['orden'] as num).toInt() : 0,
      activo: !(m['activo'] == 0 || m['activo'] == false),
      camposExtra: defs,
    );
  }
}
