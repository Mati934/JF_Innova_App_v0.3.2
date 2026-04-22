import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/rut_utils.dart';
import '../../../core/services/user_session.dart';
import '../../../features/tickets/data/repositories/supabase_ticket_repository.dart';
import '../../../features/inspection/services/deferred_pdf_service.dart';
import 'dart:convert';

class SyncService {
  final _supabase = Supabase.instance.client;
  final _dbHelper = DatabaseHelper.instance;
  final _ticketRepo = SupabaseTicketRepository();

  // --- 1. DESCARGAR DATOS MAESTROS (Down-Sync) ---
  // Cada tabla se descarga independientemente: si una falla, las demás se guardan igual.
  Future<List<String>> descargarDatosMaestros() async {
    final empresaId = UserSession().empresaId;
    final userId = UserSession().userId;
    final tablasDescargadas = <String>[];
    final tablasFallidas = <String>[];

    // Helper: descarga una tabla de forma segura, retorna null si falla
    Future<List<Map<String, dynamic>>?> descargarTabla(
      String nombre,
      Future<List<Map<String, dynamic>>> query,
    ) async {
      try {
        final data = await query;
        return data;
      } catch (e, stack) {
        debugPrint("⚠️ Error descargando $nombre: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'descargarDatosMaestros: tabla $nombre',
          fatal: false,
        );
        tablasFallidas.add(nombre);
        return null;
      }
    }

    // Lanzar todas las descargas en paralelo (como antes, para velocidad)
    final futures = await Future.wait([
      // 0: areas (global — filtrado se hace via empresa_areas)
      descargarTabla(
        'areas',
        _supabase.from('areas').select('id, nombre, empresa_id'),
      ),
      // 1: centros
      descargarTabla(
        'centros',
        _supabase.from('centros').select('id, nombre, area_id'),
      ),
      // 2: contratistas
      descargarTabla(
        'contratistas',
        _supabase.from('contratistas').select('id, nombre, rut'),
      ),
      // 3: embarcaciones
      descargarTabla(
        'embarcaciones',
        _supabase
            .from('embarcaciones')
            .select('id, nombre, contratista_id, matricula'),
      ),
      // 4: formulario_items
      descargarTabla(
        'formulario_items',
        _supabase
            .from('formulario_items')
            .select()
            .eq('activo', true)
            .order('orden'),
      ),
      // 5: personal_externo
      descargarTabla(
        'personal_externo',
        _supabase.from('personal_externo').select(),
      ),
      // 6: empresas
      descargarTabla(
        'empresas',
        _supabase
            .from('empresas')
            .select('id, nombre, es_administradora, logo_url'),
      ),
      // 7: ticket_categorias
      descargarTabla(
        'ticket_categorias',
        _supabase
            .from('ticket_categorias')
            .select('id, nombre, activo')
            .eq('activo', true),
      ),
      // 8: usuarios
      descargarTabla(
        'usuarios',
        _supabase
            .from('usuarios')
            .select(
              'id, rut, nombre_completo, email, rol_id, telefono, empresa_id, roles (nombre)',
            ),
      ),
      // 9: empresa_modulos (condicional)
      descargarTabla(
        'empresa_modulos',
        empresaId != null
            ? _supabase
                  .from('empresa_modulos')
                  .select('id, empresa_id, modulo_key, habilitado, orden')
                  .eq('empresa_id', empresaId)
            : Future.value(<Map<String, dynamic>>[]),
      ),
      // 10: usuario_empresas (condicional)
      descargarTabla(
        'usuario_empresas',
        userId != null
            ? _supabase
                  .from('usuario_empresas')
                  .select('id, usuario_id, empresa_id')
                  .eq('usuario_id', userId)
            : Future.value(<Map<String, dynamic>>[]),
      ),
      // 11: empresa_areas (condicional — solo para empresa activa)
      descargarTabla(
        'empresa_areas',
        empresaId != null
            ? _supabase
                  .from('empresa_areas')
                  .select('id, empresa_id, area_id')
                  .eq('empresa_id', empresaId)
            : Future.value(<Map<String, dynamic>>[]),
      ),
    ]);

    // Guardar cada tabla que se descargó exitosamente
    // 0: areas (global — sin scope, se filtra via empresa_areas)
    if (futures[0] != null) {
      try {
        await _dbHelper.guardarMaestros(
          'areas',
          List<Map<String, dynamic>>.from(futures[0]!),
        );
        tablasDescargadas.add('areas');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando areas en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: areas',
          fatal: false,
        );
        tablasFallidas.add('areas');
      }
    }

    // 1: centros
    if (futures[1] != null) {
      try {
        await _dbHelper.guardarMaestros(
          'centros',
          List<Map<String, dynamic>>.from(futures[1]!),
        );
        tablasDescargadas.add('centros');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando centros en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: centros',
          fatal: false,
        );
        tablasFallidas.add('centros');
      }
    }

    // 2: contratistas
    if (futures[2] != null) {
      try {
        await _dbHelper.guardarMaestros(
          'contratistas',
          List<Map<String, dynamic>>.from(futures[2]!),
        );
        tablasDescargadas.add('contratistas');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando contratistas en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: contratistas',
          fatal: false,
        );
        tablasFallidas.add('contratistas');
      }
    }

    // 3: embarcaciones
    if (futures[3] != null) {
      try {
        await _dbHelper.guardarMaestros(
          'embarcaciones',
          List<Map<String, dynamic>>.from(futures[3]!),
        );
        tablasDescargadas.add('embarcaciones');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando embarcaciones en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: embarcaciones',
          fatal: false,
        );
        tablasFallidas.add('embarcaciones');
      }
    }

    // 4: formulario_items
    if (futures[4] != null) {
      try {
        await _dbHelper.guardarItemsOffline(
          List<Map<String, dynamic>>.from(futures[4]!),
        );
        tablasDescargadas.add('formulario_items');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando formulario_items en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: formulario_items',
          fatal: false,
        );
        tablasFallidas.add('formulario_items');
      }
    }

    // 5: personal_externo
    if (futures[5] != null) {
      try {
        await _dbHelper.guardarMaestros(
          'personal_externo',
          List<Map<String, dynamic>>.from(futures[5]!),
        );
        tablasDescargadas.add('personal_externo');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando personal_externo en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: personal_externo',
          fatal: false,
        );
        tablasFallidas.add('personal_externo');
      }
    }

    // 6: empresas
    if (futures[6] != null) {
      try {
        await _dbHelper.guardarMaestros(
          'empresas',
          List<Map<String, dynamic>>.from(futures[6]!),
        );
        tablasDescargadas.add('empresas');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando empresas en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: empresas',
          fatal: false,
        );
        tablasFallidas.add('empresas');
      }
    }

    // 7: ticket_categorias
    if (futures[7] != null) {
      try {
        await _dbHelper.guardarMaestros(
          'ticket_categorias',
          List<Map<String, dynamic>>.from(futures[7]!),
        );
        tablasDescargadas.add('ticket_categorias');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando ticket_categorias en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: ticket_categorias',
          fatal: false,
        );
        tablasFallidas.add('ticket_categorias');
      }
    }

    // 8: usuarios
    if (futures[8] != null) {
      try {
        await _dbHelper.guardarMaestros(
          'usuarios',
          List<Map<String, dynamic>>.from(futures[8]!),
        );
        tablasDescargadas.add('usuarios');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando usuarios en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: usuarios',
          fatal: false,
        );
        tablasFallidas.add('usuarios');
      }
    }

    // Descargar tickets (independiente)
    try {
      await _ticketRepo.descargarTicketsDesdeSupabase();
    } catch (e, stack) {
      debugPrint("⚠️ Error descargando tickets: $e");
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'descargarTicketsDesdeSupabase',
        fatal: false,
      );
    }

    // 9: empresa_modulos (condicional)
    final modulosData = futures[9];
    if (modulosData != null && modulosData.isNotEmpty) {
      try {
        await _dbHelper.guardarMaestros(
          'empresa_modulos',
          List<Map<String, dynamic>>.from(modulosData),
          scopeWhere: empresaId != null ? 'empresa_id = ?' : null,
          scopeArgs: empresaId != null ? [empresaId] : null,
        );
        tablasDescargadas.add('empresa_modulos');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando empresa_modulos en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: empresa_modulos',
          fatal: false,
        );
        tablasFallidas.add('empresa_modulos');
      }
    }

    // 10: usuario_empresas (condicional)
    final ueData = futures[10];
    if (ueData != null && ueData.isNotEmpty) {
      try {
        await _dbHelper.guardarMaestros(
          'usuario_empresas',
          List<Map<String, dynamic>>.from(ueData),
          scopeWhere: userId != null ? 'usuario_id = ?' : null,
          scopeArgs: userId != null ? [userId] : null,
        );
        tablasDescargadas.add('usuario_empresas');
        if (userId != null) {
          await UserSession().loadFromSQLite(userId);
        }
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando usuario_empresas en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: usuario_empresas',
          fatal: false,
        );
        tablasFallidas.add('usuario_empresas');
      }
    }

    // 11: empresa_areas (condicional)
    final eaData = futures[11];
    if (eaData != null && eaData.isNotEmpty) {
      try {
        await _dbHelper.guardarMaestros(
          'empresa_areas',
          List<Map<String, dynamic>>.from(eaData),
          scopeWhere: empresaId != null ? 'empresa_id = ?' : null,
          scopeArgs: empresaId != null ? [empresaId] : null,
        );
        tablasDescargadas.add('empresa_areas');
      } catch (e, stack) {
        debugPrint("⚠️ Error guardando empresa_areas en SQLite: $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'guardarMaestros SQLite: empresa_areas',
          fatal: false,
        );
        tablasFallidas.add('empresa_areas');
      }
    }

    if (tablasFallidas.isEmpty) {
      debugPrint(
        "✅ Datos maestros actualizados offline (${tablasDescargadas.length} tablas).",
      );
    } else {
      debugPrint(
        "⚠️ Descarga parcial: ${tablasDescargadas.length} OK, ${tablasFallidas.length} fallidas: $tablasFallidas",
      );
    }

    return tablasFallidas;
  }

  // --- 2. SUBIDA DE DATOS (Up-Sync) ---
  // --- 2. SUBIDA DE DATOS (Up-Sync) ---
  Future<int> sincronizarTodo() async {
    int totalSubidas = 0;
    try {
      // 0. Verificar y descargar datos maestros faltantes ANTES de sincronizar
      await _verificarYDescargarFaltantes();

      // 1. Subir datos maestros creados localmente (ANTES de actividades por FK)
      await _sincronizarMaestrosPendientes();

      // 2. Subir Inspecciones (Las que siguen usando la tabla actividades)
      int actividadesSubidas = await _sincronizarActividades();

      // 3. Subir Visitas Técnicas (AHORA SON INDEPENDIENTES)
      int visitasSubidas = await _sincronizarVisitas();

      // 4. Subir Hijos (Respuestas y Fotos)
      await _sincronizarRespuestas();
      await _sincronizarFotos();

      // 5. Subir Tickets pendientes
      await _ticketRepo.syncTicketsHaciaSupabase();

      // 6. Subir configuración de módulos por empresa
      await _sincronizarEmpresaModulos();

      totalSubidas = actividadesSubidas + visitasSubidas;
    } catch (e) {
      debugPrint("❌ Error en sincronización global: $e");
    }

    // 7. Generar PDFs diferidos SIEMPRE (fuera del try/catch principal)
    // Así se ejecuta aunque otros pasos de sync hayan fallado
    try {
      await _recuperarNumeroReporteFaltante();
      await _generarPdfsDiferidos();
    } catch (e) {
      debugPrint("⚠️ Error en generación de PDFs diferidos: $e");
    }

    return totalSubidas;
  }

  /// Verifica qué tablas maestras están vacías en SQLite y las descarga.
  /// Solo descarga las que faltan, no todas.
  Future<void> _verificarYDescargarFaltantes() async {
    final db = await _dbHelper.database;
    final empresaId = UserSession().empresaId;

    // Tablas obligatorias que siempre deben tener datos
    final tablasAVerificar = [
      'areas',
      'centros',
      'contratistas',
      'embarcaciones',
      'formulario_items',
      'personal_externo',
      'empresas',
      'ticket_categorias',
      'usuarios',
    ];

    final tablasVacias = <String>[];
    for (final tabla in tablasAVerificar) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tabla'),
      );
      if (count == null || count == 0) {
        tablasVacias.add(tabla);
      }
    }

    if (tablasVacias.isEmpty) {
      return; // Todo OK, no falta nada
    }

    debugPrint(
      "⚠️ Tablas maestras vacías detectadas: $tablasVacias → descargando...",
    );

    // Re-descargar solo las tablas faltantes
    for (final tabla in tablasVacias) {
      try {
        List<Map<String, dynamic>> data;
        switch (tabla) {
          case 'areas':
            data = await _supabase
                .from('areas')
                .select('id, nombre, empresa_id');
            await _dbHelper.guardarMaestros('areas', data);
            break;
          case 'centros':
            data = await _supabase
                .from('centros')
                .select('id, nombre, area_id');
            await _dbHelper.guardarMaestros('centros', data);
            break;
          case 'contratistas':
            data = await _supabase.from('contratistas').select('id, nombre');
            await _dbHelper.guardarMaestros('contratistas', data);
            break;
          case 'embarcaciones':
            data = await _supabase
                .from('embarcaciones')
                .select('id, nombre, contratista_id, matricula');
            await _dbHelper.guardarMaestros('embarcaciones', data);
            break;
          case 'formulario_items':
            data = await _supabase
                .from('formulario_items')
                .select()
                .eq('activo', true)
                .order('orden');
            await _dbHelper.guardarItemsOffline(data);
            break;
          case 'personal_externo':
            data = await _supabase.from('personal_externo').select();
            await _dbHelper.guardarMaestros('personal_externo', data);
            break;
          case 'empresas':
            data = await _supabase
                .from('empresas')
                .select('id, nombre, es_administradora, logo_url');
            await _dbHelper.guardarMaestros('empresas', data);
            break;
          case 'ticket_categorias':
            data = await _supabase
                .from('ticket_categorias')
                .select('id, nombre, activo')
                .eq('activo', true);
            await _dbHelper.guardarMaestros('ticket_categorias', data);
            break;
          case 'usuarios':
            data = await _supabase
                .from('usuarios')
                .select(
                  'id, rut, nombre_completo, email, rol_id, telefono, empresa_id, roles (nombre)',
                );
            await _dbHelper.guardarMaestros('usuarios', data);
            break;
        }
        debugPrint("✅ Tabla faltante '$tabla' descargada OK");
      } catch (e, stack) {
        debugPrint("⚠️ No se pudo descargar tabla faltante '$tabla': $e");
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'verificarYDescargarFaltantes: tabla $tabla',
          fatal: false,
        );
      }
    }

    // Verificar tabla condicional: empresa_areas
    if (empresaId != null) {
      final eaCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM empresa_areas WHERE empresa_id = ?',
          [empresaId],
        ),
      );
      if (eaCount == null || eaCount == 0) {
        try {
          final eaData = await _supabase
              .from('empresa_areas')
              .select('id, empresa_id, area_id')
              .eq('empresa_id', empresaId);
          if (eaData.isNotEmpty) {
            await _dbHelper.guardarMaestros(
              'empresa_areas',
              eaData,
              scopeWhere: 'empresa_id = ?',
              scopeArgs: [empresaId],
            );
            debugPrint("✅ Tabla faltante 'empresa_areas' descargada OK");
          }
        } catch (e, stack) {
          debugPrint(
            "⚠️ No se pudo descargar tabla faltante 'empresa_areas': $e",
          );
          FirebaseCrashlytics.instance.recordError(
            e,
            stack,
            reason: 'verificarYDescargarFaltantes: empresa_areas',
            fatal: false,
          );
        }
      }
    }
  }

  Future<int> _sincronizarActividades() async {
    final db = await _dbHelper.database;
    final pendientes = await db.query(
      'actividades_pendientes',
      where: 'subido = 0',
    );

    if (pendientes.isEmpty) return 0;

    int count = 0;
    for (var row in pendientes) {
      final activityId = row['id'] as String;
      final tipoActividad = row['tipo_actividad'] as String;
      final estaEliminado = (row['eliminado'] as int?) == 1;

      if (estaEliminado) {
        try {
          debugPrint("🗑️ Eliminando borrador en nube: $activityId");

          await _supabase
              .from('actividades')
              .update({'estado_final': 'Eliminada'})
              .eq('id', activityId);

          // Limpieza profunda local (Hard Delete)
          await db.delete(
            'actividades_pendientes',
            where: 'id = ?',
            whereArgs: [activityId],
          );

          // Limpieza de tablas hijas (BUCEO y EMBARCACIÓN)
          if (tipoActividad == 'INSPECCION_BUCEO') {
            await db.delete(
              'verificaciones_buceo',
              where: 'actividad_id = ?',
              whereArgs: [activityId],
            );
          } else if (tipoActividad == 'INSPECCION_EMBARCACION') {
            await db.delete(
              'verificaciones_embarcacion',
              where: 'actividad_id = ?',
              whereArgs: [activityId],
            );
          }
          // Participantes aplica a AMBOS tipos
          await db.delete(
            'actividad_participantes',
            where: 'actividad_id = ?',
            whereArgs: [activityId],
          );

          await db.delete(
            'fotos_pendientes',
            where: 'actividad_id = ?',
            whereArgs: [activityId],
          );
          await db.delete(
            'inspeccion_respuestas_pendientes',
            where: 'actividad_id = ?',
            whereArgs: [activityId],
          );

          debugPrint("✅ Borrador zombie aniquilado: $activityId");
        } catch (e) {
          debugPrint("❌ Error eliminando zombie en Supabase  (offline?): $e");
        }
        continue;
      }

      try {
        debugPrint("🚀 Sync Actividad ($tipoActividad): $activityId");

        final datosParaNube = Map<String, dynamic>.from(row);
        datosParaNube['puerto_abierto'] = (row['puerto_abierto'] == 1);
        datosParaNube['numero_seguimiento'] = row['numero_seguimiento'] ?? 0;
        datosParaNube.remove('numero_reporte');
        datosParaNube.remove('subido');
        datosParaNube.remove('eliminado');
        datosParaNube.remove('pdf_path_local');
        datosParaNube.remove('app_version');

        // --- 1. VERIFICACIÓN ESTRICTA EN LA NUBE ---
        final checkNube = await _supabase
            .from('actividades')
            .select('id')
            .eq('id', activityId)
            .maybeSingle();

        if (checkNube != null) {
          datosParaNube.remove('numero_informe');
          await _supabase
              .from('actividades')
              .update(datosParaNube)
              .eq('id', activityId);

          // Si acabamos de finalizar (En Seguimiento), el trigger asignó número
          final estadoActual = row['estado_final']?.toString();
          if (estadoActual == 'En Seguimiento') {
            final updatedRow = await _supabase
                .from('actividades')
                .select('numero_informe')
                .eq('id', activityId)
                .maybeSingle();
            final numFromUpdate = updatedRow?['numero_informe'];
            if (numFromUpdate != null) {
              await db.update(
                'actividades_pendientes',
                {'numero_reporte': numFromUpdate.toString()},
                where: 'id = ?',
                whereArgs: [activityId],
              );
            }
          }
        } else {
          datosParaNube.remove('numero_informe');
          final response = await _supabase
              .from('actividades')
              .insert(datosParaNube)
              .select('numero_informe')
              .single();

          // Solo guardar numero_informe si realmente se asignó (finalizados)
          final nuevoNumero = response['numero_informe'];
          if (nuevoNumero != null) {
            await db.update(
              'actividades_pendientes',
              {'numero_reporte': nuevoNumero.toString()},
              where: 'id = ?',
              whereArgs: [activityId],
            );
          }
        }

        // --- 2. SUBIDA DE DATOS HIJOS ---
        if (tipoActividad == 'INSPECCION_BUCEO') {
          await _sincronizarVerificaciones(db, activityId);
        } else if (tipoActividad == 'INSPECCION_EMBARCACION') {
          await _sincronizarVerificacionesEmbarcacion(db, activityId);
        }

        // ¡IMPORTANTE! Los participantes aplican para AMBOS tipos de inspección
        await _sincronizarParticipantes(db, activityId);

        // --- 2.5. SUBIR PDF PENDIENTE SI HAY UNO LOCAL ---
        final pdfPathLocal = row['pdf_path_local'] as String?;
        final pdfUrlActual = row['pdf_url'] as String?;

        if (pdfPathLocal != null &&
            pdfPathLocal.isNotEmpty &&
            (pdfUrlActual == null || pdfUrlActual.isEmpty)) {
          try {
            final file = File(pdfPathLocal);
            if (file.existsSync()) {
              final pdfBytes = await file.readAsBytes();
              final nombreArchivo = "reporte_${row['numero_reporte']}.pdf";
              final pathStorage = "$activityId/$nombreArchivo";

              debugPrint("☁️ Subiendo PDF pendiente a Storage...");
              await _supabase.storage
                  .from('reportes')
                  .uploadBinary(
                    pathStorage,
                    pdfBytes,
                    fileOptions: const FileOptions(upsert: true),
                  );

              final pdfUrl = _supabase.storage
                  .from('reportes')
                  .getPublicUrl(pathStorage);

              // Actualizar URL en local y en Supabase
              await db.update(
                'actividades_pendientes',
                {'pdf_url': pdfUrl, 'pdf_path_local': null},
                where: 'id = ?',
                whereArgs: [activityId],
              );

              await _supabase
                  .from('actividades')
                  .update({'pdf_url': pdfUrl})
                  .eq('id', activityId);

              debugPrint("✅ PDF pendiente subido: $pdfUrl");
            } else {
              // Archivo local eliminado (reinstalación, clear data, etc.)
              // Limpiar pdf_path_local para que DeferredPdfService lo regenere
              debugPrint(
                "⚠️ PDF local no existe ($pdfPathLocal), limpiando para regenerar...",
              );
              await db.update(
                'actividades_pendientes',
                {'pdf_path_local': null},
                where: 'id = ?',
                whereArgs: [activityId],
              );
            }
          } catch (e) {
            debugPrint("⚠️ Error subiendo PDF pendiente (se reintentará): $e");
            // No fallamos, el PDF se subirá en el próximo sync
          }
        }

        // --- 3. MARCAR COMO SUBIDO LOCALMENTE ---
        await db.update(
          'actividades_pendientes',
          {'subido': 1},
          where: 'id = ?',
          whereArgs: [activityId],
        );

        count++;
        debugPrint("✅ Actividad subida OK: $activityId");
      } catch (e) {
        debugPrint("🔥 Error subiendo actividad $activityId: $e");
      }
    }
    return count;
  }

  Future<void> _sincronizarVerificacionesEmbarcacion(
    DatabaseExecutor db,
    String activityId,
  ) async {
    final results = await db.query(
      'verificaciones_embarcacion',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    if (results.isNotEmpty) {
      try {
        final data = Map<String, dynamic>.from(results.first);
        await _supabase
            .from('verificaciones_embarcacion')
            .upsert(data, onConflict: 'actividad_id');
        debugPrint(
          "✅ Verificaciones de embarcación sincronizadas para $activityId",
        );
      } catch (e) {
        debugPrint("⚠️ Error subiendo verificaciones embarcación: $e");
      }
    }
  }

  // --- 🟢 NUEVO MÉTODO EXCLUSIVO PARA VISITAS (DDD) ---
  Future<int> _sincronizarVisitas() async {
    final db = await _dbHelper.database;
    final pendientes = await db.query(
      'visitas_tecnicas_pendientes',
      where: 'subido = 0',
    );

    if (pendientes.isEmpty) return 0;

    int count = 0;
    for (var row in pendientes) {
      final id = row['id'] as String;
      final estaEliminado = (row['eliminado'] as int?) == 1;

      // 1. FLUJO DE BORRADO (ZOMBIES)
      if (estaEliminado) {
        try {
          debugPrint("🗑️ Eliminando Visita zombie en nube: $id");
          await _supabase
              .from('visitas_tecnicas')
              .update({'estado_final': 'Eliminada'})
              .eq('id', id);

          await db.delete(
            'visitas_tecnicas_pendientes',
            where: 'id = ?',
            whereArgs: [id],
          );
          await db.delete(
            'fotos_pendientes',
            where: 'actividad_id = ?',
            whereArgs: [id],
          );
          await db.delete(
            'visitas_checklists_pendientes',
            where: 'visita_id = ?',
            whereArgs: [id],
          );

          debugPrint("✅ Visita zombie aniquilada.");
        } catch (e) {
          debugPrint("❌ Error eliminando Visita zombie (offline?): $e");
        }
        continue;
      }

      // 2. FLUJO DE SUBIDA/UPSERT
      try {
        debugPrint("🚀 Sync Visita Técnica Independiente: $id");

        final datosNube = Map<String, dynamic>.from(row);

        // Limpiamos la basura local y la ruta física del PDF
        datosNube.remove('subido');
        datosNube.remove('eliminado');
        final String? pdfPathLocal = datosNube.remove('pdf_path_local');

        // Parseamos los booleanos de SQLite (1/0) a PostgreSQL (true/false).
        // Preservamos null si el módulo no usa estos campos (ej: extintores).
        bool? toBool(dynamic v) => v == null ? null : v == 1;
        datosNube['check_reunion'] = toBool(datosNube['check_reunion']);
        datosNube['check_instalacion_senaletica'] = toBool(
          datosNube['check_instalacion_senaletica'],
        );
        datosNube['check_capacitacion'] = toBool(
          datosNube['check_capacitacion'],
        );
        datosNube['check_visita_sso'] = toBool(datosNube['check_visita_sso']);
        datosNube['check_charla'] = toBool(datosNube['check_charla']);
        datosNube['check_investigacion_incidente'] = toBool(
          datosNube['check_investigacion_incidente'],
        );
        datosNube['check_inspeccion_sso'] = toBool(
          datosNube['check_inspeccion_sso'],
        );
        datosNube['check_obs_conductual'] = toBool(
          datosNube['check_obs_conductual'],
        );
        datosNube['check_otro'] = toBool(datosNube['check_otro']);

        final sessionActiva = _supabase.auth.currentSession;
        debugPrint(
          "🕵️ [AUDITORÍA AUTH] Token activo: ${sessionActiva != null}",
        );
        debugPrint(
          "🕵️ [AUDITORÍA AUTH] ID Usuario: ${_supabase.auth.currentUser?.id}",
        );
        debugPrint("🕵️ [AUDITORÍA PAYLOAD] Datos a inyectar: $datosNube");

        if (datosNube['usuario_id'] == null) {
          final activeUserId = _supabase.auth.currentUser?.id;
          if (activeUserId != null) {
            datosNube['usuario_id'] = activeUserId;

            // Opcional: Curar también SQLite para que quede consistente
            await db.update(
              'visitas_tecnicas_pendientes',
              {'usuario_id': activeUserId},
              where: 'id = ?',
              whereArgs: [id],
            );
            debugPrint(
              "🩹 [AUTO-FIX] usuario_id nulo curado con la sesión activa.",
            );
          }
        }

        // 2.A. Hacemos el Upsert directo a Supabase (Data Relacional)
        await _supabase
            .from('visitas_tecnicas')
            .upsert(datosNube, onConflict: 'id');

        // --- 2.A.2 Sincronizar Checklist Dinámico (JSONB) ---
        final checklistResults = await db.query(
          'visitas_checklists_pendientes',
          where: 'visita_id = ?',
          whereArgs: [id],
        );

        if (checklistResults.isNotEmpty) {
          for (var chk in checklistResults) {
            final String tipo = chk['tipo_checklist'] as String;
            final String respuestasStr = chk['respuestas'] as String;

            // Decodificamos el String de SQLite a un Map para que Supabase lo inserte como JSONB
            final payloadChecklist = {
              'visita_id': id,
              'tipo_checklist': tipo,
              'respuestas': jsonDecode(respuestasStr),
            };

            await _supabase
                .from('visitas_checklists')
                .upsert(
                  payloadChecklist,
                  onConflict: 'visita_id, tipo_checklist',
                );
          }
          debugPrint("✅ Checklist dinámico sincronizado para visita: $id");
        }

        // --- 2.A.3 Sincronizar Extintores (solo si es inspección de extintores) ---
        if (row['tipo_actividad'] == 'VISITA_R004') {
          await _sincronizarExtintoresDe(db, id);
        }

        // 2.B. MAGIA CAMINO B: Subida del PDF en Background
        String? pdfUrlNube = row['pdf_url'] as String?;

        if (pdfPathLocal != null && pdfUrlNube == null) {
          final file = File(pdfPathLocal);
          if (file.existsSync()) {
            try {
              debugPrint("📤 Subiendo PDF de visita al Storage...");
              final nombreArchivo = 'Visita_$id.pdf';
              final pathStorage = '$id/$nombreArchivo';

              // Subimos al bucket que creaste
              await _supabase.storage
                  .from('pdfs_visitas')
                  .upload(
                    pathStorage,
                    file,
                    fileOptions: const FileOptions(upsert: true),
                  );

              // Obtenemos la URL pública
              pdfUrlNube = _supabase.storage
                  .from('pdfs_visitas')
                  .getPublicUrl(pathStorage);

              // Actualizamos la fila en la tabla con la URL generada
              await _supabase
                  .from('visitas_tecnicas')
                  .update({'pdf_url': pdfUrlNube})
                  .eq('id', id);

              debugPrint("✅ PDF subido y URL enlazada: $pdfUrlNube");
            } catch (e) {
              debugPrint("⚠️ Error subiendo PDF al Storage: $e");
              // OJO: Si el Storage falla por red, no reventamos la transacción.
              // La data relacional ya subió. El PDF se intentará de nuevo después.
            }
          } else {
            debugPrint("⚠️ El archivo PDF local no existe en: $pdfPathLocal");
          }
        }

        // 2.C. Marcamos como subido localmente SOLO si:
        // - No había PDF local que subir, O
        // - El PDF se subió correctamente (pdfUrlNube != null)
        final pdfPendiente = pdfPathLocal != null && pdfUrlNube == null;
        if (!pdfPendiente) {
          await db.update(
            'visitas_tecnicas_pendientes',
            {'subido': 1, if (pdfUrlNube != null) 'pdf_url': pdfUrlNube},
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          debugPrint(
            "⚠️ PDF pendiente de subir para visita $id, no se marca como subido",
          );
        }

        count++;
        debugPrint("✅ Visita Técnica (y artefactos) sincronizada OK: $id");
      } catch (e) {
        // 🚨 AQUÍ EL CATCH ESTÁ BLINDADO. NO MODIFICA ESTADO, SOLO ADVIERTE.
        debugPrint("🔥 Error subiendo visita $id: $e");
      }
    }
    return count;
  }

  /// Sube los extintores de una inspección VISITA_R004 a Supabase
  Future<void> _sincronizarExtintoresDe(
    DatabaseExecutor db,
    String visitaId,
  ) async {
    final extintores = await db.query(
      'extintores_pendientes',
      where: 'visita_id = ? AND subido = 0',
      whereArgs: [visitaId],
    );

    if (extintores.isEmpty) return;

    for (final row in extintores) {
      try {
        final payload = {
          'id': row['id'],
          'visita_id': row['visita_id'],
          'numero': row['numero'],
          'matricula': row['matricula'],
          'tipo_extintor': row['tipo_extintor'],
          'peso_extintor': row['peso_extintor'],
          'fecha_ultima_mantencion': row['fecha_ultima_mantencion'],
          'fecha_proxima_mantencion': row['fecha_proxima_mantencion'],
          'fotos_json': row['fotos_json'] != null
              ? jsonDecode(row['fotos_json'] as String)
              : [],
          'respuestas_json': row['respuestas_json'] != null
              ? jsonDecode(row['respuestas_json'] as String)
              : {},
        };

        await _supabase.from('extintores').upsert(payload, onConflict: 'id');

        await db.update(
          'extintores_pendientes',
          {'subido': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint("⚠️ Error sincronizando extintor ${row['id']}: $e");
      }
    }
    debugPrint("✅ Extintores sincronizados para visita $visitaId");
  }

  Future<void> _sincronizarVerificaciones(
    DatabaseExecutor db,
    String activityId,
  ) async {
    // 1. Buscamos el registro en SQLite
    final results = await db.query(
      'verificaciones_buceo',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    if (results.isNotEmpty) {
      try {
        // 2. Limpieza de datos (Importante)
        // Creamos una copia editable del mapa
        final data = Map<String, dynamic>.from(results.first);

        // Eliminamos columnas que sean SOLO locales (si tienes alguna como 'id_sqlite')
        // Si no tienes columnas extra locales, esto igual asegura que sea un mapa limpio

        // 3. Upsert a Supabase
        // Usamos upsert para que sirva tanto para guardar borrador (insert)
        // como para actualizar cambios finales (update)
        await _supabase
            .from('verificaciones_buceo')
            .upsert(
              data,
              onConflict: 'actividad_id',
            ); // Asegúrate que la PK sea actividad_id o la que definiste

        debugPrint("✅ Verificaciones de buceo sincronizadas para $activityId");
      } catch (e) {
        debugPrint("⚠️ Error subiendo verificaciones buceo: $e");
      }
    }
  }

  // En SyncService.dart

  Future<void> _sincronizarParticipantes(
    DatabaseExecutor db,
    String activityId,
  ) async {
    // 1. Obtener la lista de relaciones locales
    final relaciones = await db.query(
      'actividad_participantes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    // --- LIMPIEZA DE HUÉRFANOS (Sin cambios, tu lógica estaba bien) ---
    try {
      final idsVigentes = relaciones.map((r) => r['personal_id']).toList();
      if (idsVigentes.isNotEmpty) {
        await _supabase
            .from('actividad_participantes')
            .delete()
            .eq('actividad_id', activityId)
            .filter('personal_id', 'not.in', '(${idsVigentes.join(',')})');
      } else {
        await _supabase
            .from('actividad_participantes')
            .delete()
            .eq('actividad_id', activityId);
      }
    } catch (e) {
      debugPrint("⚠️ Error limpiando participantes antiguos: $e");
    }
    // ----------------------------------------------------------------

    if (relaciones.isEmpty) return;

    for (var rel in relaciones) {
      final personalId = rel['personal_id'] as String;

      // --- PASO A: Asegurar que la PERSONA exista en Supabase ---
      final personaData = await db.query(
        'personal_externo',
        where: 'id = ?',
        whereArgs: [personalId],
      );

      if (personaData.isNotEmpty) {
        final raw = personaData.first;

        // 1. CREAMOS EL PAQUETE COMPLETO (Incluyendo contratista_id)
        final datosLimpios = {
          'id': raw['id'],
          'rut': RutUtils.normalize(raw['rut'] as String?),
          'nombre_completo': raw['nombre_completo'],
          'cargo': raw['cargo'],
          'activo': (raw['activo'] == 1),
          'matricula': raw['matricula'],
          // ✅ FIX CRÍTICO: Enviamos el ID del contratista padre
          'contratista_id': raw['contratista_id'],
        };

        try {
          await _supabase.from('personal_externo').upsert(datosLimpios);
          // Si pasa aquí, la persona existe en la nube.
        } catch (e) {
          // 🛑 SI FALLA LA PERSONA, ABORTAMOS EL VÍNCULO
          debugPrint(
            "🔥 Error CRÍTICO subiendo persona (${raw['nombre_completo']}): $e",
          );
          debugPrint("Saltando vínculo para evitar crash FK...");
          continue; // Pasamos al siguiente del bucle, no intentamos vincular
        }
      } else {
        debugPrint(
          "⚠️ ALERTA: ID $personalId en relación pero no en tabla personal local.",
        );
        continue;
      }

      // --- PASO B: Subir la RELACIÓN (Solo llegamos aquí si el PASO A funcionó) ---
      try {
        final datosRelacion = Map<String, dynamic>.from(rel);
        if (rel['condiciones_optimas'] is int) {
          datosRelacion['condiciones_optimas'] =
              (rel['condiciones_optimas'] == 1);
        }
        await _supabase.from('actividad_participantes').upsert(datosRelacion);
      } catch (e) {
        debugPrint("❌ Error vinculando participante: $e");
      }
    }
    debugPrint("✅ Cuadrilla sincronizada.");
  }

  // --- MÉTODOS EXISTENTES (Sin cambios mayores) ---

  Future<int> _sincronizarRespuestas() async {
    final db = await _dbHelper.database;
    final pendientes = await db.query(
      'inspeccion_respuestas_pendientes',
      where: 'subido = 0',
    );
    if (pendientes.isEmpty) return 0;

    List<Map<String, dynamic>> batchParaNube = [];
    List<int> idsLocales = [];

    for (var row in pendientes) {
      idsLocales.add(row['id'] as int);
      batchParaNube.add({
        'actividad_id': row['actividad_id'],
        'item_id': row['item_id'],
        'estado': row['estado'],
        'observacion': row['observacion'],
        'criticidad_registrada': row['criticidad_registrada'],
      });
    }

    await _supabase
        .from('inspeccion_respuestas')
        .upsert(
          batchParaNube,
          onConflict:
              'actividad_id, item_id', // Asegúrate de tener este constraint en Supabase
        );

    // 2. ACTUALIZAR LOCALMENTE (NO BORRAR)
    for (var id in idsLocales) {
      await db.update(
        'inspeccion_respuestas_pendientes',
        {'subido': 1}, // ✅ MARCAMOS COMO SUBIDO
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    debugPrint(
      "✅ Respuestas sincronizadas y marcadas localmente (${batchParaNube.length})",
    );
    return batchParaNube.length;
  }

  Future<int> _sincronizarFotos() async {
    final db = await _dbHelper.database;
    final fotosPendientes = await db.query(
      'fotos_pendientes',
      where: 'subido = 0',
    );
    if (fotosPendientes.isEmpty) return 0;

    int fotosSubidas = 0;

    for (var row in fotosPendientes) {
      final localId = row['id'] as int;
      final localPath = row['local_path'] as String;
      final actividadId = row['actividad_id'] as String;
      final itemId =
          row['item_id'] as String?; // Puede ser null si es foto general
      final descripcion = row['descripcion'] as String?;

      final file = File(localPath);
      if (!file.existsSync()) {
        // Limpieza de basura: Si el archivo no existe, borramos el registro
        await db.delete(
          'fotos_pendientes',
          where: 'id = ?',
          whereArgs: [localId],
        );
        continue;
      }

      try {
        // 1. BUSQUEDA DE ID PADRE (CRÍTICO)
        // ✅ CORRECCIÓN: El ID de la tabla inspeccion_respuestas en Supabase es un UUID (String), no un int.
        String? respuestaIdNube;

        if (itemId != null && itemId != 'visita_general') {
          final respuestaData = await _supabase
              .from('inspeccion_respuestas')
              .select('id')
              .eq('actividad_id', actividadId)
              .eq('item_id', itemId)
              .maybeSingle();

          if (respuestaData != null) {
            // Asignamos el String directamente
            respuestaIdNube = respuestaData['id'] as String;
          } else {
            debugPrint(
              "⚠️ Foto huérfana para item $itemId. Saltando hasta sync de respuestas.",
            );
            continue;
          }
        }

        // 2. SUBIDA AL STORAGE
        final nombreArchivoReal = file.uri.pathSegments.last;
        final pathStorage = '$actividadId/$nombreArchivoReal';

        await _supabase.storage
            .from('evidencias')
            .upload(
              pathStorage,
              file,
              fileOptions: const FileOptions(upsert: true),
            );

        final publicUrl = _supabase.storage
            .from('evidencias')
            .getPublicUrl(pathStorage);

        // 3. INSERT EN BASE DE DATOS (CON VÍNCULO)
        // Usamos upsert para evitar duplicados si se corta internet a mitad de camino
        final datosFoto = {
          'actividad_id': actividadId,
          'foto_url': publicUrl,
          'descripcion': descripcion ?? '',
        };

        // ✅ CORRECCIÓN: Si tenemos el ID de la respuesta, lo inyectamos al Map
        if (respuestaIdNube != null) {
          datosFoto['inspeccion_respuesta_id'] = respuestaIdNube;
        }

        await _supabase
            .from('registro_fotografico')
            .upsert(
              datosFoto,
              onConflict:
                  'foto_url', // Asegúrate de que esto coincide con tu base de datos
            );

        // 4. ACTUALIZAR LOCALMENTE
        await db.update(
          'fotos_pendientes',
          {'subido': 1},
          where: 'id = ?',
          whereArgs: [localId],
        );

        fotosSubidas++;
        debugPrint("✅ Foto subida exitosamente y enlazada.");
      } catch (e) {
        debugPrint("❌ Error subiendo foto $localId: $e");
      }
    }
    return fotosSubidas;
  }

  // --- 0. INICIALIZACIÓN CRÍTICA (NUEVO) ---
  Future<void> hidratarContextoInicial(String userId) async {
    try {
      debugPrint("🔄 Iniciando hidratación de contexto para usuario: $userId");

      // 1. OBTENER PERFIL DEL USUARIO (Evita que el PDF salga en blanco)
      final userData = await _supabase
          .from('usuarios')
          .select(
            'id, rut, nombre_completo, email, rol_id, telefono, empresa_id, roles(nombre)',
          )
          .eq('id', userId)
          .maybeSingle();

      if (userData != null) {
        final db = await _dbHelper.database;
        final String? nombreRol = userData['roles'] != null
            ? userData['roles']['nombre']
            : null;
        await db.insert('usuarios', {
          'id': userData['id'],
          'rut': userData['rut'],
          'nombre_completo': userData['nombre_completo'],
          'email': userData['email'],
          'rol_id': userData['rol_id'],
          'telefono': userData['telefono'],
          'empresa_id': userData['empresa_id'],
          'nombre_rol': nombreRol,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        debugPrint(
          "✅ Perfil hidratado en SQLite. Rol detectado: ${nombreRol ?? 'Ninguno'}",
        );

        debugPrint(
          "✅ Perfil de usuario hidratado en SQLite desde SyncService.",
        );

        // Cargar UserSession singleton para acceso rápido en toda la app
        await UserSession().loadFromSQLite(userId);
      } else {
        throw Exception("Perfil de usuario no encontrado en la base de datos.");
      }

      // 2. DESCARGAR MAESTROS Y FORMULARIOS
      await descargarDatosMaestros();

      // 3. INTENTAR SUBIR PENDIENTES (Up-Sync silencioso)
      // Lo lanzamos sin hacer await para no bloquear el inicio de la app más de lo necesario
      sincronizarTodo().then((subidos) {
        if (subidos > 0) {
          debugPrint("✅ $subidos registros pendientes subidos al iniciar.");
        }
      });
    } catch (e) {
      debugPrint("🔥 Error crítico en hidratación inicial: $e");
      rethrow; // Lanzamos el error para que el AuthGate lo atrape y cierre sesión si es necesario
    }
  }

  // --- 5. SINCRONIZACIÓN DE MÓDULOS POR EMPRESA ---

  /// Método público para sincronizar módulos desde la pantalla de admin.
  Future<void> sincronizarEmpresaModulos() => _sincronizarEmpresaModulos();

  Future<void> _sincronizarEmpresaModulos() async {
    try {
      final db = await _dbHelper.database;
      final pendientes = await db.query('empresa_modulos', where: 'subido = 0');

      if (pendientes.isEmpty) return;

      for (var row in pendientes) {
        try {
          // onConflict en (empresa_id, modulo_key) porque Supabase tiene
          // UNIQUE constraint en esa combinación, y el id local puede diferir
          await _supabase.from('empresa_modulos').upsert({
            'empresa_id': row['empresa_id'],
            'modulo_key': row['modulo_key'],
            'habilitado': (row['habilitado'] as int) == 1,
            'orden': row['orden'],
          }, onConflict: 'empresa_id,modulo_key');

          await db.update(
            'empresa_modulos',
            {'subido': 1},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        } catch (e) {
          debugPrint("⚠️ Error sincronizando módulo ${row['modulo_key']}: $e");
        }
      }

      debugPrint("✅ ${pendientes.length} módulos de empresa sincronizados.");
    } catch (e) {
      debugPrint("⚠️ Error en _sincronizarEmpresaModulos: $e");
    }
  }

  /// Sube solo datos maestros (contratistas, centros, embarcaciones) creados localmente.
  /// Retorna mapa con resultados por tabla. Más liviano que sincronizarTodo().
  Future<Map<String, ({int exitosos, int fallidos, String? ultimoError})>>
  sincronizarMaestros() async {
    return _sincronizarMaestrosPendientes();
  }

  /// Eliminar un registro maestro de Supabase por tabla e id.
  Future<void> eliminarMaestro(String tabla, String id) async {
    await _supabase.from(tabla).delete().eq('id', id);
  }

  /// Sube centros, contratistas y embarcaciones creados localmente (subido=0).
  Future<Map<String, ({int exitosos, int fallidos, String? ultimoError})>>
  _sincronizarMaestrosPendientes() async {
    final resultados =
        <String, ({int exitosos, int fallidos, String? ultimoError})>{};
    try {
      // Contratistas primero (embarcaciones dependen de ellos)
      resultados['contratistas'] = await _syncTabla('contratistas', [
        'id',
        'nombre',
        'rut',
      ]);
      // Centros
      resultados['centros'] = await _syncTabla('centros', [
        'id',
        'nombre',
        'area_id',
      ]);
      // Embarcaciones
      resultados['embarcaciones'] = await _syncTabla('embarcaciones', [
        'id',
        'nombre',
        'contratista_id',
        'matricula',
      ]);
    } catch (e) {
      debugPrint("⚠️ Error en _sincronizarMaestrosPendientes: $e");
    }
    return resultados;
  }

  Future<({int exitosos, int fallidos, String? ultimoError})> _syncTabla(
    String tabla,
    List<String> campos,
  ) async {
    final pendientes = await _dbHelper.getPendingMasterData(tabla);
    debugPrint(
      '🔍 DEBUG-SYNC [_syncTabla] $tabla: ${pendientes.length} pendientes encontrados',
    );
    if (pendientes.isEmpty) {
      return (exitosos: 0, fallidos: 0, ultimoError: null);
    }

    int exitosos = 0;
    int fallidos = 0;
    String? ultimoError;
    for (var row in pendientes) {
      try {
        final payload = <String, dynamic>{};
        for (final campo in campos) {
          payload[campo] = row[campo];
        }
        // Safety net: contratistas requiere rut NOT NULL en Supabase
        if (tabla == 'contratistas' &&
            (payload['rut'] == null || (payload['rut'] as String).isEmpty)) {
          payload['rut'] = 'PENDIENTE-${(row['id'] as String).substring(0, 8)}';
        }
        debugPrint(
          '🔍 DEBUG-SYNC [_syncTabla] $tabla upsert payload: $payload',
        );
        await _supabase.from(tabla).upsert(payload);
        debugPrint('🔍 DEBUG-SYNC [_syncTabla] $tabla upsert ✅ OK: $payload');
        await _dbHelper.markMasterDataSynced(tabla, row['id'] as String);
        exitosos++;
      } catch (e) {
        fallidos++;
        ultimoError = e.toString();
        debugPrint("🔍 DEBUG-SYNC [_syncTabla] $tabla upsert ❌ FALLÓ: $e");
      }
    }
    debugPrint(
      "🔍 DEBUG-SYNC [_syncTabla] $tabla RESUMEN: $exitosos/${pendientes.length} OK, $fallidos fallidos",
    );
    return (exitosos: exitosos, fallidos: fallidos, ultimoError: ultimoError);
  }

  // --- 5.5. RECUPERAR numero_reporte FALTANTE ---
  // Inspecciones "En Seguimiento" que se sincronizaron pero nunca leyeron
  // el numero_informe de vuelta (ej: sync parcial, trigger retrasado).
  Future<void> _recuperarNumeroReporteFaltante() async {
    try {
      final db = await _dbHelper.database;
      final stuck = await db.query(
        'actividades_pendientes',
        columns: ['id'],
        where:
            "estado_final = 'En Seguimiento' AND "
            "(numero_reporte IS NULL OR numero_reporte = '') AND "
            "eliminado = 0",
      );

      if (stuck.isEmpty) return;

      debugPrint(
        "🔍 ${stuck.length} inspecciones sin numero_reporte, consultando Supabase...",
      );

      for (var row in stuck) {
        final activityId = row['id'] as String;
        try {
          final remote = await _supabase
              .from('actividades')
              .select('numero_informe')
              .eq('id', activityId)
              .maybeSingle();

          final numero = remote?['numero_informe'];
          if (numero != null && numero.toString().isNotEmpty) {
            await db.update(
              'actividades_pendientes',
              {'numero_reporte': numero.toString()},
              where: 'id = ?',
              whereArgs: [activityId],
            );
            debugPrint("✅ numero_reporte recuperado para $activityId: $numero");
          }
        } catch (e) {
          debugPrint(
            "⚠️ Error recuperando numero_reporte para $activityId: $e",
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error en _recuperarNumeroReporteFaltante: $e");
    }
  }

  // --- 6. GENERACIÓN DE PDFs DIFERIDOS (Opción C) ---
  Future<void> _generarPdfsDiferidos() async {
    try {
      final db = await _dbHelper.database;
      final pendientes = await db.query(
        'actividades_pendientes',
        where:
            "estado_final = 'En Seguimiento' AND "
            "(pdf_path_local IS NULL OR pdf_path_local = '') AND "
            "(pdf_url IS NULL OR pdf_url = '') AND "
            "eliminado = 0 AND "
            "numero_reporte IS NOT NULL AND numero_reporte != '' AND "
            "numero_reporte NOT LIKE 'PROV-%' AND "
            "numero_reporte NOT LIKE '~%'",
      );

      if (pendientes.isEmpty) return;

      debugPrint(
        "📄 Detectadas ${pendientes.length} inspecciones con PDF pendiente.",
      );

      final pdfService = DeferredPdfService();
      for (var row in pendientes) {
        final activityId = row['id'] as String;
        try {
          final ok = await pdfService.generarPdfDiferido(activityId);
          if (ok) {
            debugPrint("✅ PDF diferido generado para $activityId");
          }
        } catch (e) {
          debugPrint("⚠️ Error generando PDF diferido para $activityId: $e");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error en _generarPdfsDiferidos: $e");
    }
  }
}
