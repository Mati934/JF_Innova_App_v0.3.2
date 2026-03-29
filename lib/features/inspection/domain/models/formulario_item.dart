class FormularioItem {
  final String id;
  final String pregunta;
  final String categoria;
  final String criticidad;
  final String? infoAdicional;
  final String? urlImagenReferencia;

  FormularioItem({
    required this.id,
    required this.pregunta,
    required this.categoria,
    required this.criticidad,
    this.infoAdicional,
    this.urlImagenReferencia,
  });

  factory FormularioItem.fromJson(Map<String, dynamic> json) {
    return FormularioItem(
      id: json['id'],
      pregunta: json['pregunta'],
      categoria: json['categoria'],
      criticidad: json['criticidad'] ?? 'Tolerable',
      infoAdicional: json['info_adicional'] ?? json['infoAdicional'],
      urlImagenReferencia: json['url_imagen_referencia'],
    );
  }
}
