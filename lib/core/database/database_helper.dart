import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const int _dbVersion =
      33; // Incrementa este número cada vez que hagas un cambio en la estructura de la base de datos
  static const String _dbName = 'jfinnova_v18_local.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onOpen(Database db) async {
    await _repairCriticalSchema(db);
  }

  Future<void> _createDB(Database db, int version) async {
    debugPrint("✨ Creando Base de Datos Nueva v$version");

    // TABLA USUARIOS
    await db.execute('''
      CREATE TABLE usuarios (
        id TEXT PRIMARY KEY,
        rut TEXT,
        nombre_completo TEXT,
        email TEXT,
        telefono TEXT,
        rol_id TEXT,
        nombre_rol TEXT
      )
    ''');

    // 1. ITEMS DEL FORMULARIO
    await db.execute('''
      CREATE TABLE formulario_items (
        id TEXT PRIMARY KEY,
        tipo_actividad TEXT,
        categoria TEXT,
        pregunta TEXT,
        criticidad TEXT,
        orden INTEGER,
        activo INTEGER,
        info_adicional TEXT,
        url_imagen_referencia TEXT
      )
    ''');

    // 2. RESPUESTAS PENDIENTES
    await db.execute('''
      CREATE TABLE inspeccion_respuestas_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actividad_id TEXT,
        item_id TEXT,
        estado TEXT,
        observacion TEXT,
        criticidad_registrada TEXT,
        subido INTEGER DEFAULT 0
      )
    ''');

    // 3. FOTOS PENDIENTES
    await db.execute('''
      CREATE TABLE fotos_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actividad_id TEXT,
        item_id TEXT,
        local_path TEXT,
        descripcion TEXT,
        subido INTEGER DEFAULT 0
      )
    ''');

    // --- TABLAS DE DATOS MAESTROS (OFFLINE) ---
    await db.execute(
      'CREATE TABLE areas (id TEXT PRIMARY KEY, nombre TEXT, empresa_id TEXT)',
    );
    await db.execute(
      'CREATE TABLE centros (id TEXT PRIMARY KEY, nombre TEXT, area_id TEXT)',
    );
    await db.execute(
      'CREATE TABLE contratistas (id TEXT PRIMARY KEY, nombre TEXT)',
    );
    await db.execute(
      'CREATE TABLE empresas (id TEXT PRIMARY KEY, nombre TEXT)',
    );
    // Agregamos matricula aquí también por si acaso
    await db.execute(
      'CREATE TABLE embarcaciones (id TEXT PRIMARY KEY, nombre TEXT, contratista_id TEXT, matricula TEXT)',
    );

    // 4. ACTIVIDADES PENDIENTES
    await db.execute('''
      CREATE TABLE actividades_pendientes (
        id TEXT PRIMARY KEY,
        usuario_id TEXT,
        centro_id TEXT,
        contratista_id TEXT,
        embarcacion_id TEXT,
        tipo_actividad TEXT,
        fecha_realizacion TEXT,
        puerto_abierto INTEGER,
        observaciones_generales TEXT,
        estado_final TEXT,
        numero_reporte TEXT,
        numero_seguimiento INTEGER DEFAULT 0,
        pdf_url TEXT,
        pdf_path_local TEXT,
        eliminado INTEGER DEFAULT 0,
        subido INTEGER DEFAULT 0,
        app_version TEXT
      )
    ''');

    // --- 5. TABLAS ESPECÍFICAS DE BUCEO ---
    await db.execute('''
      CREATE TABLE verificaciones_buceo (
        actividad_id TEXT PRIMARY KEY,
        autorizacion_autoridad_maritima INTEGER DEFAULT 0,
        induccion_centro_cultivo INTEGER DEFAULT 0,
        permiso_buceo_centro_correcto INTEGER DEFAULT 0,
        plan_contingencias_centro_ok INTEGER DEFAULT 0,
        examenes_ocupacionales_vigentes INTEGER DEFAULT 0,

        -- OBSERVACIONES Y FOTOS POR ITEM
        obs_autorizacion TEXT, img_autorizacion TEXT,
        obs_induccion TEXT, img_induccion TEXT,
        obs_permiso TEXT, img_permiso TEXT,
        obs_plan TEXT, img_plan TEXT,
        obs_examenes TEXT, img_examenes TEXT,
        
        observacion_general TEXT,
        estado_manual TEXT,
        
        -- DATOS TÉCNICOS
        supervisor_nombre TEXT,
        supervisor_rut TEXT,
        encargado_centro TEXT,     
        supervisor_centro TEXT,    

        -- HORARIOS 
        hora_inicio TEXT,
        hora_termino TEXT,

        -- COMPRESOR 1
        compresor_1_matricula TEXT,
        compresor_1_vigencia TEXT,
        compresor_1_vigencia_ph TEXT, 
        compresor_1_buzos_cargo INTEGER,

        -- COMPRESOR 2
        compresor_2_matricula TEXT,
        compresor_2_vigencia TEXT,
        compresor_2_vigencia_ph TEXT, 
        compresor_2_buzos_cargo INTEGER,

        certificado_equipos_ok INTEGER DEFAULT 0,
        certificado_equipos_vigencia TEXT
      )
    ''');

    // --- TABLA ESPECÍFICA DE EMBARCACIONES ---
    await db.execute('''
      CREATE TABLE verificaciones_embarcacion (
        actividad_id TEXT PRIMARY KEY,
        correo_empresa TEXT,
        observaciones_cierre TEXT,
        numero_zarpe TEXT,
        hora_inicio TEXT,
        hora_termino TEXT
      )
    ''');

    // Tabla Maestra de Personal Externo (CORREGIDA: nombre_completo)
    await db.execute('''
      CREATE TABLE personal_externo (
        id TEXT PRIMARY KEY,
        rut TEXT,
        nombre_completo TEXT NOT NULL,
        cargo TEXT,
        matricula TEXT,
        contratista_id TEXT,
        activo INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_personal_externo_rut
      ON personal_externo(rut) WHERE rut IS NOT NULL AND rut != ''
    ''');

    // Tabla Intermedia
    await db.execute('''
      CREATE TABLE actividad_participantes (
        actividad_id TEXT,
        personal_id TEXT,
        rol_en_faena TEXT,
        condiciones_optimas INTEGER DEFAULT 1,
        PRIMARY KEY (actividad_id, personal_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE visitas_tecnicas_pendientes (
        id TEXT PRIMARY KEY,           
        usuario_id TEXT,               
        fecha_realizacion TEXT,        
        estado_final TEXT,             
        subido INTEGER DEFAULT 0,      
        eliminado INTEGER DEFAULT 0,   
        region TEXT,
        lugar_visita TEXT,             
        jefatura_a_cargo TEXT,
        origen_visita TEXT,
        hora_inicio TEXT,
        hora_termino TEXT,
        email_empresa_1 TEXT,
        email_empresa_2 TEXT,
        check_reunion INTEGER DEFAULT 0,
        check_instalacion_senaletica INTEGER DEFAULT 0,
        check_capacitacion INTEGER DEFAULT 0,
        check_visita_sso INTEGER DEFAULT 0,
        check_charla INTEGER DEFAULT 0,
        check_investigacion_incidente INTEGER DEFAULT 0,
        check_inspeccion_sso INTEGER DEFAULT 0,
        check_obs_conductual INTEGER DEFAULT 0,
        check_otro INTEGER DEFAULT 0,
        otro_actividad_texto TEXT,
        apuntes_observaciones TEXT,
        signature_image BLOB,
        pdf_path_local TEXT,
        pdf_url TEXT,
        tipo_actividad TEXT
      )
    ''');

    // --- 6. CHECKLISTS DINÁMICOS PARA VISITAS ---
    await db.execute('''
      CREATE TABLE visitas_checklists_pendientes (
        id TEXT PRIMARY KEY,
        visita_id TEXT,
        tipo_checklist TEXT,
        respuestas TEXT, -- SQLite guarda el JSON como String
        subido INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE visita_respuestas_pendientes (
        id TEXT PRIMARY KEY,
        visita_id TEXT,
        item_id TEXT,
        estado TEXT,
        observacion TEXT,
        criticidad TEXT,
        foto_path TEXT,
        subido INTEGER DEFAULT 0
      )
    ''');

    // --- MÓDULO TICKETS DE REQUERIMIENTOS ---
    await db.execute('''
      CREATE TABLE ticket_categorias (
        id TEXT PRIMARY KEY,
        nombre TEXT,
        activo INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE tickets_pendientes (
        id TEXT PRIMARY KEY,
        codigo_ticket TEXT,
        empresa_id TEXT,
        area_id TEXT,
        centro_id TEXT,
        embarcacion_id TEXT,
        actividad_id TEXT,
        categoria_id TEXT,
        categoria_otro TEXT,
        descripcion TEXT,
        solicitante_id TEXT,
        responsable_id TEXT,
        estado TEXT,
        criticidad TEXT,
        fecha_tentativa_cierre TEXT,
        created_at TEXT,
        subido INTEGER DEFAULT 0,
        eliminado INTEGER DEFAULT 0
      )
    ''');

    // --- MÓDULO EXTINTORES ---
    await db.execute('''
      CREATE TABLE extintores_pendientes (
        id TEXT PRIMARY KEY,
        visita_id TEXT NOT NULL,
        numero INTEGER NOT NULL,
        matricula TEXT,
        fotos_json TEXT,
        respuestas_json TEXT,
        subido INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    debugPrint("✅ Base de datos v$_dbVersion inicializada.");
  }

  // 🔥 GESTIÓN DE MIGRACIONES
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint("🔧 UPGRADE DB: v$oldVersion -> v$newVersion");

    // v3: Columnas de Buceo
    if (oldVersion < 3) {
      List<String> columnasNuevas = [
        "obs_autorizacion",
        "img_autorizacion",
        "obs_induccion",
        "img_induccion",
        "obs_permiso",
        "img_permiso",
        "obs_plan",
        "img_plan",
        "obs_examenes",
        "img_examenes",
      ];
      for (var col in columnasNuevas) {
        await _safeAddColumn(db, "verificaciones_buceo", col, "TEXT");
      }
    }

    // v4: Contratista y PDF
    if (oldVersion < 4) {
      await _safeAddColumn(db, "personal_externo", "contratista_id", "TEXT");
      await _safeAddColumn(db, "actividades_pendientes", "pdf_url", "TEXT");
    }

    // v5: Fix Actividades Pendientes
    if (oldVersion < 5) {
      await _safeAddColumn(
        db,
        "actividades_pendientes",
        "numero_seguimiento",
        "INTEGER DEFAULT 0",
      );
      await _safeAddColumn(
        db,
        "actividades_pendientes",
        "puerto_abierto",
        "INTEGER",
      );
      await _safeAddColumn(
        db,
        "actividades_pendientes",
        "numero_reporte",
        "TEXT",
      );
      await _safeAddColumn(
        db,
        "actividades_pendientes",
        "estado_final",
        "TEXT",
      );
      await _safeAddColumn(
        db,
        "actividades_pendientes",
        "observaciones_generales",
        "TEXT",
      );
    }

    // v10: FIX CRÍTICO PERSONAL EXTERNO (Nombre vs NombreCompleto)
    // Saltamos a v10 para asegurarnos que esto corra sí o sí.
    if (oldVersion < 10) {
      debugPrint("🚑 Aplicando parche v10 (Personal Externo)...");
      // Aseguramos que existan las columnas correctas
      await _safeAddColumn(db, "personal_externo", "nombre_completo", "TEXT");
      await _safeAddColumn(db, "personal_externo", "rut", "TEXT");

      // Aseguramos matrícula en embarcaciones por si acaso
      await _safeAddColumn(db, "embarcaciones", "matricula", "TEXT");
      debugPrint("✅ Parche v10 aplicado.");
    }

    if (oldVersion < 11) {
      debugPrint("🚀 Aplicando parche v11 (App Version)...");
      await _safeAddColumn(db, "actividades_pendientes", "app_version", "TEXT");
      debugPrint("✅ Parche v11 aplicado.");
    }
    if (oldVersion < 12) {
      debugPrint("🚀 Aplicando parche v12 (Módulo Visitas)...");

      // 1. Agregar teléfono al usuario local
      await _safeAddColumn(db, "usuarios", "telefono", "TEXT");

      // 2. Crear tabla local de visitas
      await db.execute('''
      CREATE TABLE visitas_tecnicas_pendientes (
        activity_id TEXT PRIMARY KEY,
        region TEXT,
        lugar_visita TEXT,
        jefatura_a_cargo TEXT,
        origen_visita TEXT,
        hora_inicio TEXT,
        hora_termino TEXT,
        email_empresa_1 TEXT,
        email_empresa_2 TEXT,
        check_reunion INTEGER DEFAULT 0,
        check_instalacion_senaletica INTEGER DEFAULT 0,
        check_capacitacion INTEGER DEFAULT 0,
        check_visita_sso INTEGER DEFAULT 0,
        check_charla INTEGER DEFAULT 0,
        check_investigacion_incidente INTEGER DEFAULT 0,
        check_inspeccion_sso INTEGER DEFAULT 0,
        check_obs_conductual INTEGER DEFAULT 0,
        check_otro INTEGER DEFAULT 0,
        otro_actividad_texto TEXT,
        apuntes_observaciones TEXT
      )
    ''');
      debugPrint("✅ Parche v12 aplicado.");
    }
    if (oldVersion < 13) {
      debugPrint("🚀 Aplicando parche v13 (Soft Delete)...");
      await _safeAddColumn(
        db,
        "actividades_pendientes",
        "eliminado",
        "INTEGER DEFAULT 0",
      );
    }
    if (oldVersion < 15) {
      debugPrint("🚀 Aplicando parche v14 (Info Adicional en Items)...");
      await _safeAddColumn(db, "formulario_items", "info_adicional", "TEXT");
      debugPrint("✅ Parche v14 aplicado.");
    }
    if (oldVersion < 16) {
      debugPrint("🚀 Aplicando parche v16 (Inspecciones Embarcación)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS verificaciones_embarcacion (
          actividad_id TEXT PRIMARY KEY,
          correo_empresa TEXT,
          observaciones_cierre TEXT
        )
      ''');
      debugPrint("✅ Parche v16 aplicado.");
    }
    if (oldVersion < 17) {
      debugPrint("🚀 Aplicando parche v17 (Numero de Zarpe Embarcación)...");
      await _safeAddColumn(
        db,
        "verificaciones_embarcacion",
        "numero_zarpe",
        "TEXT",
      );
      debugPrint("✅ Parche v17 aplicado.");
    }
    if (oldVersion < 18) {
      debugPrint("🚀 Aplicando parche v18 (Firma Digital Visitas)...");
      await _safeAddColumn(
        db,
        "visitas_tecnicas_pendientes",
        "signature_image",
        "BLOB",
      );
      debugPrint("✅ Parche v18 aplicado.");
    }
    if (oldVersion < 19) {
      debugPrint("🚀 Aplicando parche v19 (URL Imagen Referencia en Items)...");
      await _safeAddColumn(
        db,
        "formulario_items",
        "url_imagen_referencia",
        "TEXT",
      );
      debugPrint("✅ Parche v19 aplicado.");
    }
    if (oldVersion < 20) {
      debugPrint(
        "🚀 Aplicando parche v20 (Módulo Tickets de Requerimientos)...",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ticket_categorias (
          id TEXT PRIMARY KEY,
          nombre TEXT,
          activo INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tickets_pendientes (
          id TEXT PRIMARY KEY,
          codigo_ticket TEXT,
          empresa_id TEXT,
          area_id TEXT,
          actividad_id TEXT,
          categoria_id TEXT,
          categoria_otro TEXT,
          descripcion TEXT,
          solicitante_id TEXT,
          responsable_id TEXT,
          estado TEXT,
          criticidad TEXT,
          fecha_tentativa_cierre TEXT,
          subido INTEGER DEFAULT 0,
          eliminado INTEGER DEFAULT 0
        )
      ''');
      debugPrint("✅ Parche v20 aplicado.");
    }
    if (oldVersion < 21) {
      debugPrint("🚀 Aplicando parche v21 (Tabla Empresas)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS empresas (
          id TEXT PRIMARY KEY,
          nombre TEXT
        )
      ''');
      debugPrint("✅ Parche v21 aplicado.");
    }
    if (oldVersion < 22) {
      debugPrint(
        "🚀 Aplicando parche v22 (Centro y Embarcación en Tickets)...",
      );
      await _safeAddColumn(db, "tickets_pendientes", "centro_id", "TEXT");
      await _safeAddColumn(db, "tickets_pendientes", "embarcacion_id", "TEXT");
      debugPrint("✅ Parche v22 aplicado.");
    }
    if (oldVersion < 23) {
      debugPrint("🚀 Aplicando parche v23 (Fecha creación en Tickets)...");
      await _safeAddColumn(db, "tickets_pendientes", "created_at", "TEXT");
      debugPrint("✅ Parche v23 aplicado.");
    }

    if (oldVersion < 24) {
      debugPrint(
        "🚀 Aplicando parche v24 (Horas en Embarcación + PDF offline)...",
      );
      await _safeAddColumn(
        db,
        "verificaciones_embarcacion",
        "hora_inicio",
        "TEXT",
      );
      await _safeAddColumn(
        db,
        "verificaciones_embarcacion",
        "hora_termino",
        "TEXT",
      );
      await _safeAddColumn(
        db,
        "actividades_pendientes",
        "pdf_path_local",
        "TEXT",
      );
      debugPrint("✅ Parche v24 aplicado.");
    }

    if (oldVersion < 25) {
      await _migrateToV25(db);
    }
    if (oldVersion < 26) {
      debugPrint("🚀 Aplicando parche v26 (Relación Área-Empresa)...");
      await _safeAddColumn(db, "areas", "empresa_id", "TEXT");
      debugPrint("✅ Parche v26 aplicado.");
    }
    if (oldVersion < 27) {
      debugPrint("🚀 Aplicando parche v27 (Desnormalizar Rol)...");
      await _safeAddColumn(db, "usuarios", "nombre_rol", "TEXT");
      debugPrint("✅ Parche v27 aplicado.");
    }
    if (oldVersion < 28) {
      debugPrint(
        "🚀 Aplicando parche v28 (Checklists dinámicos de Visitas)...",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS visitas_checklists_pendientes (
          id TEXT PRIMARY KEY,
          visita_id TEXT,
          tipo_checklist TEXT,
          respuestas TEXT,
          subido INTEGER DEFAULT 0
        )
      ''');
      debugPrint("✅ Parche v28 aplicado.");
    }
    // v29: Nueva tabla visita_respuestas_pendientes
    if (oldVersion < 29) {
      debugPrint(
        "🚀 Aplicando parche v29 (Tabla visita_respuestas_pendientes)...",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS visita_respuestas_pendientes (
          id TEXT PRIMARY KEY,
          visita_id TEXT,
          item_id TEXT,
          estado TEXT,
          observacion TEXT,
          subido INTEGER DEFAULT 0
        )
      ''');
      debugPrint("✅ Parche v29 aplicado.");
    }

    // v30: Agregar criticidad y foto_path a visita_respuestas_pendientes
    if (oldVersion < 30) {
      debugPrint(
        "🚀 Aplicando parche v30 (criticidad y foto_path en visita_respuestas_pendientes)...",
      );
      await _safeAddColumn(
        db,
        "visita_respuestas_pendientes",
        "criticidad",
        "TEXT",
      );
      await _safeAddColumn(
        db,
        "visita_respuestas_pendientes",
        "foto_path",
        "TEXT",
      );
      debugPrint("✅ Parche v30 aplicado.");
    }

    // v31: Agregar tipo_actividad a visitas_tecnicas_pendientes
    if (oldVersion < 31) {
      debugPrint(
        "🚀 Aplicando parche v31 (tipo_actividad en visitas_tecnicas_pendientes)...",
      );
      await _safeAddColumn(
        db,
        "visitas_tecnicas_pendientes",
        "tipo_actividad",
        "TEXT",
      );
      debugPrint("✅ Parche v31 aplicado.");
    }

    // v32: Nueva tabla extintores_pendientes (Módulo Inspección Extintores)
    if (oldVersion < 32) {
      debugPrint("🚀 Aplicando parche v32 (Módulo Extintores)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS extintores_pendientes (
          id TEXT PRIMARY KEY,
          visita_id TEXT NOT NULL,
          numero INTEGER NOT NULL,
          matricula TEXT,
          fotos_json TEXT,
          respuestas_json TEXT,
          subido INTEGER DEFAULT 0,
          created_at TEXT
        )
      ''');
      debugPrint("✅ Parche v32 aplicado.");
    }

    if (oldVersion < 33) {
      debugPrint(
        "🚀 Aplicando parche v33 (Normalización RUT + UNIQUE index)...",
      );

      // Paso 1: Normalizar todos los RUTs existentes
      await db.execute("""
        UPDATE personal_externo
        SET rut = REPLACE(REPLACE(REPLACE(LOWER(TRIM(rut)), '.', ''), '-', ''), ' ', '')
        WHERE rut IS NOT NULL AND rut != ''
      """);

      // Paso 2: Resolver duplicados (mantener el que tenga contratista_id)
      final duplicados = await db.rawQuery("""
        SELECT rut, GROUP_CONCAT(id) as ids, COUNT(*) as cnt
        FROM personal_externo
        WHERE rut IS NOT NULL AND rut != ''
        GROUP BY rut HAVING COUNT(*) > 1
      """);

      for (var dup in duplicados) {
        final ids = (dup['ids'] as String).split(',');
        // Buscar el "ganador": preferir el que tenga contratista_id
        String? winnerId;
        for (var id in ids) {
          final rows = await db.query(
            'personal_externo',
            where: 'id = ?',
            whereArgs: [id],
          );
          if (rows.isNotEmpty && rows.first['contratista_id'] != null) {
            winnerId = id;
            break;
          }
        }
        winnerId ??=
            ids.first; // Si ninguno tiene contratista_id, tomar el primero

        // Reasignar referencias y eliminar perdedores
        for (var id in ids) {
          if (id != winnerId) {
            await db.update(
              'actividad_participantes',
              {'personal_id': winnerId},
              where: 'personal_id = ?',
              whereArgs: [id],
            );
            await db.delete(
              'personal_externo',
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }

      // Paso 3: Crear índice UNIQUE
      await db.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_personal_externo_rut
        ON personal_externo(rut) WHERE rut IS NOT NULL AND rut != ''
      """);

      debugPrint("✅ Parche v33 aplicado.");
    }
  }

  Future<void> _migrateToV25(Database db) async {
    debugPrint("🚀 Aplicando parche v25 (Firma Digital en Visitas)...");
    try {
      await db.transaction((txn) async {
        await _safeAddColumn(
          txn,
          "visitas_tecnicas_pendientes",
          "signature_image",
          "BLOB",
        );
      });
      debugPrint("✅ Parche v25 aplicado.");
    } catch (e, st) {
      debugPrint("❌ Error en parche v25: $e\n$st");
      rethrow;
    }
  }

  Future<void> _repairCriticalSchema(Database db) async {
    try {
      await _safeAddColumn(
        db,
        "visitas_tecnicas_pendientes",
        "signature_image",
        "BLOB",
      );
    } catch (e, st) {
      debugPrint("❌ Error reparando esquema crítico: $e\n$st");
      rethrow;
    }
  }

  // Helper seguro para migraciones
  Future<void> _safeAddColumn(
    DatabaseExecutor db,
    String table,
    String column,
    String type,
  ) async {
    try {
      final exists = await _columnExists(db, table, column);
      if (exists) {
        return;
      }

      await db.execute("ALTER TABLE $table ADD COLUMN $column $type");
    } on DatabaseException catch (e) {
      // Ignoramos si se intenta agregar una columna ya existente.
      if (e.toString().toLowerCase().contains("duplicate column name")) {
        return;
      }
      rethrow;
    }
  }

  Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final columns = await db.rawQuery("PRAGMA table_info($table)");
    return columns.any((c) => c['name'] == column);
  }

  // --- MÉTODOS CRUD GENÉRICOS ---

  Future<void> guardarMaestros(
    String tabla,
    List<Map<String, dynamic>> datos,
  ) async {
    // BLINDAJE: Si la lista está vacía, NO toques la base de datos.
    // Así evitamos borrar todo por un error de red que devuelva [].
    if (datos.isEmpty) {
      debugPrint(
        "⚠️ Advertencia: Se intentó guardar lista vacía en $tabla. Operación cancelada.",
      );
      return;
    }

    final db = await database;

    // Usamos UPSERT (replace) en lugar de DELETE + INSERT
    // Esto es más seguro: si fallan algunos registros, no se pierden los demás
    final batch = db.batch();

    for (var item in datos) {
      Map<String, dynamic> row = {};

      row['id'] = item['id'];
      if (tabla == 'personal_externo') {
        row['nombre_completo'] =
            item['nombre_completo'] ?? item['nombre'] ?? 'Sin Nombre';
        final rawRut = (item['rut'] ?? '') as String;
        row['rut'] = rawRut
            .replaceAll(RegExp(r'[\.\-\s\r\n\t\u00AD]'), '')
            .toLowerCase()
            .trim();
        row['cargo'] = item['cargo'];
        row['matricula'] = item['matricula'];
        row['contratista_id'] = item['contratista_id'];
        row['activo'] = (item['activo'] == true || item['activo'] == 1) ? 1 : 0;
      } else if (tabla == 'usuarios') {
        row['rut'] = item['rut'];
        row['nombre_completo'] = item['nombre_completo'];
        row['email'] = item['email'];
        row['telefono'] = item['telefono'];
        row['rol_id'] = item['rol_id'];
        if (item['roles'] != null && item['roles'] is Map) {
          row['nombre_rol'] = item['roles']['nombre'];
        } else {
          row['nombre_rol'] = null;
        }
      } else if (tabla == 'embarcaciones') {
        row['nombre'] = item['nombre'];
        row['contratista_id'] = item['contratista_id'];
        row['matricula'] = item['matricula'];
      } else if (tabla == 'centros') {
        row['nombre'] = item['nombre'];
        row['area_id'] = item['area_id'];
      } else if (tabla == 'areas') {
        // <-- AGREGAR ESTO
        row['nombre'] = item['nombre'];
        row['empresa_id'] = item['empresa_id'];
      } else {
        row['nombre'] = item['nombre'];
      }

      batch.insert(tabla, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint("✅ Maestros guardados en $tabla: ${datos.length} registros");
  }

  Future<List<Map<String, dynamic>>> getAreas() async {
    final db = await instance.database;
    return await db.query('areas', orderBy: 'nombre');
  }

  Future<List<Map<String, dynamic>>> getCentros(String areaId) async {
    final db = await instance.database;
    return await db.query(
      'centros',
      where: 'area_id = ?',
      whereArgs: [areaId],
      orderBy: 'nombre',
    );
  }

  Future<List<Map<String, dynamic>>> getAllCentros() async {
    final db = await instance.database;
    return await db.query('centros', orderBy: 'nombre');
  }

  Future<List<Map<String, dynamic>>> getContratistas() async {
    final db = await instance.database;
    return await db.query('contratistas', orderBy: 'nombre');
  }

  Future<List<Map<String, dynamic>>> getEmbarcaciones(
    String contratistaId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'embarcaciones',
      where: 'contratista_id = ?',
      whereArgs: [contratistaId],
      orderBy: 'nombre',
    );
  }

  Future<void> guardarItemsOffline(List<Map<String, dynamic>> items) async {
    // BLINDAJE: Si la lista está vacía, NO toques la base de datos
    if (items.isEmpty) {
      debugPrint(
        "⚠️ Advertencia: Se intentó guardar lista vacía en formulario_items. Operación cancelada.",
      );
      return;
    }

    final db = await instance.database;
    final batch = db.batch();

    for (var item in items) {
      batch.insert('formulario_items', {
        'id': item['id'],
        'tipo_actividad': item['tipo_actividad'],
        'categoria': item['categoria'],
        'pregunta': item['pregunta'],
        'criticidad': item['criticidad'],
        'orden': item['orden'],
        'activo': (item['activo'] == true) ? 1 : 0,
        'info_adicional': item['info_adicional'],
        'url_imagen_referencia': item['url_imagen_referencia'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    debugPrint("✅ Formulario items guardados: ${items.length} registros");
  }

  Future<void> saveActividadOffline(Map<String, dynamic> actividad) async {
    final db = await instance.database;
    await db.insert(
      'actividades_pendientes',
      actividad,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllEmpresas() async {
    final db = await instance.database;
    return await db.query('empresas', orderBy: 'nombre');
  }

  Future<List<Map<String, dynamic>>> getAllUsuarios() async {
    final db = await instance.database;
    return await db.query('usuarios', orderBy: 'nombre_completo');
  }

  Future<List<Map<String, dynamic>>> getAllEmbarcaciones() async {
    final db = await instance.database;
    return await db.query('embarcaciones', orderBy: 'nombre');
  }

  /// Devuelve todas las actividades no eliminadas que tienen número de reporte,
  /// ordenadas por fecha de realización descendente.
  Future<List<Map<String, dynamic>>> getAllActividades() async {
    final db = await instance.database;
    return await db.query(
      'actividades_pendientes',
      columns: ['id', 'numero_reporte', 'tipo_actividad', 'fecha_realizacion'],
      where:
          'eliminado = 0 AND numero_reporte IS NOT NULL AND numero_reporte != ""',
      orderBy: 'fecha_realizacion DESC',
    );
  }
}
