/// Notificación in-app asociada a un ticket (ver docs/planificacion/02_en_progreso/PLAN_TICKETS_MVP.md §8.4).
enum TicketNotificacionTipo {
  tomado,
  parcial,
  aprobado,
  rechazado;

  String get value => switch (this) {
    TicketNotificacionTipo.tomado => 'TOMADO',
    TicketNotificacionTipo.parcial => 'PARCIAL',
    TicketNotificacionTipo.aprobado => 'APROBADO',
    TicketNotificacionTipo.rechazado => 'RECHAZADO',
  };

  static TicketNotificacionTipo fromValue(String? value) => switch (value) {
    'PARCIAL' => TicketNotificacionTipo.parcial,
    'APROBADO' => TicketNotificacionTipo.aprobado,
    'RECHAZADO' => TicketNotificacionTipo.rechazado,
    _ => TicketNotificacionTipo.tomado,
  };
}

class TicketNotificacionModel {
  final String id;
  final String ticketId;
  final String usuarioDestinoId;
  final TicketNotificacionTipo tipo;
  final String mensaje;
  final bool leido;
  final DateTime? createdAt;

  const TicketNotificacionModel({
    required this.id,
    required this.ticketId,
    required this.usuarioDestinoId,
    required this.tipo,
    required this.mensaje,
    this.leido = false,
    this.createdAt,
  });

  factory TicketNotificacionModel.fromMap(Map<String, dynamic> map) {
    return TicketNotificacionModel(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      usuarioDestinoId: map['usuario_destino_id'] as String,
      tipo: TicketNotificacionTipo.fromValue(map['tipo'] as String?),
      mensaje: map['mensaje'] as String? ?? '',
      leido: map['leido'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
