class TicketCategoriaModel {
  final String id;
  final String nombre;
  final bool activo;

  const TicketCategoriaModel({
    required this.id,
    required this.nombre,
    this.activo = true,
  });

  factory TicketCategoriaModel.fromMap(Map<String, dynamic> map) {
    return TicketCategoriaModel(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      activo: map['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'nombre': nombre, 'activo': activo};
  }
}
