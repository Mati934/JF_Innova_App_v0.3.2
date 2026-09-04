import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/models/configurable_checklist.dart';

class LocalConfigurableChecklistRepository {
  final DatabaseHelper _db;

  LocalConfigurableChecklistRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  Future<List<ChecklistFormType>> getActiveFormTypes() async {
    final rows = await _db.database.then(
      (db) => db.query(
        'checklist_form_types',
        where: 'activo = 1',
        orderBy: 'form_type_key ASC',
      ),
    );
    return rows.map(ChecklistFormType.fromMap).toList();
  }

  Future<List<ConfigurableChecklist>> getActiveChecklists() async {
    final rows = await _db.database.then(
      (db) =>
          db.query('checklists', where: 'activo = 1', orderBy: 'nombre ASC'),
    );
    return rows.map(ConfigurableChecklist.fromMap).toList();
  }

  Future<ConfigurableChecklist?> getChecklist(String checklistKey) async {
    final rows = await (await _db.database).query(
      'checklists',
      where: 'checklist_key = ?',
      whereArgs: [checklistKey],
      limit: 1,
    );
    return rows.isEmpty ? null : ConfigurableChecklist.fromMap(rows.first);
  }

  Future<ChecklistVersion?> getPublishedVersion(String checklistKey) async {
    final rows = await (await _db.database).query(
      'checklist_versions',
      where: 'checklist_key = ? AND estado = ?',
      whereArgs: [checklistKey, 'PUBLICADA'],
      orderBy: 'version DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ChecklistVersion.fromMap(rows.first);
  }

  Future<List<ChecklistNavigationNode>> getNavigationNodes(
    String empresaId,
  ) async {
    final rows = await (await _db.database).query(
      'checklist_navigation_nodes',
      where: 'empresa_id = ? AND habilitado = 1',
      whereArgs: [empresaId],
      orderBy: 'orden ASC, titulo ASC',
    );
    return rows.map(ChecklistNavigationNode.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getItemsForChecklist(
    String checklistKey,
  ) async {
    final version = await getPublishedVersion(checklistKey);
    return version?.preguntas ?? const [];
  }

  Future<void> saveDraft({
    required Map<String, dynamic> inspection,
    required List<Map<String, dynamic>> responses,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'checklist_inspecciones_pendientes',
        inspection,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'checklist_respuestas_pendientes',
        where: 'inspeccion_id = ?',
        whereArgs: [inspection['id']],
      );
      for (final response in responses) {
        await txn.insert(
          'checklist_respuestas_pendientes',
          response,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteDraft(String inspectionId) async {
    final db = await _db.database;
    await db.update(
      'checklist_inspecciones_pendientes',
      {'eliminado': 1, 'subido': 0},
      where: 'id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<List<Map<String, dynamic>>> getDrafts() async {
    final db = await _db.database;
    return db.query(
      'checklist_inspecciones_pendientes',
      where: 'eliminado = 0 AND estado_final = ?',
      whereArgs: ['Borrador'],
      orderBy: 'created_at DESC',
    );
  }
}
