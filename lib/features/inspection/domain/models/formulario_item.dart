class FormularioItem {
  final String id;
  final String pregunta;
  final String categoria;
  final String criticidad;
  final String? infoAdicional;

  FormularioItem({
    required this.id,
    required this.pregunta,
    required this.categoria,
    required this.criticidad,
    this.infoAdicional,
  });

  factory FormularioItem.fromJson(Map<String, dynamic> json) {
    return FormularioItem(
      id: json['id'],
      pregunta: json['pregunta'],
      categoria: json['categoria'],
      criticidad: json['criticidad'] ?? 'Bajo',
      infoAdicional: json['info_adicional'] ?? json['infoAdicional'],
    );
  }
}
