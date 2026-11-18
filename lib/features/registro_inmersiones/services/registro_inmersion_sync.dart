import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/user_session.dart';
import '../data/repositories/local_registro_inmersion_repository.dart';
import '../domain/models/registro_inmersion_models.dart';
import '../domain/models/registro_inmersion_pdf_data.dart';
import 'registro_inmersion_pdf_service.dart';

/// Payload de Supabase para un buzo (SQLite guarda los booleanos como 0/1).
Map<String, dynamic> buzoPayloadSupabase(Map<String, dynamic> r) => {
  'id': r['id'],
  'registro_id': r['registro_id'],
  'personal_id': r['personal_id'],
  'nombre': r['nombre'],
  'rut': r['rut'],
  'cargo': r['cargo'],
  'realizo_inmersion': r['realizo_inmersion'] != 0,
  'profundidad_maxima_m': r['profundidad_maxima_m'],
  'excede_autorizada': r['excede_autorizada'] == 1,
  'marcado_rojo': r['marcado_rojo'] == 1,
  'tiempo_total_min': r['tiempo_total_min'],
  'cantidad_inmersiones': r['cantidad_inmersiones'] ?? 0,
  'profundimetro_marca': r['profundimetro_marca'],
  'profundimetro_serie': r['profundimetro_serie'],
  'dispositivo_tipo': r['dispositivo_tipo'],
  'dispositivo_serie': r['dispositivo_serie'],
  'nota': r['nota'],
  'orden': r['orden'] ?? 0,
};

Map<String, dynamic> inmersionPayloadSupabase(Map<String, dynamic> r) => {
  'id': r['id'],
  'buzo_id': r['buzo_id'],
  'registro_id': r['registro_id'],
  'orden': r['orden'] ?? 1,
  'profundidad_maxima_m': r['profundidad_maxima_m'],
  'excede_autorizada': r['excede_autorizada'] == 1,
  'hora_inicio': r['hora_inicio'],
  'hora_inicio_editada': r['hora_inicio_editada'] == 1,
  'hora_termino': r['hora_termino'],
  'tiempo_min': r['tiempo_min'],
};

/// Cabecera para Supabase: sin columnas solo locales ni las que pone el
/// trigger (`numero`, `correlativo`).
Map<String, dynamic> registroPayloadSupabase(Map<String, dynamic> row) =>
    Map<String, dynamic>.from(row)
      ..remove('subido')
      ..remove('eliminado')
      ..remove('pdf_path_local')
      ..remove('numero')
      ..remove('correlativo');

/// Subida del registro de inmersiones. Solo sube registros finalizados (los
/// borradores viven en el teléfono). El PDF se genera aquí, cuando ya existen
/// el N° propio (RI-NNNN) y el N° de la inspección de buceo.
class RegistroInmersionSync {
  final SupabaseClient _supabase;
  final DatabaseHelper _dbHelper;

  RegistroInmersionSync({SupabaseClient? supabase, DatabaseHelper? dbHelper})
    : _supabase = supabase ?? Supabase.instance.client,
      _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const _tRegistro = 'registros_inmersion_pendientes';
  static const _hijos = [
    'registro_inmersion_inmersiones_pendientes',
    'registro_inmersion_buzos_pendientes',
    'registro_inmersion_fotos_pendientes',
  ];

  Future<int> sincronizar() async {
    final db = await _dbHelper.database;
    final pendientes = await db.query(_tRegistro, where: 'subido = 0');
    var count = 0;
    for (final row in pendientes) {
      final id = row['id'].toString();
      try {
        if (row['eliminado'] == 1) {
          await _eliminar(db, row);
          continue;
        }
        if (row['estado_final'] != RegistroInmersionEstado.finalizado) continue;
        if (await _subir(db, row)) count++;
      } catch (e, st) {
        debugPrint('🔥 Error sincronizando registro de inmersiones $id: $e');
        try {
          await FirebaseCrashlytics.instance.recordError(
            e,
            st,
            reason: 'RegistroInmersionSync: $id',
            fatal: false,
          );
        } catch (_) {}
      }
    }
    return count;
  }

  Future<void> _eliminar(DatabaseExecutor db, Map<String, dynamic> row) async {
    final id = row['id'].toString();
    if (row['estado_final'] != RegistroInmersionEstado.borrador) {
      // Puede haber llegado a Supabase: se da de baja allá primero.
      await _supabase
          .from('registros_inmersion')
          .update({'estado_final': RegistroInmersionEstado.eliminada})
          .eq('id', id);
    }
    for (final t in _hijos) {
      await db.delete(t, where: 'registro_id = ?', whereArgs: [id]);
    }
    await db.delete(_tRegistro, where: 'id = ?', whereArgs: [id]);
  }

  /// True si quedó todo arriba (cabecera, hijos, fotos y PDF).
  Future<bool> _subir(Database db, Map<String, dynamic> row) async {
    final id = row['id'].toString();
    final payload = registroPayloadSupabase(row);
    payload['usuario_id'] ??= _supabase.auth.currentUser?.id;
    payload['empresa_id'] ??= UserSession().empresaId;

    final saved = await _supabase
        .from('registros_inmersion')
        .upsert(payload, onConflict: 'id')
        .select('numero, correlativo, estado_final')
        .maybeSingle();
    if (saved?['estado_final'] == RegistroInmersionEstado.eliminada) {
      // La inspección se eliminó en Supabase: el registro quedó de baja.
      for (final t in _hijos) {
        await db.delete(t, where: 'registro_id = ?', whereArgs: [id]);
      }
      await db.delete(_tRegistro, where: 'id = ?', whereArgs: [id]);
      return false;
    }
    final correlativo = saved?['correlativo']?.toString();
    await db.update(
      _tRegistro,
      {
        'usuario_id': payload['usuario_id'],
        'empresa_id': payload['empresa_id'],
        if (saved?['numero'] != null) 'numero': saved!['numero'],
        if (correlativo != null) 'correlativo': correlativo,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    var completo = true;
    final buzos = await db.query(
      'registro_inmersion_buzos_pendientes',
      where: 'registro_id = ?',
      whereArgs: [id],
    );
    if (buzos.isNotEmpty) {
      await _supabase
          .from('registro_inmersion_buzos')
          .upsert(buzos.map(buzoPayloadSupabase).toList(), onConflict: 'id');
    }
    final inmersiones = await db.query(
      'registro_inmersion_inmersiones_pendientes',
      where: 'registro_id = ?',
      whereArgs: [id],
    );
    if (inmersiones.isNotEmpty) {
      await _supabase
          .from('registro_inmersion_inmersiones')
          .upsert(
            inmersiones.map(inmersionPayloadSupabase).toList(),
            onConflict: 'id',
          );
    }

    final fotos = await db.query(
      'registro_inmersion_fotos_pendientes',
      where: 'registro_id = ? AND subido = 0',
      whereArgs: [id],
    );
    for (final f in fotos) {
      final fotoId = f['id'].toString();
      final local = f['local_path']?.toString();
      if (local == null || local.isEmpty || !File(local).existsSync()) {
        // La foto ya no está en el teléfono: no se puede recuperar.
        debugPrint(
          '⚠️ [RI-FOTO-001] Foto $fotoId sin archivo local, se omite.',
        );
        await db.delete(
          'registro_inmersion_fotos_pendientes',
          where: 'id = ?',
          whereArgs: [fotoId],
        );
        continue;
      }
      try {
        final storagePath = 'inmersiones/$id/$fotoId.jpg';
        await _supabase.storage
            .from('evidencias')
            .upload(
              storagePath,
              File(local),
              fileOptions: const FileOptions(upsert: true),
            );
        final url = _supabase.storage
            .from('evidencias')
            .getPublicUrl(storagePath);
        await _supabase.from('registro_inmersion_fotos').upsert({
          'id': fotoId,
          'registro_id': id,
          'buzo_id': f['buzo_id'],
          'tipo': f['tipo'],
          'posicion': f['posicion'] ?? 0,
          'storage_path': storagePath,
          'foto_url': url,
          'descripcion': f['descripcion'],
        }, onConflict: 'id');
        await db.update(
          'registro_inmersion_fotos_pendientes',
          {'subido': 1, 'storage_path': storagePath, 'foto_url': url},
          where: 'id = ?',
          whereArgs: [fotoId],
        );
      } catch (e) {
        completo = false;
        debugPrint('⚠️ [RI-FOTO-002] Error subiendo foto $fotoId: $e');
      }
    }

    var pdfUrl = row['pdf_url']?.toString();
    if (completo && (pdfUrl == null || pdfUrl.isEmpty)) {
      pdfUrl = await _generarYSubirPdf(db, id, correlativo);
      if (pdfUrl == null) completo = false;
    }

    if (completo) {
      await db.update(
        _tRegistro,
        {'subido': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return completo;
  }

  /// Genera el PDF con los dos números reales. Null si todavía falta alguno
  /// (queda para el próximo sync).
  Future<String?> _generarYSubirPdf(
    Database db,
    String id,
    String? correlativo,
  ) async {
    if ((correlativo ?? '').isEmpty) return null;
    final repo = LocalRegistroInmersionRepository(db: _dbHelper);
    final completo = await repo.getCompleto(id);
    if (completo == null) return null;
    final registro = completo.registro;

    final numeroInspeccion =
        numeroInspeccionValido(registro.numeroInspeccion) ??
        await _numeroInspeccion(db, registro.actividadId);
    if (numeroInspeccion == null) {
      debugPrint('⏳ Registro $id espera el N° de su inspección para el PDF.');
      return null;
    }
    registro
      ..numeroInspeccion = numeroInspeccion
      ..correlativo = correlativo;

    try {
      final data = buildRegistroInmersionPdfData(
        registro: registro,
        buzos: completo.buzos,
        fotos: completo.fotos,
        auditor: UserSession().nombreCompleto ?? '',
        existe: (p) => File(p).existsSync(),
      );
      final bytes = await const RegistroInmersionPdfService().generar(
        data,
        empresaId: registro.empresaId,
      );
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/registro_inmersion_$id.pdf';
      await File(path).writeAsBytes(bytes, flush: true);

      final storagePath = '$id/RegistroInmersiones_$id.pdf';
      await _supabase.storage
          .from('pdfs_visitas')
          .upload(
            storagePath,
            File(path),
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _supabase.storage
          .from('pdfs_visitas')
          .getPublicUrl(storagePath);
      await _supabase
          .from('registros_inmersion')
          .update({
            'pdf_url': url,
            'pdf_version': kRegistroInmersionPdfVersion,
            'numero_inspeccion': numeroInspeccion,
          })
          .eq('id', id);
      await db.update(
        _tRegistro,
        {
          'pdf_url': url,
          'pdf_path_local': path,
          'pdf_version': kRegistroInmersionPdfVersion,
          'numero_inspeccion': numeroInspeccion,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return url;
    } catch (e) {
      debugPrint('⚠️ [RI-PDF-001] Error generando/subiendo PDF $id: $e');
      return null;
    }
  }

  Future<String?> _numeroInspeccion(Database db, String actividadId) async {
    final local = await db.query(
      'actividades_pendientes',
      columns: ['numero_reporte'],
      where: 'id = ?',
      whereArgs: [actividadId],
      limit: 1,
    );
    final n = local.isEmpty
        ? null
        : numeroInspeccionValido(local.first['numero_reporte']);
    if (n != null) return n;
    try {
      final remoto = await _supabase
          .from('actividades')
          .select('numero_informe')
          .eq('id', actividadId)
          .maybeSingle();
      return numeroInspeccionValido(remoto?['numero_informe']);
    } catch (_) {
      return null;
    }
  }
}
