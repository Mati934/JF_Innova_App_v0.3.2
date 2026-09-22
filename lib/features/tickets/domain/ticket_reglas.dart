import '../../inspection/domain/models/mandatory_buceo_photo_slot.dart';
import 'models/ticket_item_model.dart';
import 'models/ticket_model.dart';

/// Reglas de negocio puras del ciclo de vida de un ticket, separadas del
/// controlador para poder testearlas sin depender de Supabase/UserSession.
class TicketReglas {
  TicketReglas._();

  /// true si [usuarioId] puede finalizar (enviar a revisión del admin) el
  /// ticket que tiene tomado.
  ///
  /// Cubre dos casos:
  /// - Ticket con ítems: todos deben estar subsanados.
  /// - Ticket sin ítems (típico de un ticket de tipo SOLICITUD, que no tiene
  ///   observaciones que subsanar): se puede finalizar directamente, ya que
  ///   de lo contrario nunca podría salir del estado TOMADO (bug corregido:
  ///   antes solo se finalizaba automáticamente al marcar el último ítem
  ///   subsanado, lo que dejaba a los tickets sin ítems sin forma de
  ///   cerrarse).
  static bool puedeFinalizar({
    required TicketModel? ticket,
    required List<TicketItemModel> items,
    required String? usuarioId,
  }) {
    if (ticket == null || usuarioId == null) return false;
    if (ticket.estado != TicketEstado.tomado) return false;
    if (ticket.tomadoPorId != usuarioId) return false;
    return items.isEmpty || items.every((i) => i.subsanado);
  }

  /// true si [usuarioId] puede eliminar (borrado lógico) el ticket: el propio
  /// autor del ticket, o cualquier usuario admin.
  static bool puedeEliminar({
    required TicketModel? ticket,
    required String? usuarioId,
    required bool esAdmin,
  }) {
    if (ticket == null || usuarioId == null) return false;
    return esAdmin || ticket.generadoPorId == usuarioId;
  }

  /// true si se debe pedir confirmación explícita antes de generar un ticket
  /// automático porque la inspección no tiene ninguna respuesta "No Cumple"
  /// (100% de cumplimiento). El usuario igual puede continuar si hay fotos
  /// con observación que ameriten seguimiento.
  static bool debeConfirmarGeneracionSinNoCumple({
    required int cantidadNoCumple,
  }) {
    return cantidadNoCumple == 0;
  }

  /// Descripción `Item <uuid>` con que la app guarda las fotos asociadas a una
  /// pregunta del checklist. Si la foto se subió sin poder enlazar su
  /// `inspeccion_respuesta_id`, queda suelta con ese texto de placeholder.
  static final RegExp _placeholderFotoDePregunta = RegExp(
    r'^item\s+[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// Descripciones que escribe la app (no el inspector) al subir fotos que no
  /// son observaciones: galería general, anexo de visitas y foto anexa sin
  /// texto.
  static const Set<String> _placeholdersFotoSinObservacion = {
    'general', // galería general de la app vieja (bug 2026-07-07)
    'fotografía anexa',
    'fotografia anexa',
    'anexo fotográfico de visita técnica',
  };

  /// true si una foto suelta (sin respuesta de formulario asociada) tiene una
  /// observación real escrita por el inspector.
  ///
  /// Descarta todo lo que es evidencia del formulario o placeholder de la app:
  /// sin este filtro se generan `ticket_items` basura (verificaciones críticas
  /// del estado de la faena, registros fotográficos complementarios, fotos de
  /// pregunta huérfanas y fotos anexas sin texto).
  ///
  /// `registro_fotografico` no guarda el item_id, así que la única señal
  /// disponible es la descripción con que las sube el sync.
  static bool esObservacionFotoReal(String? descripcion) {
    final lower = (descripcion?.trim() ?? '').toLowerCase();
    if (lower.isEmpty) return false;
    if (_placeholdersFotoSinObservacion.contains(lower)) return false;
    if (lower.startsWith('verificación:') ||
        lower.startsWith('verificacion:')) {
      return false;
    }
    if (_placeholderFotoDePregunta.hasMatch(lower)) return false;
    if (mandatoryBuceoPhotoSlots.any((s) => s.title.toLowerCase() == lower)) {
      return false;
    }
    return true;
  }
}
