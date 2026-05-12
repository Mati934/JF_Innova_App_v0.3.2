import 'draft_card_data.dart';

/// Convierte los `Map<String, dynamic>` que entregan los repositorios locales
/// (`actividades_pendientes`, `visitas_tecnicas_pendientes`, extintores) en
/// objetos [DraftCardData] listos para renderizar.
///
/// Centraliza:
/// - Mapeo de identificadores técnicos (`VISITA_R005`, `INSPECCION_BUCEO`,
///   etc.) a etiquetas humanas.
/// - Detección del [DraftKind] correspondiente.
/// - Parseo defensivo de fechas.
class DraftCardMapper {
  const DraftCardMapper._();

  /// Inspecciones (Buceo / Embarcación / Bitácora) — provienen de
  /// `actividades_pendientes` con JOIN a `centros`.
  static DraftCardData fromInspeccion(Map<String, dynamic> raw) {
    final tipo = (raw['tipo_actividad'] ?? '').toString();
    final kind = _kindFromInspeccion(tipo);
    return DraftCardData(
      id: raw['id'].toString(),
      kind: kind,
      title: _titleForKind(kind, fallback: tipo),
      centro: _firstNonEmpty([raw['nombre_centro']]),
      fecha: _parseFecha(raw['fecha_realizacion']),
      numeroReporte: _firstNonEmpty([raw['numero_reporte']]),
      raw: raw,
    );
  }

  /// Visitas Técnicas (incluye R003 visita estándar y checklists R005/R006).
  /// Provienen de `visitas_tecnicas_pendientes`.
  static DraftCardData fromVisita(Map<String, dynamic> raw) {
    final tipo = (raw['tipo_actividad'] ?? '').toString();
    final kind = _kindFromVisita(tipo);
    return DraftCardData(
      id: raw['id'].toString(),
      kind: kind,
      title: _titleForKind(kind, fallback: 'Visita Técnica'),
      centro: _firstNonEmpty([raw['lugar_visita'], raw['nombre_centro']]),
      fecha: _parseFecha(raw['fecha_realizacion']),
      region: _firstNonEmpty([raw['region']]),
      empresa: _firstNonEmpty([raw['empresa']]),
      horaRango: _formatRangoHoras(raw['hora_inicio'], raw['hora_termino']),
      raw: raw,
    );
  }

  /// Inspecciones de Extintores (visitas con `tipo_actividad = VISITA_R004`).
  static DraftCardData fromExtintor(Map<String, dynamic> raw) {
    return DraftCardData(
      id: raw['id'].toString(),
      kind: DraftKind.inspeccionExtintores,
      title: _titleForKind(DraftKind.inspeccionExtintores),
      centro: _firstNonEmpty([raw['lugar_visita'], raw['nombre_centro']]),
      fecha: _parseFecha(raw['fecha_realizacion']),
      region: _firstNonEmpty([raw['region']]),
      empresa: _firstNonEmpty([raw['empresa']]),
      horaRango: _formatRangoHoras(raw['hora_inicio'], raw['hora_termino']),
      raw: raw,
    );
  }

  /// Servicio de Mantención de Extintores PROSESSO.
  static DraftCardData fromProsesso(Map<String, dynamic> raw) {
    return DraftCardData(
      id: raw['id'].toString(),
      kind: DraftKind.mantencionProsesso,
      title: _titleForKind(DraftKind.mantencionProsesso),
      centro: _firstNonEmpty([
        raw['cliente_nombre'],
        raw['lugar_visita'],
        raw['nombre_centro'],
      ]),
      fecha: _parseFecha(raw['fecha_servicio'] ?? raw['fecha_realizacion']),
      empresa: _firstNonEmpty([raw['empresa']]),
      raw: raw,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  static DraftKind _kindFromInspeccion(String tipo) {
    final t = tipo.toUpperCase();
    if (t == 'INSPECCION_BUCEO') return DraftKind.inspeccionBuceo;
    if (t == 'INSPECCION_EMBARCACION') return DraftKind.inspeccionEmbarcacion;
    if (t == 'BITACORA' || t.startsWith('BITACORA_')) return DraftKind.bitacora;
    return DraftKind.desconocido;
  }

  static DraftKind _kindFromVisita(String tipo) {
    final t = tipo.toUpperCase();
    if (t == 'MANTENCION_PROSESSO') return DraftKind.mantencionProsesso;
    if (t.contains('R005') || t.contains('ELECTRIC')) {
      return DraftKind.visitaChecklistElectricidad;
    }
    if (t.contains('R006') || t.contains('PISOS')) {
      return DraftKind.visitaChecklistPisos;
    }
    if (t == 'VISITA_R003' || t == 'VISITA TÉCNICA' || t == 'VISITA TECNICA') {
      return DraftKind.visitaTecnica;
    }
    if (t.startsWith('VISITA_')) return DraftKind.visitaChecklistOtro;
    return DraftKind.visitaTecnica;
  }

  static String _titleForKind(DraftKind kind, {String? fallback}) {
    switch (kind) {
      case DraftKind.inspeccionBuceo:
        return 'Inspección de Buceo';
      case DraftKind.inspeccionEmbarcacion:
        return 'Inspección de Embarcación';
      case DraftKind.bitacora:
        return 'Bitácora';
      case DraftKind.visitaTecnica:
        return 'Visita Técnica';
      case DraftKind.visitaChecklistElectricidad:
        return 'Insp. Condiciones Eléctricas';
      case DraftKind.visitaChecklistPisos:
        return 'Insp. Pisos y Superficies';
      case DraftKind.visitaChecklistOtro:
        return 'Checklist de Visita';
      case DraftKind.inspeccionExtintores:
        return 'Inspección Extintores';
      case DraftKind.mantencionProsesso:
        return 'Mantención de Extintores';
      case DraftKind.desconocido:
        return fallback?.isNotEmpty == true ? fallback! : 'Borrador';
    }
  }

  static DateTime _parseFecha(Object? value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  static String? _firstNonEmpty(List<Object?> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static String? _formatRangoHoras(Object? inicio, Object? termino) {
    final i = inicio?.toString().trim();
    final t = termino?.toString().trim();
    final iOk = i != null && i.isNotEmpty;
    final tOk = t != null && t.isNotEmpty;
    if (iOk && tOk) return '$i – $t';
    if (iOk) return 'Inicio $i';
    if (tOk) return 'Hasta $t';
    return null;
  }

  /// Devuelve una representación corta de cuánto tiempo pasó desde [fecha].
  static String tiempoRelativo(DateTime fecha, {DateTime? ahora}) {
    final now = ahora ?? DateTime.now();
    final diff = now.difference(fecha);
    if (diff.isNegative) return 'recién';
    if (diff.inMinutes < 1) return 'recién';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    if (diff.inDays < 30) return 'hace ${(diff.inDays / 7).floor()} sem';
    if (diff.inDays < 365) return 'hace ${(diff.inDays / 30).floor()} mes';
    return 'hace ${(diff.inDays / 365).floor()} a';
  }
}
