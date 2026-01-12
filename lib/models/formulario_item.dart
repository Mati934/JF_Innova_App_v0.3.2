class FormularioItem {
  final String id;
  final String pregunta;
  final String categoria;
  final String criticidad;

  FormularioItem({
    required this.id,
    required this.pregunta,
    required this.categoria,
    required this.criticidad,
  });

  factory FormularioItem.fromJson(Map<String, dynamic> json) {
    return FormularioItem(
      id: json['id'],
      pregunta: json['pregunta'],
      categoria: json['categoria'],
      criticidad: json['criticidad'] ?? 'Bajo',
    );
  }
}