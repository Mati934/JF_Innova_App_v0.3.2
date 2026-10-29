import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class EmailConfigService {
  Future<bool> seedCaseBase({bool force = false}) async {
    final db = await DatabaseHelper.instance.database;

    if (!force) {
      final totalRows = await db.rawQuery('''
        SELECT
          (SELECT COUNT(*) FROM correo_plantillas) +
          (SELECT COUNT(*) FROM correo_listas) +
          (SELECT COUNT(*) FROM correo_lista_destinatarios) +
          (SELECT COUNT(*) FROM correo_configuracion) AS total
      ''');
      final total = (totalRows.first['total'] as int?) ?? 0;
      if (total > 0) {
        return false;
      }
    }

    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('correo_plantillas', {
        'id': 'tpl_hidroser_demo',
        'nombre': 'Lista de verificación grúa horquilla',
        'asunto_template':
            'Lista de verificación de grúa horquilla patio fiordo austra - {{fecha_inspeccion}}',
        'cuerpo_template':
            '''Buenos días / buenas tardes,\n\nSe adjunta la lista de verificación correspondiente al registro realizado el día {{fecha_inspeccion}} a las {{hora_inspeccion}}.\nRealizado por: {{supervisor_nombre}}\n\nSaludos cordiales,\n{{supervisor_nombre}}''',
        'modulo': 'hidroser',
        'empresa_id': null,
        'variables_permitidas':
            'fecha_inspeccion,hora_inspeccion,supervisor_nombre',
        'activo': 1,
        'version': 1,
        'created_at': now,
        'updated_at': now,
        'updated_by': 'seed',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await txn.insert('correo_listas', {
        'id': 'list_demo_hidroser',
        'nombre': 'Prueba Hidroser',
        'proposito': 'Destinatarios de prueba',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await txn.insert('correo_lista_destinatarios', {
        'id': 'dest_demo_1',
        'lista_id': 'list_demo_hidroser',
        'nombre': 'Matias',
        'correo': 'matipro934@gmail.com',
        'tipo_sugerido': 'to',
        'activo': 1,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await txn.insert('correo_configuracion', {
        'id': 'cfg_demo_hidroser',
        'empresa_id': null,
        'modulo': 'hidroser',
        'plantilla_id': 'tpl_hidroser_demo',
        'lista_id': 'list_demo_hidroser',
        'prioridad': 0,
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });

    return true;
  }
}
