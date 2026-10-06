/// Modelos del módulo AST (Análisis Seguro de Trabajo).
///
/// El módulo es independiente del registro de visita / inspecciones: tiene sus
/// propias tablas locales (`ast_informes_pendientes`, `ast_hallazgos_pendientes`)
/// y su propia secuencia/correlativo en Supabase (asignado por trigger cuando
/// el informe pasa a estado `En Seguimiento`).

/// Un hallazgo detectado durante el AST. Reutilizable como tarjeta en la UI.
class AstHallazgo {
  final String id;
  final String informeId;

  /// Número correlativo del hallazgo dentro del informe (1, 2, 3...).
  int numero;

  /// Título corto del hallazgo (qué se encontró).
  String titulo;

  /// Detalle / descripción ampliada del hallazgo.
  String detalle;

  /// Ruta local de la foto de evidencia (puede ser null).
  String? fotoPath;

  AstHallazgo({
    required this.id,
    required this.informeId,
    required this.numero,
    this.titulo = '',
    this.detalle = '',
    this.fotoPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'informe_id': informeId,
    'numero': numero,
    'titulo': titulo,
    'detalle': detalle,
    'foto_path': fotoPath,
  };

  factory AstHallazgo.fromMap(Map<String, dynamic> m) => AstHallazgo(
    id: m['id'] as String,
    informeId: m['informe_id'] as String,
    numero: (m['numero'] is num) ? (m['numero'] as num).toInt() : 0,
    titulo: (m['titulo'] ?? '') as String,
    detalle: (m['detalle'] ?? '') as String,
    fotoPath: m['foto_path'] as String?,
  );
}

/// Cabecera de un informe AST.
class AstInforme {
  final String id;
  String? usuarioId;
  String? empresaId;

  // Ubicación / contexto
  String? areaId;
  String? centroId;
  String? contratistaId; // "Empresa" en la UI
  String? embarcacionId; // Opcional

  // Datos descriptivos (para mostrar en PDF/historial sin joins online)
  String? areaNombre;
  String? centroNombre;
  String? contratistaNombre;
  String? embarcacionNombre;

  String profesional;
  DateTime fechaRealizacion;

  String descripcionActividad;
  String observaciones;

  /// Correlativo asignado por Supabase al finalizar (ej. AST-2025-0001).
  String? correlativo;

  String estadoFinal; // 'En Progreso' | 'En Seguimiento' | 'Eliminada'
  String? pdfUrl;
  String? pdfPathLocal;

  /// Rutas locales de la galería general (se serializan a JSON en SQLite).
  List<String> fotosGenerales;

  AstInforme({
    required this.id,
    this.usuarioId,
    this.empresaId,
    this.areaId,
    this.centroId,
    this.contratistaId,
    this.embarcacionId,
    this.areaNombre,
    this.centroNombre,
    this.contratistaNombre,
    this.embarcacionNombre,
    this.profesional = '',
    DateTime? fechaRealizacion,
    this.descripcionActividad = '',
    this.observaciones = '',
    this.correlativo,
    this.estadoFinal = 'En Progreso',
    this.pdfUrl,
    this.pdfPathLocal,
    List<String>? fotosGenerales,
  }) : fechaRealizacion = fechaRealizacion ?? DateTime.now(),
       fotosGenerales = fotosGenerales ?? <String>[];
}
