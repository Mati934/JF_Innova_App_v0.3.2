import 'dart:typed_data';

/// Representa una respuesta a un ítem del checklist Hidroser dentro de una inspección.
class HidroserRespuesta {
  final String id;
  final String inspeccionId;
  final String itemId;
  String estado; // 'C' | 'NC' | 'NA'
  String? observacion;
  String? criticidad; // 'Baja' | 'Media' | 'Alta'
  String? fotoPath;

  HidroserRespuesta({
    required this.id,
    required this.inspeccionId,
    required this.itemId,
    this.estado = 'C',
    this.observacion,
    this.criticidad,
    this.fotoPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'inspeccion_id': inspeccionId,
    'item_id': itemId,
    'estado': estado,
    'observacion': observacion,
    'criticidad': criticidad,
    'foto_path': fotoPath,
  };
}

/// Cabecera de una inspección Hidroser (un evento de aplicación de una lista).
class HidroserInspeccion {
  final String id;
  String listaCodigo;
  String? usuarioId;
  String? empresaId;
  DateTime fechaRealizacion;
  String? correlativo;
  String? quienInspecciona;
  String? observaciones;
  Map<String, String> camposExtra;
  String? firmaSupervisorNombre;
  String? firmaOperadorNombre;
  Uint8List? firmaSupervisorImage;
  Uint8List? firmaOperadorImage;
  String estadoFinal; // 'Borrador' | 'En Seguimiento' | 'Eliminada'
  String? pdfUrl;
  String? pdfPathLocal;

  HidroserInspeccion({
    required this.id,
    required this.listaCodigo,
    required this.fechaRealizacion,
    this.usuarioId,
    this.empresaId,
    this.correlativo,
    this.quienInspecciona,
    this.observaciones,
    Map<String, String>? camposExtra,
    this.firmaSupervisorNombre,
    this.firmaOperadorNombre,
    this.firmaSupervisorImage,
    this.firmaOperadorImage,
    this.estadoFinal = 'Borrador',
    this.pdfUrl,
    this.pdfPathLocal,
  }) : camposExtra = camposExtra ?? <String, String>{};
}
