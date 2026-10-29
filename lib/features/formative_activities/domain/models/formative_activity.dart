class FormativeActivity {
  final String id;
  final String usuarioId;
  final String empresaId;
  final String? centroId;
  final String? centroNombre;
  final String? areaId;
  final String? areaNombre;
  final String? areaOtro;
  final String tipoActividad;
  final String? tipoOtro;
  final String? descripcion;
  final DateTime fecha;
  final String horaInicio;
  final String horaTermino;
  final int asistentes;
  final String relatorNombre;
  final String? correlativo;
  final String estadoFinal;

  const FormativeActivity({
    required this.id,
    required this.usuarioId,
    required this.empresaId,
    required this.tipoActividad,
    required this.fecha,
    required this.horaInicio,
    required this.horaTermino,
    required this.asistentes,
    required this.relatorNombre,
    this.centroId,
    this.centroNombre,
    this.areaId,
    this.areaNombre,
    this.areaOtro,
    this.tipoOtro,
    this.descripcion,
    this.correlativo,
    this.estadoFinal = 'En Progreso',
  });

  static int? durationMinutes(String start, String end) {
    final startMinutes = _minuteOfDay(start);
    final endMinutes = _minuteOfDay(end);
    if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
      return null;
    }
    return endMinutes - startMinutes;
  }

  static int accountedDurationMinutes(int duration) {
    if (duration <= 0) return 0;
    return ((duration + 14) ~/ 15) * 15;
  }

  static double hoursWithoutRelator(int attendees, int durationMinutes) =>
      attendees * durationMinutes / 60;

  static double hoursWithRelator(int attendees, int durationMinutes) =>
      (attendees + 1) * durationMinutes / 60;

  static int? _minuteOfDay(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }
}
