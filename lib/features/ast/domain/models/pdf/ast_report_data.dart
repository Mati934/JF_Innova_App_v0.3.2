/// Datos planos y serializables que se envían al isolate para generar el PDF
/// del módulo AST. Diseñado para producir un informe limpio y ordenado.
class AstReportData {
  // --- Marca / encabezado ---
  final String empresaProveedor; // Empresa que presta el servicio (JF Innova)
  final String titulo; // "Análisis Seguro de Trabajo (AST)"
  final String fecha; // Fecha formateada (dd/MM/yyyy HH:mm)
  final String? correlativo; // Ej. AST-2025-0001

  // --- Datos del informe (tabla superior) ---
  final List<AstHeaderField> datos;

  // --- Cuerpo ---
  final String descripcionActividad;
  final List<AstHallazgoDto> hallazgos;
  final String observaciones;

  // --- Anexo fotográfico (galería general) ---
  final List<String> fotosPaths;

  const AstReportData({
    this.empresaProveedor = 'JF INNOVA',
    this.titulo = 'Análisis Seguro de Trabajo (AST)',
    required this.fecha,
    this.correlativo,
    this.datos = const [],
    this.descripcionActividad = '',
    this.hallazgos = const [],
    this.observaciones = '',
    this.fotosPaths = const [],
  });
}

class AstHeaderField {
  final String label;
  final String valor;
  const AstHeaderField({required this.label, required this.valor});
}

class AstHallazgoDto {
  final int numero;
  final String titulo;
  final String detalle;
  final String? fotoPath;

  const AstHallazgoDto({
    required this.numero,
    required this.titulo,
    required this.detalle,
    this.fotoPath,
  });
}
