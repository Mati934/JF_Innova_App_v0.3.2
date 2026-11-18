/// Formato interno del informe de inspección. Lo fija el módulo con que se
/// crea la actividad (`INSPECCION_SEAROV` → `SEAROV`) y queda guardado en
/// `actividades.formato_informe`. El usuario no lo ve: cambia el banco de
/// preguntas y el diseño del PDF, no el flujo.
class FormatoInspeccion {
  static const estandar = 'ESTANDAR';
  static const searov = 'SEAROV';

  /// Clave del banco de preguntas en `formulario_items`. La actividad sigue
  /// siendo `INSPECCION_BUCEO` / `INSPECCION_EMBARCACION` (numeración,
  /// tickets e historial no cambian); solo las preguntas vienen de otra clave.
  static String bancoPreguntas(String tipoActividad, String formato) =>
      formato == searov ? '${tipoActividad}_SEAROV' : tipoActividad;

  /// Respuesta consolidada de una pregunta "por buzo": basta un buzo con
  /// No cumple para que la pregunta sea No cumple. Null si nadie respondió.
  static String? consolidarPorBuzo(Iterable<String?> respuestas) {
    final valores = respuestas.whereType<String>().toSet();
    if (valores.contains('NC')) return 'NC';
    if (valores.contains('C')) return 'C';
    if (valores.contains('N/A')) return 'N/A';
    return null;
  }

  /// Resultado del formato de embarcación por potencialidad:
  /// un incumplimiento ALTA rechaza; de 1 a 5 MEDIA autoriza condicional
  /// (7 días); 6 o más MEDIA rechaza. Es independiente de la criticidad.
  static ResultadoPotencialidad resultadoPorPotencialidad(
    Iterable<({String? potencialidad, String respuesta})> items,
  ) {
    var altas = 0;
    var medias = 0;
    for (final item in items) {
      if (item.respuesta != 'NC') continue;
      if (item.potencialidad == 'ALTA') altas++;
      if (item.potencialidad == 'MEDIA') medias++;
    }
    if (altas > 0 || medias >= 6) {
      return ResultadoPotencialidad(
        ResultadoEmbarcacion.rechazada,
        altas,
        medias,
      );
    }
    if (medias > 0) {
      return ResultadoPotencialidad(
        ResultadoEmbarcacion.condicional,
        altas,
        medias,
      );
    }
    return ResultadoPotencialidad(ResultadoEmbarcacion.autorizada, 0, 0);
  }
}

enum ResultadoEmbarcacion {
  autorizada('FAENA AUTORIZADA'),
  condicional('AUTORIZADA CONDICIONAL'),
  rechazada('RECHAZADA');

  const ResultadoEmbarcacion(this.etiqueta);
  final String etiqueta;
}

class ResultadoPotencialidad {
  final ResultadoEmbarcacion resultado;
  final int incumplimientosAlta;
  final int incumplimientosMedia;

  const ResultadoPotencialidad(
    this.resultado,
    this.incumplimientosAlta,
    this.incumplimientosMedia,
  );
}
