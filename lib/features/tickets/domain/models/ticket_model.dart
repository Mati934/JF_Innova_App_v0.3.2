/// Origen de un ticket: generado desde una inspección o solicitado manualmente.
enum TicketOrigen {
  inspeccion,
  solicitud;

  String get value => switch (this) {
    TicketOrigen.inspeccion => 'INSPECCION',
    TicketOrigen.solicitud => 'SOLICITUD',
  };

  static TicketOrigen fromValue(String? value) => switch (value) {
    'INSPECCION' => TicketOrigen.inspeccion,
    _ => TicketOrigen.solicitud,
  };
}

/// Categoría visible del ticket (para filtros).
enum TicketTipo {
  revisionObservaciones,
  solicitud;

  String get value => switch (this) {
    TicketTipo.revisionObservaciones => 'REVISION_OBSERVACIONES',
    TicketTipo.solicitud => 'SOLICITUD',
  };

  String get label => switch (this) {
    TicketTipo.revisionObservaciones => 'Revisión de observaciones',
    TicketTipo.solicitud => 'Solicitud',
  };

  static TicketTipo fromValue(String? value) => switch (value) {
    'REVISION_OBSERVACIONES' => TicketTipo.revisionObservaciones,
    _ => TicketTipo.solicitud,
  };
}

/// Estados del ciclo de vida de un ticket (ver docs/planificacion/02_en_progreso/PLAN_TICKETS_MVP.md §4.1).
enum TicketEstado {
  abierto,
  tomado,
  parcial,
  finalizadoPendienteRevision,
  cerrado;

  String get value => switch (this) {
    TicketEstado.abierto => 'ABIERTO',
    TicketEstado.tomado => 'TOMADO',
    TicketEstado.parcial => 'PARCIAL',
    TicketEstado.finalizadoPendienteRevision => 'FINALIZADO_PENDIENTE_REVISION',
    TicketEstado.cerrado => 'CERRADO',
  };

  String get label => switch (this) {
    TicketEstado.abierto => 'Abierto',
    TicketEstado.tomado => 'Tomado',
    TicketEstado.parcial => 'Parcial',
    TicketEstado.finalizadoPendienteRevision => 'Pendiente de revisión',
    TicketEstado.cerrado => 'Cerrado',
  };

  static TicketEstado fromValue(String? value) => switch (value) {
    'TOMADO' => TicketEstado.tomado,
    'PARCIAL' => TicketEstado.parcial,
    'FINALIZADO_PENDIENTE_REVISION' => TicketEstado.finalizadoPendienteRevision,
    'CERRADO' => TicketEstado.cerrado,
    _ => TicketEstado.abierto,
  };
}

class TicketModel {
  final String id;
  final String? codigoTicket;
  final String empresaId;
  final TicketOrigen origen;
  final TicketTipo tipoTicket;
  final String? inspeccionId;
  final String? hallazgoId;
  final String? tipoInspeccion;
  final String? numeroInforme;
  final String? areaId;
  final String? centroId;
  final String? embarcacionId;
  final String? contratistaId;
  final String? asunto;
  final String? motivo;
  final String generadoPorId;
  final TicketEstado estado;
  final String? tomadoPorId;
  final DateTime? fechaLimite;
  final String? revisadoPorId;
  final DateTime? revisadoAt;
  final bool rechazado;
  final String? motivoRechazo;
  final String? rechazadoPorId;
  final DateTime? rechazadoAt;
  final Map<String, dynamic> camposExtra;
  final bool eliminado;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TicketModel({
    required this.id,
    this.codigoTicket,
    required this.empresaId,
    required this.origen,
    required this.tipoTicket,
    this.inspeccionId,
    this.hallazgoId,
    this.tipoInspeccion,
    this.numeroInforme,
    this.areaId,
    this.centroId,
    this.embarcacionId,
    this.contratistaId,
    this.asunto,
    this.motivo,
    required this.generadoPorId,
    this.estado = TicketEstado.abierto,
    this.tomadoPorId,
    this.fechaLimite,
    this.revisadoPorId,
    this.revisadoAt,
    this.rechazado = false,
    this.motivoRechazo,
    this.rechazadoPorId,
    this.rechazadoAt,
    this.camposExtra = const {},
    this.eliminado = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Título corto para mostrar en listas.
  String get tituloVisible {
    final a = asunto?.trim();
    if (a != null && a.isNotEmpty) return a;
    final m = motivo?.trim();
    if (m != null && m.isNotEmpty) {
      return m.length > 60 ? '${m.substring(0, 60)}…' : m;
    }
    return origen == TicketOrigen.inspeccion
        ? 'Observación de inspección'
        : 'Solicitud';
  }

  bool get estaVencido {
    if (fechaLimite == null) return false;
    if (estado == TicketEstado.cerrado) return false;
    return fechaLimite!.isBefore(DateTime.now());
  }

  factory TicketModel.fromMap(Map<String, dynamic> map) {
    return TicketModel(
      id: map['id'] as String,
      codigoTicket: map['codigo_ticket'] as String?,
      empresaId: map['empresa_id'] as String,
      origen: TicketOrigen.fromValue(map['origen'] as String?),
      tipoTicket: TicketTipo.fromValue(map['tipo_ticket'] as String?),
      inspeccionId: map['inspeccion_id'] as String?,
      hallazgoId: map['hallazgo_id'] as String?,
      tipoInspeccion: map['tipo_inspeccion'] as String?,
      numeroInforme: map['numero_informe'] as String?,
      areaId: map['area_id'] as String?,
      centroId: map['centro_id'] as String?,
      embarcacionId: map['embarcacion_id'] as String?,
      contratistaId: map['contratista_id'] as String?,
      asunto: map['asunto'] as String?,
      motivo: map['motivo'] as String?,
      generadoPorId: map['generado_por_id'] as String,
      estado: TicketEstado.fromValue(map['estado'] as String?),
      tomadoPorId: map['tomado_por_id'] as String?,
      fechaLimite: map['fecha_limite'] != null
          ? DateTime.tryParse(map['fecha_limite'].toString())
          : null,
      revisadoPorId: map['revisado_por_id'] as String?,
      revisadoAt: map['revisado_at'] != null
          ? DateTime.tryParse(map['revisado_at'].toString())
          : null,
      rechazado: map['rechazado'] == true,
      motivoRechazo: map['motivo_rechazo'] as String?,
      rechazadoPorId: map['rechazado_por_id'] as String?,
      rechazadoAt: map['rechazado_at'] != null
          ? DateTime.tryParse(map['rechazado_at'].toString())
          : null,
      camposExtra:
          (map['campos_extra_json'] as Map?)?.cast<String, dynamic>() ??
          const {},
      eliminado: map['eliminado'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  /// Datos para INSERT (no incluye campos que la BD maneja sola: codigo_ticket,
  /// estado inicial, timestamps).
  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'empresa_id': empresaId,
      'origen': origen.value,
      'tipo_ticket': tipoTicket.value,
      'inspeccion_id': inspeccionId,
      'hallazgo_id': hallazgoId,
      'tipo_inspeccion': tipoInspeccion,
      'numero_informe': numeroInforme,
      'area_id': areaId,
      'centro_id': centroId,
      'embarcacion_id': embarcacionId,
      'contratista_id': contratistaId,
      'asunto': asunto,
      'motivo': motivo,
      'generado_por_id': generadoPorId,
      'fecha_limite': fechaLimite?.toIso8601String(),
      'campos_extra_json': camposExtra,
    };
  }
}
