import '../../../../core/database/database_helper.dart';
import '../../../../core/modules/module_registry.dart';
import '../../../../core/services/user_session.dart';

/// Helper simple para saber si la empresa activa tiene el módulo de Tickets
/// habilitado (misma fuente que [ModuleRegistry]/`empresa_modulos`, sin
/// duplicar la lógica completa de `HomeController`).
Future<bool> isTicketsModuleEnabled() async {
  final empresaId = UserSession().empresaId;
  if (empresaId == null) return false;
  final rows = await DatabaseHelper.instance.getModulosHabilitados(empresaId);
  if (rows.isEmpty) {
    return ModuleRegistry.defaultModuleKeys.contains('TICKETS');
  }
  return rows.any(
    (r) => r['modulo_key'] == 'TICKETS' && (r['habilitado'] as int) == 1,
  );
}
