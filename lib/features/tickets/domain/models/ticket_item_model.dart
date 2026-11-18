/// Origen de un [TicketItemModel] dentro de un ticket.
enum TicketItemOrigen {
  respuestaInspeccion,
  fotoObservacion,
  manual;

  String get value => switch (this) {
    TicketItemOrigen.respuestaInspeccion => 'RESPUESTA_INSPECCION',
    TicketItemOrigen.fotoObservacion => 'FOTO_OBSERVACION',
    TicketItemOrigen.manual => 'MANUAL',
  };

  static TicketItemOrigen fromValue(String? value) => switch (value) {
    'FOTO_OBSERVACION' => TicketItemOrigen.fotoObservacion,
    'MANUAL' => TicketItemOrigen.manual,
    _ => TicketItemOrigen.respuestaInspeccion,
  };
}

/// Una observación / no-cumple a subsanar dentro de un ticket.
class TicketItemModel {
  final String id;
  final String ticketId;
  final TicketItemOrigen origenItem;
  final String? referenciaId;
  final String descripcion;
  final String? fotoOriginalUrl;
  final bool subsanado;
  final String? fotoSubsanacionUrl;
  final String? subsanadoPorId;
  final DateTime? subsanadoAt;
  final int orden;
  final DateTime? createdAt;

  /// Categoría de la pregunta original (solo aplica a ítems de origen
  /// [TicketItemOrigen.respuestaInspeccion]; viene de `formulario_items.categoria`).
  final String? categoria;

  /// Número/orden de la pregunta dentro del checklist original (solo aplica
  /// a ítems de origen [TicketItemOrigen.respuestaInspeccion]; viene de
  /// `formulario_items.orden`).
  final int? numeroPregunta;

  /// Texto de la pregunta (título del ítem). Solo aplica a ítems de origen
  /// [TicketItemOrigen.respuestaInspeccion]. Para
  /// [TicketItemOrigen.fotoObservacion] es null: en ese caso [descripcion]
  /// ya contiene el texto de la observación de la foto.
  final String? pregunta;

  const TicketItemModel({
    required this.id,
    required this.ticketId,
    required this.origenItem,
    this.referenciaId,
    required this.descripcion,
    this.fotoOriginalUrl,
    this.subsanado = false,
    this.fotoSubsanacionUrl,
    this.subsanadoPorId,
    this.subsanadoAt,
    this.orden = 0,
    this.createdAt,
    this.categoria,
    this.numeroPregunta,
    this.pregunta,
  });

  TicketItemModel copyWith({bool? subsanado, String? fotoSubsanacionUrl}) {
    return TicketItemModel(
      id: id,
      ticketId: ticketId,
      origenItem: origenItem,
      referenciaId: referenciaId,
      descripcion: descripcion,
      fotoOriginalUrl: fotoOriginalUrl,
      subsanado: subsanado ?? this.subsanado,
      fotoSubsanacionUrl: fotoSubsanacionUrl ?? this.fotoSubsanacionUrl,
      subsanadoPorId: subsanadoPorId,
      subsanadoAt: subsanadoAt,
      orden: orden,
      createdAt: createdAt,
      categoria: categoria,
      numeroPregunta: numeroPregunta,
      pregunta: pregunta,
    );
  }

  factory TicketItemModel.fromMap(Map<String, dynamic> map) {
    return TicketItemModel(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      origenItem: TicketItemOrigen.fromValue(map['origen_item'] as String?),
      referenciaId: map['referencia_id'] as String?,
      descripcion: map['descripcion'] as String? ?? '',
      fotoOriginalUrl: map['foto_original_url'] as String?,
      subsanado: map['subsanado'] == true,
      fotoSubsanacionUrl: map['foto_subsanacion_url'] as String?,
      subsanadoPorId: map['subsanado_por_id'] as String?,
      subsanadoAt: map['subsanado_at'] != null
          ? DateTime.tryParse(map['subsanado_at'].toString())
          : null,
      orden: map['orden'] as int? ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      categoria: map['categoria'] as String?,
      numeroPregunta: map['numero_pregunta'] as int?,
      pregunta: map['pregunta'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'origen_item': origenItem.value,
      'referencia_id': referenciaId,
      'descripcion': descripcion,
      'foto_original_url': fotoOriginalUrl,
      'orden': orden,
      'categoria': categoria,
      'numero_pregunta': numeroPregunta,
      'pregunta': pregunta,
    };
  }
}
