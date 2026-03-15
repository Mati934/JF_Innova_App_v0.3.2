class TicketModel {
  final String id;
  final String? codigoTicket; // Es null antes de insertarse en la BD

  final String empresaId;
  final String? areaId;
  final String? centroId;
  final String? embarcacionId;
  final String? actividadId;

  final String categoriaId;
  final String? categoriaOtro;

  final String descripcion;
  final String solicitanteId;
  final String? responsableId;

  final String estado;
  final String criticidad;
  final DateTime? fechaTentativaCierre;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TicketModel({
    required this.id,
    this.codigoTicket,
    required this.empresaId,
    this.areaId,
    this.centroId,
    this.embarcacionId,
    this.actividadId,
    required this.categoriaId,
    this.categoriaOtro,
    required this.descripcion,
    required this.solicitanteId,
    this.responsableId,
    this.estado = 'Abierto',
    this.criticidad = 'Medio',
    this.fechaTentativaCierre,
    this.createdAt,
    this.updatedAt,
  });

  TicketModel copyWith({
    String? id,
    String? codigoTicket,
    String? empresaId,
    String? areaId,
    String? centroId,
    String? embarcacionId,
    String? actividadId,
    String? categoriaId,
    String? categoriaOtro,
    String? descripcion,
    String? solicitanteId,
    String? responsableId,
    String? estado,
    String? criticidad,
    DateTime? fechaTentativaCierre,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TicketModel(
      id: id ?? this.id,
      codigoTicket: codigoTicket ?? this.codigoTicket,
      empresaId: empresaId ?? this.empresaId,
      areaId: areaId ?? this.areaId,
      centroId: centroId ?? this.centroId,
      embarcacionId: embarcacionId ?? this.embarcacionId,
      actividadId: actividadId ?? this.actividadId,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaOtro: categoriaOtro ?? this.categoriaOtro,
      descripcion: descripcion ?? this.descripcion,
      solicitanteId: solicitanteId ?? this.solicitanteId,
      responsableId: responsableId ?? this.responsableId,
      estado: estado ?? this.estado,
      criticidad: criticidad ?? this.criticidad,
      fechaTentativaCierre: fechaTentativaCierre ?? this.fechaTentativaCierre,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TicketModel.fromMap(Map<String, dynamic> map) {
    return TicketModel(
      id: map['id'] as String,
      codigoTicket: map['codigo_ticket'] as String?,
      empresaId: map['empresa_id'] as String,
      areaId: map['area_id'] as String?,
      centroId: map['centro_id'] as String?,
      embarcacionId: map['embarcacion_id'] as String?,
      actividadId: map['actividad_id'] as String?,
      categoriaId: map['categoria_id'] as String,
      categoriaOtro: map['categoria_otro'] as String?,
      descripcion: map['descripcion'] as String,
      solicitanteId: map['solicitante_id'] as String,
      responsableId: map['responsable_id'] as String?,
      estado: map['estado'] as String? ?? 'Abierto',
      criticidad: map['criticidad'] as String? ?? 'Medio',
      fechaTentativaCierre: map['fecha_tentativa_cierre'] != null
          ? DateTime.tryParse(map['fecha_tentativa_cierre'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // No mandamos codigoTicket al crear, la BD lo genera
      'empresa_id': empresaId,
      'area_id': areaId,
      'centro_id': centroId,
      'embarcacion_id': embarcacionId,
      'actividad_id': actividadId,
      'categoria_id': categoriaId,
      'categoria_otro': categoriaOtro,
      'descripcion': descripcion,
      'solicitante_id': solicitanteId,
      'responsable_id': responsableId,
      'estado': estado,
      'criticidad': criticidad,
      'fecha_tentativa_cierre': fechaTentativaCierre?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      // No mandamos updatedAt, lo maneja Supabase
    };
  }
}
