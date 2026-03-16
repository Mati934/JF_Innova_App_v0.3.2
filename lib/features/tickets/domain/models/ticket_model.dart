class TicketModel {
  final String id;
  final String titulo;
  final String descripcion;
  final String estado;
  final String prioridad;
  final String? creadoPor;
  final String? nombreCreador;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  TicketModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.prioridad,
    this.creadoPor,
    this.nombreCreador,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String? ?? '',
      estado: json['estado'] as String? ?? 'Abierto',
      prioridad: json['prioridad'] as String? ?? 'Media',
      creadoPor: json['creado_por'] as String?,
      nombreCreador: json['nombre_creador'] as String?,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      fechaActualizacion:
          DateTime.parse(json['fecha_actualizacion'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'estado': estado,
      'prioridad': prioridad,
      'creado_por': creadoPor,
      'nombre_creador': nombreCreador,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
    };
  }
}
