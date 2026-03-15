import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/tickets/data/repositories/ticket_repository.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_categoria_model.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';

class LocalTicketRepository implements TicketRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  @override
  Future<List<TicketCategoriaModel>> getCategoriasLocales() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'ticket_categorias',
        where: 'activo = ?',
        whereArgs: [1],
        orderBy: 'nombre',
      );
      // SQLite almacena bool como int (0/1). Se convierte antes de parsear.
      // Map<String, dynamic>.from() resuelve el mismatch de tipo con db.query().
      return rows.map((row) {
        final map = Map<String, dynamic>.from(row);
        map['activo'] = map['activo'] == 1;
        return TicketCategoriaModel.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('❌ [LocalTicketRepo] Error al leer categorías: $e');
      return [];
    }
  }

  @override
  Future<List<TicketModel>> getTicketsLocales() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'tickets_pendientes',
        where: 'eliminado = ?',
        whereArgs: [0],
        // Quitamos el orderBy problemático
      );

      // Mapeo seguro casteando los tipos
      return rows
          .map((row) => TicketModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('❌ [LocalTicketRepo] Error al leer tickets: $e');
      return [];
    }
  }

  @override
  Future<void> saveTicketLocal(TicketModel ticket) async {
    try {
      final db = await _db;
      final map = ticket.toMap()
        ..['subido'] = 0
        ..['eliminado'] = 0;

      await db.insert(
        'tickets_pendientes',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint(
        '✅ [LocalTicketRepo] Ticket ${ticket.id} guardado localmente.',
      );
    } catch (e) {
      debugPrint('❌ [LocalTicketRepo] Error al guardar ticket: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateTicketLocal(TicketModel ticket) async {
    try {
      final db = await _db;
      final map = ticket.toMap()..['subido'] = 0; // Forzar re-sync
      await db.update(
        'tickets_pendientes',
        map,
        where: 'id = ?',
        whereArgs: [ticket.id],
      );
      debugPrint(
        '✅ [LocalTicketRepo] Ticket ${ticket.id} actualizado localmente.',
      );
    } catch (e) {
      debugPrint('❌ [LocalTicketRepo] Error al actualizar ticket: $e');
      rethrow;
    }
  }

  @override
  Future<void> softDeleteTicket(String id) async {
    try {
      final db = await _db;
      await db.update(
        'tickets_pendientes',
        {'eliminado': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('✅ [LocalTicketRepo] Ticket $id marcado como eliminado.');
    } catch (e) {
      debugPrint('❌ [LocalTicketRepo] Error al eliminar ticket: $e');
      rethrow;
    }
  }

  @override
  Future<void> syncTicketsHaciaSupabase() {
    throw UnimplementedError(
      'La sincronización la gestiona SupabaseTicketRepository.',
    );
  }

  @override
  Future<int> getCantidadTicketsAbiertos() async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM tickets_pendientes "
        "WHERE estado = 'Abierto' AND eliminado = 0",
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('❌ [LocalTicketRepo] Error al contar tickets abiertos: $e');
      return 0;
    }
  }
}
