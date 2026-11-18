class EmailTemplateModel {
  final String id;
  final String nombre;
  final String asuntoTemplate;
  final String cuerpoTemplate;
  final String? modulo;
  final String? empresaId;
  final bool activo;
  final int version;

  const EmailTemplateModel({
    required this.id,
    required this.nombre,
    required this.asuntoTemplate,
    required this.cuerpoTemplate,
    this.modulo,
    this.empresaId,
    this.activo = true,
    this.version = 1,
  });

  factory EmailTemplateModel.fromMap(Map<String, dynamic> map) {
    return EmailTemplateModel(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      asuntoTemplate: map['asunto_template']?.toString() ?? '',
      cuerpoTemplate: map['cuerpo_template']?.toString() ?? '',
      modulo: map['modulo']?.toString(),
      empresaId: map['empresa_id']?.toString(),
      activo: (map['activo'] as int?) == 1 || map['activo'] == true,
      version: int.tryParse(map['version']?.toString() ?? '1') ?? 1,
    );
  }
}
