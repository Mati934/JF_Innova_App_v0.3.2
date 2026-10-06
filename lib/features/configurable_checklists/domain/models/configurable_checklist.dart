import 'dart:convert';

bool checklistBool(Object? value) => value == true || value == 1;

Object? checklistJson(Object? value) {
  if (value is String) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }
  return value;
}

class ChecklistFormType {
  final String key;
  final String nombre;
  final String pdfTemplateKey;
  final bool permiteRespuestas;
  final bool permiteFotos;
  final bool permiteFirma;
  final bool requiereObservacionNc;
  final bool requiereFotoNc;
  final bool usaCriticidad;
  final bool requiereCriticidadNc;

  const ChecklistFormType({
    required this.key,
    required this.nombre,
    required this.pdfTemplateKey,
    required this.permiteRespuestas,
    required this.permiteFotos,
    required this.permiteFirma,
    required this.requiereObservacionNc,
    required this.requiereFotoNc,
    required this.usaCriticidad,
    required this.requiereCriticidadNc,
  });

  factory ChecklistFormType.fromMap(Map<String, dynamic> map) {
    return ChecklistFormType(
      key: (map['form_type_key'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      pdfTemplateKey: (map['pdf_template_key'] ?? '').toString(),
      permiteRespuestas: checklistBool(map['permite_respuestas']),
      permiteFotos: checklistBool(map['permite_fotos']),
      permiteFirma: checklistBool(map['permite_firma']),
      requiereObservacionNc: checklistBool(map['requiere_observacion_nc']),
      requiereFotoNc: checklistBool(map['requiere_foto_nc']),
      usaCriticidad: checklistBool(map['usa_criticidad']),
      requiereCriticidadNc: checklistBool(map['requiere_criticidad_nc']),
    );
  }
}

class ConfigurableChecklist {
  final String key;
  final String formTypeKey;
  final String permissionKey;
  final String reportPrefix;
  final String nombre;
  final String? subtitulo;
  final String? icono;
  final String? color;
  final int publishedVersion;

  String get nombreVisible => nombre.replaceFirst(
    RegExp(r'^Chequeo(?: de)?\s+', caseSensitive: false),
    '',
  );

  const ConfigurableChecklist({
    required this.key,
    required this.formTypeKey,
    required this.permissionKey,
    required this.reportPrefix,
    required this.nombre,
    this.subtitulo,
    this.icono,
    this.color,
    required this.publishedVersion,
  });

  factory ConfigurableChecklist.fromMap(Map<String, dynamic> map) {
    return ConfigurableChecklist(
      key: (map['checklist_key'] ?? '').toString(),
      formTypeKey: (map['form_type_key'] ?? '').toString(),
      permissionKey: (map['permission_key'] ?? '').toString(),
      reportPrefix: (map['report_prefix'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      subtitulo: map['subtitulo']?.toString(),
      icono: map['icono']?.toString(),
      color: map['color']?.toString(),
      publishedVersion: (map['published_version'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChecklistVersion {
  final String id;
  final String checklistKey;
  final int version;
  final String estado;
  final List<Map<String, dynamic>> preguntas;
  final List<Map<String, dynamic>> camposExtra;
  final Map<String, dynamic> reglas;

  const ChecklistVersion({
    required this.id,
    required this.checklistKey,
    required this.version,
    required this.estado,
    required this.preguntas,
    required this.camposExtra,
    required this.reglas,
  });

  factory ChecklistVersion.fromMap(Map<String, dynamic> map) {
    final rawQuestions = checklistJson(map['snapshot_preguntas']);
    final rawFields = checklistJson(map['snapshot_campos_extra']);
    final rawRules = checklistJson(map['snapshot_reglas']);
    return ChecklistVersion(
      id: (map['id'] ?? '').toString(),
      checklistKey: (map['checklist_key'] ?? '').toString(),
      version: (map['version'] as num?)?.toInt() ?? 0,
      estado: (map['estado'] ?? '').toString(),
      preguntas: rawQuestions is List
          ? rawQuestions
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList()
          : const [],
      camposExtra: rawFields is List
          ? rawFields.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : const [],
      reglas: rawRules is Map ? Map<String, dynamic>.from(rawRules) : const {},
    );
  }

  /// Vista tipada de [camposExtra] (catálogo de campos dinámicos congelado en
  /// el snapshot al publicar la versión). Ver `checklist_campo_definiciones`
  /// / `checklist_campo_asignaciones` en Supabase para el origen editable.
  List<ChecklistCampoDefinicion> get camposDefiniciones =>
      camposExtra.map(ChecklistCampoDefinicion.fromMap).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
}

/// Definición de un campo dinámico ("dato general") de un checklist,
/// congelada en `checklist_versions.snapshot_campos_extra` al publicar.
/// El catálogo editable vive en `checklist_campo_definiciones` +
/// `checklist_campo_asignaciones` (Supabase); esta clase solo representa la
/// foto ya publicada que la app usa para renderizar y guardar valores.
class ChecklistCampoDefinicion {
  final String id;
  final String clave;
  final String etiqueta;
  final String tipo;
  final List<String> opciones;
  final String? unidad;
  final String seccion;
  final int orden;
  final bool requerido;

  const ChecklistCampoDefinicion({
    required this.id,
    required this.clave,
    required this.etiqueta,
    required this.tipo,
    this.opciones = const [],
    this.unidad,
    this.seccion = 'Datos generales',
    this.orden = 0,
    this.requerido = false,
  });

  factory ChecklistCampoDefinicion.fromMap(Map<String, dynamic> map) {
    final rawOpciones = map['opciones'];
    return ChecklistCampoDefinicion(
      id: (map['id'] ?? '').toString(),
      clave: (map['clave'] ?? '').toString(),
      etiqueta: (map['etiqueta'] ?? '').toString(),
      tipo: (map['tipo'] ?? 'texto').toString(),
      opciones: rawOpciones is List
          ? rawOpciones.map((e) => e.toString()).toList()
          : const [],
      unidad: map['unidad']?.toString(),
      seccion: (map['seccion'] ?? 'Datos generales').toString(),
      orden: (map['orden'] as num?)?.toInt() ?? 0,
      requerido: checklistBool(map['requerido']),
    );
  }
}

class ChecklistNavigationNode {
  final String key;
  final String empresaId;
  final String? parentNodeKey;
  final String nodeType;
  final String? checklistKey;
  final String permissionKey;
  final String titulo;
  final String? icono;
  final String? color;
  final int orden;
  final bool habilitado;

  const ChecklistNavigationNode({
    required this.key,
    required this.empresaId,
    this.parentNodeKey,
    required this.nodeType,
    this.checklistKey,
    required this.permissionKey,
    required this.titulo,
    this.icono,
    this.color,
    required this.orden,
    this.habilitado = true,
  });

  bool get isGroup => nodeType == 'GROUP';

  factory ChecklistNavigationNode.fromMap(Map<String, dynamic> map) {
    return ChecklistNavigationNode(
      key: (map['node_key'] ?? '').toString(),
      empresaId: (map['empresa_id'] ?? '').toString(),
      parentNodeKey: map['parent_node_key']?.toString(),
      nodeType: (map['node_type'] ?? '').toString(),
      checklistKey: map['checklist_key']?.toString(),
      permissionKey: (map['permission_key'] ?? '').toString(),
      titulo: (map['titulo'] ?? '').toString(),
      icono: map['icono']?.toString(),
      color: map['color']?.toString(),
      orden: (map['orden'] as num?)?.toInt() ?? 0,
      habilitado: checklistBool(map['habilitado']),
    );
  }
}
