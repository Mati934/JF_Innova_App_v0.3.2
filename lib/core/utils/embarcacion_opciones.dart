// Lista de embarcaciones para elegir en Nueva inspección y AST.
// Antes se mostraban solo las del servicio elegido; como las embarcaciones rotan de servicio, la que no aparecía se
// volvía a crear y quedaba duplicada (2026-11-17). Ahora salen todas: primero las del servicio elegido y después las
// demás con su servicio actual. La actividad sigue guardando su propio contratista_id, así que no se pierde nada.

/// Agrega `etiqueta` a cada fila (el texto que se ve y se busca en el selector) y ordena.
/// - Del servicio elegido: solo el nombre.
/// - De otro servicio: "nombre · servicio" (los nombres se repiten entre servicios, ej. "SANTA MARIA").
/// Filas de entrada: `id`, `nombre`, `contratista_id`, `contratista_nombre`. `nombre` no se toca (se guarda tal cual).
List<Map<String, dynamic>> opcionesEmbarcacion(
  List<Map<String, dynamic>> filas,
  String? contratistaId,
) {
  String txt(Object? v) => (v ?? '').toString().trim();
  int porNombre(Map<String, dynamic> a, Map<String, dynamic> b) {
    final n = txt(
      a['nombre'],
    ).toLowerCase().compareTo(txt(b['nombre']).toLowerCase());
    return n != 0
        ? n
        : txt(
            a['contratista_nombre'],
          ).toLowerCase().compareTo(txt(b['contratista_nombre']).toLowerCase());
  }

  final propias =
      filas
          .where(
            (f) =>
                contratistaId != null && f['contratista_id'] == contratistaId,
          )
          .toList()
        ..sort(porNombre);
  final otras =
      filas
          .where(
            (f) =>
                contratistaId == null || f['contratista_id'] != contratistaId,
          )
          .toList()
        ..sort(porNombre);

  final usadas = <String>{};
  String unica(String base) {
    var e = base;
    for (var i = 2; usadas.contains(e); i++) {
      e = '$base ($i)';
    }
    usadas.add(e);
    return e;
  }

  return [
    for (final f in propias) {...f, 'etiqueta': unica(txt(f['nombre']))},
    for (final f in otras)
      {
        ...f,
        'etiqueta': unica(
          '${txt(f['nombre'])} · ${txt(f['contratista_nombre']).isEmpty ? 'sin servicio' : txt(f['contratista_nombre'])}',
        ),
      },
  ];
}
