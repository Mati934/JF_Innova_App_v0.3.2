/// Definición de un campo extra propio de un checklist.
/// Vive en la tabla maestra `formulario_campos_extra` (Supabase + SQLite).
class CampoExtraDef {
  final String tipoActividad;
  final String clave;
  final String label;
  final String tipo; // 'texto' | 'numero' | 'hora' | 'email'
  final int orden;
  final bool requerido;

  const CampoExtraDef({
    required this.tipoActividad,
    required this.clave,
    required this.label,
    this.tipo = 'texto',
    this.orden = 0,
    this.requerido = false,
  });

  factory CampoExtraDef.fromMap(Map<String, dynamic> m) {
    bool toBool(dynamic v) =>
        v == true || v == 1 || v == '1' || v == 't' || v == 'true';
    return CampoExtraDef(
      tipoActividad: m['tipo_actividad']?.toString() ?? '',
      clave: m['clave']?.toString() ?? '',
      label: m['label']?.toString() ?? '',
      tipo: (m['tipo']?.toString().isNotEmpty ?? false)
          ? m['tipo'].toString()
          : 'texto',
      orden: (m['orden'] is num) ? (m['orden'] as num).toInt() : 0,
      requerido: toBool(m['requerido']),
    );
  }
}
