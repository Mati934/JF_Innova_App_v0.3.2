import 'dart:typed_data';

/// Datos planos y serializables para generar el PDF de un checklist
/// configurable (herramientas y equipos: esmeril, soldadora, taladro,
/// extensión eléctrica, herramientas manuales, y cualquier otro que se
/// siembre a futuro con el mismo `form_type_key = generic_standard_form`).
///
/// El diseño replica el formato de referencia entregado por el cliente
/// (encabezado "Datos generales", checklist numerado, apuntes/observaciones,
/// fotos generales y firma, con footer "Generado por Servimaf").
class ChecklistReportData {
  final String empresaNombre;
  final String tituloChecklist;
  final String fecha;
  final String? correlativo;

  /// Pares label/valor de "Datos generales" (Supervisor a cargo, Obra o
  /// faena, Región, etc.), en el orden en que deben imprimirse.
  final List<ChecklistHeaderField> datosGenerales;

  final List<ChecklistPdfItemDto> checklistItems;
  final String apuntesObservaciones;
  final List<String> fotosGeneralesPaths;

  final String? firmaNombre;
  final Uint8List? firmaImagen;

  const ChecklistReportData({
    this.empresaNombre = 'JF INNOVA',
    required this.tituloChecklist,
    required this.fecha,
    this.correlativo,
    this.datosGenerales = const [],
    this.checklistItems = const [],
    this.apuntesObservaciones = '',
    this.fotosGeneralesPaths = const [],
    this.firmaNombre,
    this.firmaImagen,
  });
}

class ChecklistHeaderField {
  final String label;
  final String valor;
  const ChecklistHeaderField({required this.label, required this.valor});
}

class ChecklistPdfItemDto {
  final int numero;
  final String descripcion;
  final String? categoria;
  final String? respuesta;
  final String? observacion;
  final String? fotoPath;

  const ChecklistPdfItemDto({
    required this.numero,
    required this.descripcion,
    this.categoria,
    this.respuesta,
    this.observacion,
    this.fotoPath,
  });
}
