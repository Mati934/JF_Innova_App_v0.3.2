import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/user_session.dart';
import '../data/repositories/local_registro_inmersion_repository.dart';
import '../domain/models/registro_inmersion_models.dart';

/// Aviso "¿Quieres hacer el registro de inmersiones ahora?" al finalizar una
/// inspección de buceo. Funciona offline: solo lee SQLite.
class RegistroInmersionAviso {
  const RegistroInmersionAviso._();

  /// True si la empresa activa tiene el módulo, es inspección de buceo y aún
  /// no tiene registro. Cualquier error → false (el aviso nunca bloquea).
  static Future<bool> debeOfrecer({
    required String actividadId,
    required String tipoActividad,
  }) async {
    try {
      if (tipoActividad != 'INSPECCION_BUCEO') return false;
      final empresaId = UserSession().empresaId;
      if (empresaId == null) return false;
      final modulos = await DatabaseHelper.instance.getModulosHabilitados(
        empresaId,
      );
      final habilitado = modulos.any(
        (m) =>
            m['modulo_key'] == kRegistroInmersionesModuleKey &&
            m['habilitado'] == 1,
      );
      if (!habilitado) return false;
      final vigente = await LocalRegistroInmersionRepository()
          .getRegistroVigentePorActividad(actividadId);
      return vigente == null;
    } catch (e) {
      debugPrint('⚠️ No se pudo evaluar el aviso de inmersiones: $e');
      return false;
    }
  }

  /// Muestra el aviso. True = el auditor quiere hacerlo ahora.
  static const _avisoSueltos =
      '\n\nTienes un registro sin inspección en borrador: si es de este '
      'buceo, elige "Más tarde" y vincúlalo desde ese borrador.';

  static Future<bool> preguntar(BuildContext context) async {
    // Si ya empezó un registro sin inspección, que lo vincule en vez de
    // crear otro del mismo buceo.
    var haySueltos = false;
    try {
      final sueltos = await LocalRegistroInmersionRepository()
          .getRegistrosSinInspeccion(UserSession().userId ?? '');
      haySueltos = sueltos.any(
        (r) => r['registro_estado'] == RegistroInmersionEstado.borrador,
      );
    } catch (_) {}
    if (!context.mounted) return false;
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.scuba_diving),
        title: const Text('Registro de inmersiones'),
        content: Text(
          '¿Quieres hacer el registro de inmersiones ahora?\n\n'
          'Si eliges "Más tarde", lo encuentras en la tarjeta '
          '"Registro de inmersiones" de Inicio.'
          '${haySueltos ? _avisoSueltos : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Más tarde'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, ahora'),
          ),
        ],
      ),
    );
    return r == true;
  }
}
