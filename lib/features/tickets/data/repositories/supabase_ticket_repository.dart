import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/tickets/data/repositories/ticket_repository.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_categoria_model.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';

class SupabaseTicketRepository implements TicketRepository {
  final _client = Supabase.instance.client;
  Future<Database> get _db => DatabaseHelper.instance.database;

  @override
  Future<List<TicketCategoriaModel>> getCategoriasLocales() {
    throw UnimplementedError(
      'Use LocalTicketRepository para operaciones locales.',
    );
  }

  @override
  Future<List<TicketModel>> getTicketsLocales() {
    throw UnimplementedError(
      'Use LocalTicketRepository para operaciones locales.',
    );
  }

  @override
  Future<void> saveTicketLocal(TicketModel ticket) {
    throw UnimplementedError(
      'Use LocalTicketRepository para operaciones locales.',
    );
  }

  @override
  Future<void> updateTicketLocal(TicketModel ticket) {
    throw UnimplementedError(
      'Use LocalTicketRepository para operaciones locales.',
    );
  }

  @override
  Future<void> softDeleteTicket(String id) {
    throw UnimplementedError(
      'Use LocalTicketRepository para operaciones locales.',
    );
  }

  @override
  Future<int> getCantidadTicketsAbiertos() {
    throw UnimplementedError(
      'Use LocalTicketRepository para operaciones locales.',
    );
  }

  /// Elimina un ticket de Supabase por su ID.
  Future<void> deleteRemoteTicket(String id) async {
    try {
      await _client.from('tickets').delete().eq('id', id);
      debugPrint('✅ [SupabaseTicketRepo] Ticket $id eliminado de Supabase.');
    } catch (e) {
      debugPrint(
        '❌ [SupabaseTicketRepo] Error al eliminar ticket $id de Supabase: $e',
      );
      rethrow;
    }
  }

  /// Descarga tickets abiertos y en proceso desde Supabase a SQLite local.
  /// Los cerrados/resueltos se omiten. No sobreescribe tickets locales pendientes
  /// de subir (subido = 0).
  Future<void> descargarTicketsDesdeSupabase() async {
    try {
      final response = await _client.from('tickets').select().inFilter(
        'estado',
        ['Abierto', 'En Proceso', 'En Progreso'],
      );

      if (response.isEmpty) {
        debugPrint(
          'ℹ️ [SupabaseTicketRepo] No hay tickets abiertos/en proceso en Supabase.',
        );
        return;
      }

      final db = await _db;
      final items = List<Map<String, dynamic>>.from(response);
      int descargados = 0;

      for (final row in items) {
        final ticketId = row['id'] as String;

        // No sobreescribir tickets locales con cambios pendientes de subir
        final existing = await db.query(
          'tickets_pendientes',
          columns: ['subido'],
          where: 'id = ?',
          whereArgs: [ticketId],
        );
        if (existing.isNotEmpty && existing.first['subido'] == 0) continue;

        final map = <String, dynamic>{
          'id': ticketId,
          'codigo_ticket': row['codigo_ticket'],
          'empresa_id': row['empresa_id'],
          'area_id': row['area_id'],
          'centro_id': row['centro_id'],
          'embarcacion_id': row['embarcacion_id'],
          'actividad_id': row['actividad_id'],
          'categoria_id': row['categoria_id'],
          'categoria_otro': row['categoria_otro'],
          'descripcion': row['descripcion'],
          'solicitante_id': row['solicitante_id'],
          'responsable_id': row['responsable_id'],
          'estado': row['estado'],
          'criticidad': row['criticidad'],
          'fecha_tentativa_cierre': row['fecha_tentativa_cierre'],
          'created_at': row['created_at'],
          'subido': 1,
          'eliminado': 0,
        };

        await db.insert(
          'tickets_pendientes',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        descargados++;
      }

      debugPrint(
        '✅ [SupabaseTicketRepo] $descargados ticket(s) descargados desde Supabase.',
      );
    } catch (e) {
      debugPrint('❌ [SupabaseTicketRepo] Error descargando tickets: $e');
    }
  }

  /// Lee los tickets pendientes de SQLite (subido = 0), los envía a Supabase
  /// uno a uno y, si el insert es exitoso, marca subido = 1 en SQLite.
  @override
  Future<void> syncTicketsHaciaSupabase() async {
    try {
      final db = await _db;
      final pendientes = await db.query(
        'tickets_pendientes',
        where: 'subido = ? AND eliminado = ?',
        whereArgs: [0, 0],
      );

      if (pendientes.isEmpty) {
        debugPrint(
          'ℹ️ [SupabaseTicketRepo] No hay tickets pendientes de sincronización.',
        );
        return;
      }

      debugPrint(
        '🔄 [SupabaseTicketRepo] Sincronizando ${pendientes.length} ticket(s)...',
      );

      for (final row in pendientes) {
        final ticketId = row['id'] as String;
        try {
          final ticket = TicketModel.fromMap(row);
          // toMap() ya excluye codigoTicket, createdAt y updatedAt.
          await _client.from('tickets').upsert(ticket.toMap());

          // Leemos de vuelta el codigo_ticket generado por Supabase.
          final fetched = await _client
              .from('tickets')
              .select('codigo_ticket')
              .eq('id', ticketId)
              .maybeSingle();
          final codigoTicket = fetched?['codigo_ticket'] as String?;

          await db.update(
            'tickets_pendientes',
            {
              'subido': 1,
              if (codigoTicket != null) 'codigo_ticket': codigoTicket,
            },
            where: 'id = ?',
            whereArgs: [ticketId],
          );
          debugPrint(
            '✅ [SupabaseTicketRepo] Ticket $ticketId sincronizado'
            '${codigoTicket != null ? " ($codigoTicket)" : ""}.',
          );
        } catch (e) {
          // Un fallo individual no detiene el resto de la cola.
          debugPrint(
            '❌ [SupabaseTicketRepo] Error al sincronizar ticket $ticketId: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [SupabaseTicketRepo] Error general en sincronización: $e');
      rethrow;
    }
  }
}
