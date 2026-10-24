/// Clasificación de las fotos guardadas en `fotos_pendientes` /
/// `registro_fotografico` según su `item_id`.
///
/// Regla única y compartida por el formulario, el PDF diferido y el sync para
/// que no se contradigan: antes cada uno reimplementaba el `else` "tiene id y
/// no es pregunta => es foto con observación", y por eso las fotos de las
/// verificaciones críticas (`verif_*`) terminaban en el anexo de fotos con
/// observación.
enum FotoEvidenciaTipo {
  general,
  pregunta,
  obligatoria,
  verificacion,
  observacionExtra,
}

class FotoEvidenciaItemId {
  const FotoEvidenciaItemId._();

  static const String prefijoVerificacion = 'verif_';
  static const String prefijoObligatoria = 'mandatory::';

  /// item_id que usan las fotos generales del módulo de visitas.
  static const String visitaGeneral = 'visita_general';

  static String paraVerificacion(String clave) => '$prefijoVerificacion$clave';

  static String descripcionVerificacion(String clave) => 'Verificación: $clave';

  static bool esVerificacion(String? itemId) =>
      itemId != null && itemId.startsWith(prefijoVerificacion);

  static bool esObligatoria(String? itemId) =>
      itemId != null && itemId.startsWith(prefijoObligatoria);

  /// 'verif_examenes_1712345678901' -> 'examenes'
  static String? claveVerificacion(String? itemId) {
    if (!esVerificacion(itemId)) return null;
    return itemId!.substring(prefijoVerificacion.length).split('_').first;
  }

  static String? claveObligatoria(String? itemId) {
    if (!esObligatoria(itemId)) return null;
    return itemId!.substring(prefijoObligatoria.length);
  }

  static FotoEvidenciaTipo clasificar(
    String? itemId, {
    required Set<String> idsPreguntas,
  }) {
    if (itemId == null || itemId.isEmpty || itemId == visitaGeneral) {
      return FotoEvidenciaTipo.general;
    }
    if (esObligatoria(itemId)) return FotoEvidenciaTipo.obligatoria;
    if (esVerificacion(itemId)) return FotoEvidenciaTipo.verificacion;
    if (idsPreguntas.contains(itemId)) return FotoEvidenciaTipo.pregunta;
    return FotoEvidenciaTipo.observacionExtra;
  }
}
