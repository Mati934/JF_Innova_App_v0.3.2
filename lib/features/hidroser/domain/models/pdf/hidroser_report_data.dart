import 'dart:typed_data';

/// Datos planos y serializables que se envían al isolate para generar el PDF
/// de cualquier lista Hidroser. Está diseñado para ser ADAPTABLE: el contenido
/// del encabezado se construye dinámicamente con [headerFields] y los bloques
/// de firma son opcionales.
class HidroserReportData {
  // --- Marca / encabezado ---
  final String empresaProveedor;
  final String
  tituloLista; // Nombre de la lista (ej. "Lista de verificación de Grúa Horquilla")
  final String? subtitulo; // Ej. "Patio Fiordo Austral"
  final String fecha; // Fecha formateada (ej. dd/MM/yyyy)
  final String? correlativo; // Ej. HIDROSER-GH-2025-0001

  // --- Datos del profesional que aplica la lista ---
  final String profesional;
  final String fonoProfesional;
  final String correoProfesional;

  // --- Encabezado dinámico: campos extra (conductor, número de grúa, etc.) ---
  final List<HidroserHeaderField> headerFields;

  // --- Cuerpo del checklist ---
  final List<HidroserChecklistItemDto> checklistItems;
  final String observaciones;

  // --- Firmas (0, 1 o 2). Adaptable según la lista ---
  final List<HidroserFirmaDto> firmas;

  // --- Anexo fotográfico ---
  final List<String> fotosPaths;

  const HidroserReportData({
    this.empresaProveedor = 'JF INNOVA',
    required this.tituloLista,
    this.subtitulo,
    required this.fecha,
    this.correlativo,
    this.profesional = '',
    this.fonoProfesional = '',
    this.correoProfesional = '',
    this.headerFields = const [],
    this.checklistItems = const [],
    this.observaciones = '',
    this.firmas = const [],
    this.fotosPaths = const [],
  });
}

class HidroserHeaderField {
  final String label;
  final String valor;
  const HidroserHeaderField({required this.label, required this.valor});
}

class HidroserChecklistItemDto {
  final String categoria;
  final String pregunta;
  final String respuesta; // 'C' | 'NC' | 'NA'
  final String? criticidad;
  final String? observacion;
  final String? fotoPath;

  const HidroserChecklistItemDto({
    required this.categoria,
    required this.pregunta,
    required this.respuesta,
    this.criticidad,
    this.observacion,
    this.fotoPath,
  });
}

class HidroserFirmaDto {
  final String rol; // Ej. "Supervisor de turno", "Operador de grúa"
  final String? nombre;
  final Uint8List? imagen;

  const HidroserFirmaDto({required this.rol, this.nombre, this.imagen});
}
