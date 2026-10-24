class ParticipanteModel {
  final String personalId;
  final String nombreCompleto;
  final String rut;
  final String cargo; // S.B.M, B.M.B, etc.
  final String matricula; // <--- NUEVO CAMPO
  final String? contratistaId; // <--- ID de la empresa contratista del buzo
  bool condicionesOptimas;

  ParticipanteModel({
    required this.personalId,
    required this.nombreCompleto,
    required this.rut,
    required this.cargo,
    this.matricula = '', // <--- Por defecto vacío para no romper nada
    this.contratistaId, // <--- Opcional, puede ser null
    this.condicionesOptimas = true,
  });

  // Factory simple para cuando lees de la DB uniendo tablas
  factory ParticipanteModel.fromMap(Map<String, dynamic> map) {
    return ParticipanteModel(
      personalId: map['personal_id'],
      nombreCompleto:
          map['nombre_completo'] ?? '', // Viene del JOIN con personal_externo
      rut: map['rut'] ?? '',
      cargo: map['rol_en_faena'] ?? 'Buzo',
      matricula: map['matricula'] ?? '',
      contratistaId: map['contratista_id'], // <--- LEER DE DB
      condicionesOptimas: map['condiciones_optimas'] == 1,
    );
  }
}
