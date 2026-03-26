class VisitaRespuesta {
  final String id;
  final String visitaId;
  final String itemId;
  final String estado; // ej: 'CUMPLE', 'NO_CUMPLE', 'NO_APLICA'
  final String observacion;
  final String? criticidad; // NUEVO
  final String? fotoPath; // NUEVO
  final int subido;

  VisitaRespuesta({
    required this.id,
    required this.visitaId,
    required this.itemId,
    required this.estado,
    required this.observacion,
    this.criticidad,
    this.fotoPath,
    this.subido = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visita_id': visitaId,
      'item_id': itemId,
      'estado': estado,
      'observacion': observacion,
      'criticidad': criticidad,
      'foto_path': fotoPath,
      'subido': subido,
    };
  }

  factory VisitaRespuesta.fromMap(Map<String, dynamic> map) {
    return VisitaRespuesta(
      id: map['id'] as String,
      visitaId: map['visita_id'] as String,
      itemId: map['item_id'] as String,
      estado: map['estado'] as String,
      observacion: map['observacion'] as String,
      criticidad: map['criticidad'] as String?,
      fotoPath: map['foto_path'] as String?,
      subido: map['subido'] as int,
    );
  }
}
