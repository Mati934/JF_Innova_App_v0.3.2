import 'dart:typed_data';

/// Respuesta a un ítem del checklist de Equipamiento de Buceo dentro de una
/// inspección. Módulo independiente (tablas propias `buceo_equipamiento_*`).
class BuceoEquipmentRespuesta {
  final String id;
  final String inspeccionId;
  final String itemId;
  String estado; // 'C' | 'NC' | 'NA'
  String? observacion;
  String? criticidad; // 'Tolerable' | 'Moderado' | 'Intolerable'
  String? fotoPath;

  BuceoEquipmentRespuesta({
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

/// Cabecera de una inspección del módulo Equipamiento de Buceo.
class BuceoEquipmentInspeccion {
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

  BuceoEquipmentInspeccion({
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
