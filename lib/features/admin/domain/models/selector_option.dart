/// Modelo unificado para los dropdowns del formulario de Datos Maestros.
///
/// Representa una entidad que puede provenir de dos fuentes:
///   - SQLite (registros reales con UUID permanente)
///   - BatchDraftController (borradores en memoria con ID temporal como "temp_empresa_abc123")
///
/// La vista solo trabaja con [SelectorOption]: nunca consulta directamente
/// la BD ni el controlador de borradores.

class SelectorOption {
  /// ID real (UUID de Supabase/SQLite) o temporal (ej. "temp_empresa_abc123").
  final String id;

  /// Nombre legible que se muestra en el dropdown.
  final String nombre;

  /// `true` si el registro es un borrador en memoria (aún no sincronizado).
  /// Permite a la UI mostrar un indicador visual distinto.
  final bool isTemp;

  /// Tipo de entidad, útil para debug y para el filtro en cascada.
  final TipoEntidad tipo;

  const SelectorOption({
    required this.id,
    required this.nombre,
    required this.isTemp,
    required this.tipo,
  });

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  factory SelectorOption.fromDb({
    required String id,
    required String nombre,
    required TipoEntidad tipo,
  }) => SelectorOption(id: id, nombre: nombre, isTemp: false, tipo: tipo);

  factory SelectorOption.fromDraft({
    required String tempId,
    required String nombre,
    required TipoEntidad tipo,
  }) => SelectorOption(id: tempId, nombre: nombre, isTemp: true, tipo: tipo);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Texto que se pasa al [CustomDropdown]. El prefijo "[Borrador]" es
  /// opcional; ajústalo según tu diseño visual.
  String get displayName => isTemp ? '⏳ $nombre' : nombre;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectorOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SelectorOption(id: $id, nombre: $nombre, isTemp: $isTemp, tipo: $tipo)';
}

// ---------------------------------------------------------------------------
// Enum de tipos de entidad manejados en este módulo
// ---------------------------------------------------------------------------

enum TipoEntidad { empresa, area, contratista, embarcacion }
