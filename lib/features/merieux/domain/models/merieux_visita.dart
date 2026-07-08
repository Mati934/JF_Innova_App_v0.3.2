import 'dart:typed_data';

/// Valores posibles de `tipo_actividad` en `merieux_visitas` — distingue los
/// 2 submódulos que comparten la misma cabecera.
const String kMerieuxTipoVisitas = 'MERIEUX_VISITAS';
const String kMerieuxTipoExtintores = 'MERIEUX_EXTINTORES';

/// Único checklist disponible hoy para el submódulo de Visitas (reusa el
/// mismo banco de preguntas que VISITA_R008 "Chequeo Vehículos Livianos").
/// `null` en `checklistTipo` significa "Registro de Visita (Sin checklist)".
const String kMerieuxChecklistVehiculosLivianos = 'VISITA_R008';

/// Tipo de actividad de `formulario_items` reusado para el checklist de
/// extintores del submódulo MERIEUX_EXTINTORES (mismo banco que Prosesso).
const String kMerieuxTipoFormularioExtintores = 'MANTENCION_PROSESSO';

/// Respuesta a una pregunta del checklist del submódulo MERIEUX_VISITAS.
class MerieuxRespuesta {
  final String id;
  final String visitaId;
  final String itemId;
  String estado; // 'C' | 'NC' | 'NA'
  String? observacion;
  String? criticidad;
  String? fotoPath;

  MerieuxRespuesta({
    required this.id,
    required this.visitaId,
    required this.itemId,
    this.estado = 'C',
    this.observacion,
    this.criticidad,
    this.fotoPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'visita_id': visitaId,
    'item_id': itemId,
    'estado': estado,
    'observacion': observacion,
    'criticidad': criticidad,
    'foto_path': fotoPath,
  };
}

/// Cabecera compartida por los 2 submódulos Merieux. Los 10 campos pedidos
/// por el usuario: profesional/fono/correo (autocompletados de la sesión),
/// región, área, jefatura a cargo, hora inicio/término, origen de la
/// actividad y correos del informe.
class MerieuxVisita {
  final String id;
  String tipoActividad; // kMerieuxTipoVisitas | kMerieuxTipoExtintores
  String? checklistTipo; // solo MERIEUX_VISITAS: null | VISITA_R008
  String? usuarioId;
  String? empresaId;

  String? profesional;
  String? fonoProfesional;
  String? correoProfesional;

  String? region;
  String? area;
  String? jefaturaACargo;
  String? origenActividad;

  DateTime fechaRealizacion;
  String? horaInicio;
  String? horaTermino;
  String? correo1;
  String? correo2;

  String? observaciones;
  String? correlativo;
  String estadoFinal; // 'En Progreso' | 'En Seguimiento' | 'Eliminada'
  String?
  firmaNombre; // nombre que firma (autocompletado del profesional, editable)
  Uint8List? signatureImage;
  String? pdfUrl;
  String? pdfPathLocal;

  MerieuxVisita({
    required this.id,
    required this.tipoActividad,
    required this.fechaRealizacion,
    this.checklistTipo,
    this.usuarioId,
    this.empresaId,
    this.profesional,
    this.fonoProfesional,
    this.correoProfesional,
    this.region,
    this.area,
    this.jefaturaACargo,
    this.origenActividad,
    this.horaInicio,
    this.horaTermino,
    this.correo1,
    this.correo2,
    this.observaciones,
    this.correlativo,
    this.estadoFinal = 'En Progreso',
    this.firmaNombre,
    this.signatureImage,
    this.pdfUrl,
    this.pdfPathLocal,
  });
}
