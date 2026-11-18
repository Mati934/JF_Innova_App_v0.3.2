class FormularioItem {
  final String id;
  final String pregunta;
  final String categoria;
  final String criticidad;
  final int orden;
  final double peso;
  final String? infoAdicional;
  final String? urlImagenReferencia;

  /// `ALTA` / `MEDIA` en el formato de embarcación Searov; null en el resto.
  /// Es una medición distinta de la criticidad.
  final String? potencialidad;

  /// La pregunta se responde una vez por cada buzo de la cuadrilla.
  final bool aplicaPorBuzo;

  FormularioItem({
    required this.id,
    required this.pregunta,
    required this.categoria,
    required this.criticidad,
    this.orden = 0,
    this.peso = 1.0,
    this.infoAdicional,
    this.urlImagenReferencia,
    this.potencialidad,
    this.aplicaPorBuzo = false,
  });

  factory FormularioItem.fromJson(Map<String, dynamic> json) {
    return FormularioItem(
      id: json['id'],
      pregunta: json['pregunta'],
      categoria: json['categoria'],
      criticidad: json['criticidad'] ?? 'Tolerable',
      orden: json['orden'] as int? ?? 0,
      peso: (json['peso'] as num?)?.toDouble() ?? 1.0,
      infoAdicional: json['info_adicional'] ?? json['infoAdicional'],
      urlImagenReferencia: json['url_imagen_referencia'],
      potencialidad: json['potencialidad'] as String?,
      aplicaPorBuzo:
          json['aplica_por_buzo'] == 1 || json['aplica_por_buzo'] == true,
    );
  }
}
