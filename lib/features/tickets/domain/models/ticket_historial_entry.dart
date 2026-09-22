/// Acción registrada en la bitácora de un ticket (quién lo tomó/soltó/etc).
enum TicketHistorialAccion {
  tomado,
  soltado,
  finalizado,
  revisadoAprobado,
  revisadoRechazado,
  reabierto,
  nuevaOcurrencia;

  String get value => switch (this) {
    TicketHistorialAccion.tomado => 'TOMADO',
    TicketHistorialAccion.soltado => 'SOLTADO',
    TicketHistorialAccion.finalizado => 'FINALIZADO',
    TicketHistorialAccion.revisadoAprobado => 'REVISADO_APROBADO',
    TicketHistorialAccion.revisadoRechazado => 'REVISADO_RECHAZADO',
    TicketHistorialAccion.reabierto => 'REABIERTO',
    TicketHistorialAccion.nuevaOcurrencia => 'NUEVA_OCURRENCIA',
  };

  String get label => switch (this) {
    TicketHistorialAccion.tomado => 'Tomó el ticket',
    TicketHistorialAccion.soltado => 'Soltó el ticket (quedó parcial)',
    TicketHistorialAccion.finalizado => 'Finalizó el ticket (envió a revisión)',
    TicketHistorialAccion.revisadoAprobado => 'Aprobó y cerró el ticket',
    TicketHistorialAccion.revisadoRechazado => 'Rechazó el ticket',
    TicketHistorialAccion.reabierto => 'Reabrió el ticket',
    TicketHistorialAccion.nuevaOcurrencia => 'Registró nueva evidencia',
  };

  static TicketHistorialAccion fromValue(String? value) => switch (value) {
    'SOLTADO' => TicketHistorialAccion.soltado,
    'FINALIZADO' => TicketHistorialAccion.finalizado,
    'REVISADO_APROBADO' => TicketHistorialAccion.revisadoAprobado,
    'REVISADO_RECHAZADO' => TicketHistorialAccion.revisadoRechazado,
    'REABIERTO' => TicketHistorialAccion.reabierto,
    'NUEVA_OCURRENCIA' => TicketHistorialAccion.nuevaOcurrencia,
    _ => TicketHistorialAccion.tomado,
  };
}

class TicketHistorialEntry {
  final String id;
  final String ticketId;
  final String usuarioId;
  final TicketHistorialAccion accion;
  final String? comentario;
  final DateTime? createdAt;
  final String? usuarioNombre;

  const TicketHistorialEntry({
    required this.id,
    required this.ticketId,
    required this.usuarioId,
    required this.accion,
    this.comentario,
    this.createdAt,
    this.usuarioNombre,
  });

  factory TicketHistorialEntry.fromMap(Map<String, dynamic> map) {
    return TicketHistorialEntry(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      usuarioId: map['usuario_id'] as String,
      accion: TicketHistorialAccion.fromValue(map['accion'] as String?),
      comentario: map['comentario'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      usuarioNombre: (map['usuarios'] is Map)
          ? (map['usuarios']['nombre_completo'] as String?)
          : null,
    );
  }
}
