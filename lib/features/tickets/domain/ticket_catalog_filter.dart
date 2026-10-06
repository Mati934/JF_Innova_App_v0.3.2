/// Extrae los ids distintos y no nulos de una columna de filas crudas
/// (ej: filas de la tabla tickets), listos para usarlos en un `inFilter`.
Set<String> extractDistinctIds(
  List<Map<String, dynamic>> rows,
  String columna,
) {
  return rows
      .map((r) => r[columna])
      .where((v) => v != null)
      .map((v) => v.toString())
      .toSet();
}

/// Filtra un catalogo completo ({id, nombre}) dejando solo las filas cuyo id
/// aparece en [usedIds]. Se usa para que los selectores de filtro de Tickets
/// (area, centro, embarcacion, contratista) muestren solo opciones que
/// realmente tienen al menos un ticket vigente.
List<Map<String, dynamic>> filterCatalogByUsedIds(
  List<Map<String, dynamic>> catalogo,
  Set<String> usedIds,
) {
  return catalogo
      .where((row) => usedIds.contains(row['id']?.toString()))
      .toList();
}
