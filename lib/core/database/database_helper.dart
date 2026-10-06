import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const int _dbVersion =
      60; // Incrementa este número cada vez que hagas un cambio en la estructura de la base de datos
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
        nombre_rol TEXT,
        empresa_id TEXT
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
        url_imagen_referencia TEXT,
        peso REAL DEFAULT 1.0
      )
    ''');

    // 1.b CAMPOS EXTRA POR CHECKLIST (master data, sync con Supabase)
    await db.execute('''
      CREATE TABLE formulario_campos_extra (
        id TEXT PRIMARY KEY,
        tipo_actividad TEXT NOT NULL,
        clave TEXT NOT NULL,
        label TEXT NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'texto',
        orden INTEGER NOT NULL DEFAULT 0,
        requerido INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1,
        UNIQUE (tipo_actividad, clave)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_formulario_campos_extra_tipo
      ON formulario_campos_extra (tipo_actividad)
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
      'CREATE TABLE centros (id TEXT PRIMARY KEY, nombre TEXT, area_id TEXT, subido INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE contratistas (id TEXT PRIMARY KEY, nombre TEXT, rut TEXT, subido INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE empresas (id TEXT PRIMARY KEY, nombre TEXT, es_administradora INTEGER DEFAULT 0, logo_url TEXT)',
    );
    await db.execute('''
      CREATE TABLE empresa_modulos (
        id TEXT PRIMARY KEY,
        empresa_id TEXT NOT NULL,
        modulo_key TEXT NOT NULL,
        habilitado INTEGER NOT NULL DEFAULT 1,
        orden INTEGER NOT NULL DEFAULT 0,
        subido INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_empresa_modulo ON empresa_modulos(empresa_id, modulo_key)',
    );
    await db.execute('''
      CREATE TABLE usuario_empresas (
        id TEXT PRIMARY KEY,
        usuario_id TEXT NOT NULL,
        empresa_id TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_usuario_empresa ON usuario_empresas(usuario_id, empresa_id)',
    );
    // Junction table: N:N entre empresas y areas
    await db.execute('''
      CREATE TABLE empresa_areas (
        id TEXT PRIMARY KEY,
        empresa_id TEXT NOT NULL,
        area_id TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_empresa_area ON empresa_areas(empresa_id, area_id)',
    );
    // Agregamos matricula aquí también por si acaso
    await db.execute(
      'CREATE TABLE embarcaciones (id TEXT PRIMARY KEY, nombre TEXT, contratista_id TEXT, matricula TEXT, subido INTEGER DEFAULT 1)',
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
        estado_faena TEXT,
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
        profesional TEXT,
        fono_profesional TEXT,
        correo_profesional TEXT,
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
        incluir_actividades INTEGER DEFAULT 0,
        campos_extra TEXT,
        otro_actividad_texto TEXT,
        apuntes_observaciones TEXT,
        signature_image BLOB,
        pdf_path_local TEXT,
        pdf_url TEXT,
        tipo_actividad TEXT,
        empresa TEXT,
        lugar_inspeccion TEXT,
        cert_numero TEXT,
        cert_anio INTEGER,
        cert_correlativo INTEGER,
        cliente_nombre TEXT,
        cliente_direccion TEXT,
        fecha_servicio TEXT,
        pdf_certificado_path_local TEXT,
        pdf_certificado_url TEXT
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

    // --- MÓDULO EXTINTORES ---
    await db.execute('''
      CREATE TABLE extintores_pendientes (
        id TEXT PRIMARY KEY,
        visita_id TEXT NOT NULL,
        numero INTEGER NOT NULL,
        matricula TEXT,
        tipo_extintor TEXT,
        peso_extintor TEXT,
        fecha_ultima_mantencion TEXT,
        fecha_proxima_mantencion TEXT,
        fotos_json TEXT,
        respuestas_json TEXT,
        subido INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    // --- MÓDULO PROSESSO (Mantención y Recarga de Extintores) ---
    await db.execute('''
      CREATE TABLE mantenciones_prosesso_pendientes (
        id TEXT PRIMARY KEY,
        visita_id TEXT NOT NULL,
        numero INTEGER NOT NULL,
        planta TEXT,
        ubicacion TEXT,
        ubicacion_sector TEXT,
        ubicacion_2 TEXT,
        certificado TEXT,
        anio INTEGER,
        tipo TEXT,
        peso TEXT,
        kg TEXT,
        fecha_vencimiento TEXT,
        observaciones TEXT,
        respuestas_json TEXT,
        fotos_json TEXT,
        subido INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_mantenciones_prosesso_visita ON mantenciones_prosesso_pendientes(visita_id)',
    );

    // --- MÓDULO HIDROSER (independiente del Registro de Visita) ---
    await db.execute('''
      CREATE TABLE hidroser_listas (
        codigo TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        subtitulo TEXT,
        tipo_formulario_items TEXT NOT NULL,
        icono TEXT,
        orden INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1,
        campos_extra_definicion TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE hidroser_inspecciones_pendientes (
        id TEXT PRIMARY KEY,
        usuario_id TEXT,
        empresa_id TEXT,
        lista_codigo TEXT NOT NULL,
        fecha_realizacion TEXT,
        correlativo TEXT,
        quien_inspecciona TEXT,
        observaciones TEXT,
        campos_extra TEXT,
        firma_supervisor_nombre TEXT,
        firma_operador_nombre TEXT,
        firma_supervisor_image BLOB,
        firma_operador_image BLOB,
        estado_final TEXT NOT NULL DEFAULT 'Borrador',
        pdf_url TEXT,
        pdf_path_local TEXT,
        subido INTEGER NOT NULL DEFAULT 0,
        eliminado INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_hidroser_inspecciones_lista ON hidroser_inspecciones_pendientes(lista_codigo)',
    );
    await db.execute(
      'CREATE INDEX idx_hidroser_inspecciones_estado ON hidroser_inspecciones_pendientes(estado_final)',
    );

    await db.execute('''
      CREATE TABLE hidroser_respuestas_pendientes (
        id TEXT PRIMARY KEY,
        inspeccion_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        estado TEXT,
        observacion TEXT,
        criticidad TEXT,
        foto_path TEXT,
        subido INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_hidroser_respuestas_inspeccion ON hidroser_respuestas_pendientes(inspeccion_id)',
    );

    // --- MÓDULO EQUIPAMIENTO DE BUCEO (independiente) ---
    await db.execute('''
      CREATE TABLE buceo_equipamiento_listas (
        codigo TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        subtitulo TEXT,
        icono TEXT,
        orden INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE buceo_equipamiento_items (
        id TEXT PRIMARY KEY,
        lista_codigo TEXT NOT NULL,
        categoria TEXT NOT NULL,
        pregunta TEXT NOT NULL,
        criticidad TEXT,
        peso INTEGER NOT NULL DEFAULT 1,
        orden INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_buceo_eq_items_lista ON buceo_equipamiento_items(lista_codigo)',
    );
    await db.execute('''
      CREATE TABLE buceo_equipamiento_inspecciones_pendientes (
        id TEXT PRIMARY KEY,
        usuario_id TEXT,
        empresa_id TEXT,
        lista_codigo TEXT NOT NULL,
        fecha_realizacion TEXT,
        correlativo TEXT,
        quien_inspecciona TEXT,
        observaciones TEXT,
        campos_extra TEXT,
        firma_supervisor_nombre TEXT,
        firma_operador_nombre TEXT,
        firma_supervisor_image BLOB,
        firma_operador_image BLOB,
        estado_final TEXT NOT NULL DEFAULT 'Borrador',
        pdf_url TEXT,
        pdf_path_local TEXT,
        subido INTEGER NOT NULL DEFAULT 0,
        eliminado INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_buceo_eq_insp_lista ON buceo_equipamiento_inspecciones_pendientes(lista_codigo)',
    );
    await db.execute(
      'CREATE INDEX idx_buceo_eq_insp_estado ON buceo_equipamiento_inspecciones_pendientes(estado_final)',
    );
    await db.execute('''
      CREATE TABLE buceo_equipamiento_respuestas_pendientes (
        id TEXT PRIMARY KEY,
        inspeccion_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        estado TEXT,
        observacion TEXT,
        criticidad TEXT,
        foto_path TEXT,
        subido INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_buceo_eq_resp_inspeccion ON buceo_equipamiento_respuestas_pendientes(inspeccion_id)',
    );

    // --- MÓDULO AST (Análisis Seguro de Trabajo, independiente) ---
    await db.execute('''
      CREATE TABLE ast_informes_pendientes (
        id TEXT PRIMARY KEY,
        usuario_id TEXT,
        empresa_id TEXT,
        area_id TEXT,
        centro_id TEXT,
        contratista_id TEXT,
        embarcacion_id TEXT,
        area_nombre TEXT,
        centro_nombre TEXT,
        contratista_nombre TEXT,
        embarcacion_nombre TEXT,
        profesional TEXT,
        fecha_realizacion TEXT,
        descripcion_actividad TEXT,
        observaciones TEXT,
        correlativo TEXT,
        estado_final TEXT NOT NULL DEFAULT 'En Progreso',
        pdf_url TEXT,
        pdf_path_local TEXT,
        fotos_generales TEXT,
        subido INTEGER NOT NULL DEFAULT 0,
        eliminado INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_ast_informes_estado ON ast_informes_pendientes(estado_final)',
    );

    await db.execute('''
      CREATE TABLE ast_hallazgos_pendientes (
        id TEXT PRIMARY KEY,
        informe_id TEXT NOT NULL,
        numero INTEGER NOT NULL DEFAULT 0,
        titulo TEXT,
        detalle TEXT,
        foto_path TEXT,
        subido INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_ast_hallazgos_informe ON ast_hallazgos_pendientes(informe_id)',
    );

    // --- MÓDULO MERIEUX (independiente, 2 submódulos: Visitas + Extintores) ---
    await db.execute('''
      CREATE TABLE merieux_visitas_pendientes (
        id TEXT PRIMARY KEY,
        usuario_id TEXT,
        empresa_id TEXT,
        tipo_actividad TEXT NOT NULL,
        checklist_tipo TEXT,
        profesional TEXT,
        fono_profesional TEXT,
        correo_profesional TEXT,
        region TEXT,
        area TEXT,
        jefatura_a_cargo TEXT,
        origen_actividad TEXT,
        fecha_realizacion TEXT,
        hora_inicio TEXT,
        hora_termino TEXT,
        correo_1 TEXT,
        correo_2 TEXT,
        campos_extra TEXT,
        observaciones TEXT,
        correlativo TEXT,
        estado_final TEXT NOT NULL DEFAULT 'En Progreso',
        firma_nombre TEXT,
        signature_image BLOB,
        pdf_url TEXT,
        pdf_path_local TEXT,
        subido INTEGER NOT NULL DEFAULT 0,
        eliminado INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_merieux_visitas_tipo ON merieux_visitas_pendientes(tipo_actividad)',
    );
    await db.execute(
      'CREATE INDEX idx_merieux_visitas_estado ON merieux_visitas_pendientes(estado_final)',
    );

    await db.execute('''
      CREATE TABLE merieux_visita_respuestas_pendientes (
        id TEXT PRIMARY KEY,
        visita_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        estado TEXT,
        observacion TEXT,
        criticidad TEXT,
        foto_path TEXT,
        subido INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_merieux_visita_respuestas_visita ON merieux_visita_respuestas_pendientes(visita_id)',
    );

    await db.execute('''
      CREATE TABLE merieux_extintores_pendientes (
        id TEXT PRIMARY KEY,
        visita_id TEXT NOT NULL,
        numero INTEGER NOT NULL DEFAULT 0,
        planta TEXT,
        ubicacion TEXT,
        ubicacion_sector TEXT,
        ubicacion_2 TEXT,
        certificado TEXT,
        anio INTEGER,
        tipo TEXT,
        peso TEXT,
        kg TEXT,
        fecha_vencimiento TEXT,
        observaciones TEXT,
        respuestas_json TEXT,
        fotos_json TEXT,
        subido INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_merieux_extintores_visita ON merieux_extintores_pendientes(visita_id)',
    );

    // --- MÓDULO CORREO (MVP) ---
    await db.execute('''
      CREATE TABLE correo_plantillas (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        asunto_template TEXT NOT NULL,
        cuerpo_template TEXT NOT NULL,
        modulo TEXT,
        empresa_id TEXT,
        variables_permitidas TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        version INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        updated_by TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE correo_listas (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        proposito TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE correo_lista_destinatarios (
        id TEXT PRIMARY KEY,
        lista_id TEXT NOT NULL,
        nombre TEXT,
        correo TEXT NOT NULL,
        tipo_sugerido TEXT NOT NULL DEFAULT 'to',
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE correo_configuracion (
        id TEXT PRIMARY KEY,
        empresa_id TEXT,
        modulo TEXT NOT NULL,
        plantilla_id TEXT NOT NULL,
        lista_id TEXT NOT NULL,
        prioridad INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE correo_eventos (
        id TEXT PRIMARY KEY,
        inspeccion_id TEXT,
        empresa_id TEXT,
        usuario_id TEXT,
        config_id TEXT,
        lista_id TEXT,
        lista_nombre TEXT,
        event_type TEXT NOT NULL,
        event_timestamp TEXT NOT NULL,
        resultado_evento TEXT NOT NULL,
        canal TEXT,
        template_id TEXT,
        template_nombre TEXT,
        template_version INTEGER,
        regla_envio_nombre TEXT,
        asunto_generado TEXT,
        adjunto_nombre TEXT,
        adjunto_tipo TEXT,
        error_code TEXT,
        error_message TEXT,
        modulo_key TEXT,
        destinatarios_json TEXT,
        destinatarios_count INTEGER,
        subido INTEGER NOT NULL DEFAULT 0,
        ultimo_error_sync TEXT,
        synced_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE correo_pendientes (
        id TEXT PRIMARY KEY,
        registro_id TEXT NOT NULL,
        modulo_key TEXT NOT NULL,
        empresa_id TEXT,
        usuario_id TEXT,
        config_id TEXT,
        lista_id TEXT,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        payload_json TEXT,
        intentos INTEGER NOT NULL DEFAULT 0,
        ultimo_error TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute(
      "CREATE UNIQUE INDEX idx_correo_pendiente_unique ON correo_pendientes(registro_id, modulo_key)",
    );
    await db.execute(
      "CREATE INDEX idx_correo_pendiente_estado ON correo_pendientes(estado, updated_at)",
    );
    await db.execute('''
      CREATE TABLE correo_usuario_asignacion (
        id TEXT PRIMARY KEY,
        usuario_id TEXT NOT NULL,
        config_id TEXT,
        lista_id TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute(
      "CREATE INDEX idx_correo_usuario_asig ON correo_usuario_asignacion(usuario_id, activo)",
    );

    await _createConfigurableChecklistSchema(db);

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

    if (oldVersion < 34) {
      debugPrint(
        "🚀 Aplicando parche v34 (Empresa, Lugar Inspeccion, Tipo Extintor)...",
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'empresa',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'lugar_inspeccion',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'extintores_pendientes',
        'tipo_extintor',
        'TEXT',
      );
      debugPrint("✅ Parche v34 aplicado.");
    }

    if (oldVersion < 35) {
      debugPrint("🚀 Aplicando parche v35 (empresa_id en usuarios)...");
      await _safeAddColumn(db, 'usuarios', 'empresa_id', 'TEXT');
      debugPrint("✅ Parche v35 aplicado.");
    }

    if (oldVersion < 36) {
      debugPrint("🚀 Aplicando parche v36 (empresa_modulos)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS empresa_modulos (
          id TEXT PRIMARY KEY,
          empresa_id TEXT NOT NULL,
          modulo_key TEXT NOT NULL,
          habilitado INTEGER NOT NULL DEFAULT 1,
          orden INTEGER NOT NULL DEFAULT 0,
          subido INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_empresa_modulo ON empresa_modulos(empresa_id, modulo_key)',
      );
      debugPrint("✅ Parche v36 aplicado.");
    }

    if (oldVersion < 37) {
      debugPrint("🚀 Aplicando parche v37 (usuario_empresas multi-tenant)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS usuario_empresas (
          id TEXT PRIMARY KEY,
          usuario_id TEXT NOT NULL,
          empresa_id TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_usuario_empresa ON usuario_empresas(usuario_id, empresa_id)',
      );
      // Migrar datos existentes: usuarios con empresa_id → usuario_empresas
      await db.execute('''
        INSERT OR IGNORE INTO usuario_empresas (id, usuario_id, empresa_id)
        SELECT id || '_emp', id, empresa_id
        FROM usuarios
        WHERE empresa_id IS NOT NULL AND empresa_id != ''
      ''');
      debugPrint("✅ Parche v37 aplicado.");
    }

    if (oldVersion < 38) {
      debugPrint(
        "... Aplicando parche v38 (subido en centros/contratistas/embarcaciones)...",
      );
      await _safeAddColumn(db, 'centros', 'subido', 'INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'contratistas', 'subido', 'INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'embarcaciones', 'subido', 'INTEGER DEFAULT 1');
      debugPrint("✅ Parche v38 aplicado.");
    }

    if (oldVersion < 39) {
      debugPrint("🚀 Aplicando parche v39 (peso en formulario_items)...");
      await _safeAddColumn(db, 'formulario_items', 'peso', 'REAL DEFAULT 1.0');
      debugPrint("✅ Parche v39 aplicado.");
    }

    if (oldVersion < 40) {
      debugPrint("🚀 Aplicando parche v40 (es_administradora en empresas)...");
      await _safeAddColumn(
        db,
        'empresas',
        'es_administradora',
        'INTEGER DEFAULT 0',
      );
      debugPrint("✅ Parche v40 aplicado.");
    }

    if (oldVersion < 41) {
      debugPrint("🚀 Aplicando parche v41 (empresa_areas N:N)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS empresa_areas (
          id TEXT PRIMARY KEY,
          empresa_id TEXT NOT NULL,
          area_id TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_empresa_area ON empresa_areas(empresa_id, area_id)',
      );
      // Seed desde la relación 1:N existente en areas.empresa_id
      await db.execute('''
        INSERT OR IGNORE INTO empresa_areas (id, empresa_id, area_id)
        SELECT id || '_ea', empresa_id, id
        FROM areas
        WHERE empresa_id IS NOT NULL AND empresa_id != ''
      ''');
      debugPrint("✅ Parche v41 aplicado.");
    }

    if (oldVersion < 42) {
      debugPrint("🚀 Aplicando parche v42 (rut en contratistas)...");
      await db.execute("ALTER TABLE contratistas ADD COLUMN rut TEXT");
      debugPrint("✅ Parche v42 aplicado.");
    }

    if (oldVersion < 43) {
      debugPrint(
        "🚀 Aplicando parche v43 (campos adicionales extintores R004)...",
      );
      await _safeAddColumn(
        db,
        'extintores_pendientes',
        'peso_extintor',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'extintores_pendientes',
        'fecha_ultima_mantencion',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'extintores_pendientes',
        'fecha_proxima_mantencion',
        'TEXT',
      );
      debugPrint("✅ Parche v43 aplicado.");
    }

    if (oldVersion < 44) {
      debugPrint("🚀 Aplicando parche v44 (logo_url en empresas)...");
      await _safeAddColumn(db, 'empresas', 'logo_url', 'TEXT');
      debugPrint("✅ Parche v44 aplicado.");
    }

    if (oldVersion < 45) {
      debugPrint("🚀 Aplicando parche v45 (Módulo PROSESSO)...");
      // Tabla nueva
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mantenciones_prosesso_pendientes (
          id TEXT PRIMARY KEY,
          visita_id TEXT NOT NULL,
          numero INTEGER NOT NULL,
          planta TEXT,
          ubicacion TEXT,
          ubicacion_sector TEXT,
          ubicacion_2 TEXT,
          certificado TEXT,
          anio INTEGER,
          tipo TEXT,
          peso TEXT,
          kg TEXT,
          fecha_vencimiento TEXT,
          observaciones TEXT,
          respuestas_json TEXT,
          fotos_json TEXT,
          subido INTEGER DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mantenciones_prosesso_visita ON mantenciones_prosesso_pendientes(visita_id)',
      );
      // Columnas nuevas en visitas_tecnicas_pendientes para el certificado
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'cert_numero',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'cert_anio',
        'INTEGER',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'cert_correlativo',
        'INTEGER',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'cliente_nombre',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'cliente_direccion',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'fecha_servicio',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'pdf_certificado_path_local',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'pdf_certificado_url',
        'TEXT',
      );
      debugPrint("✅ Parche v45 aplicado.");
    }

    if (oldVersion < 46) {
      debugPrint(
        "🚀 Aplicando parche v46 (incluir_actividades opcional en visitas)...",
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'incluir_actividades',
        'INTEGER DEFAULT 0',
      );
      // Backfill: visitas existentes con cualquier check activo se consideran
      // "con bloque de actividades incluido" para no romper PDFs ya guardados.
      await db.execute('''
        UPDATE visitas_tecnicas_pendientes
        SET incluir_actividades = 1
        WHERE COALESCE(check_reunion, 0) = 1
           OR COALESCE(check_instalacion_senaletica, 0) = 1
           OR COALESCE(check_capacitacion, 0) = 1
           OR COALESCE(check_visita_sso, 0) = 1
           OR COALESCE(check_charla, 0) = 1
           OR COALESCE(check_investigacion_incidente, 0) = 1
           OR COALESCE(check_inspeccion_sso, 0) = 1
           OR COALESCE(check_obs_conductual, 0) = 1
           OR COALESCE(check_otro, 0) = 1
      ''');
      debugPrint("✅ Parche v46 aplicado.");
    }

    if (oldVersion < 47) {
      debugPrint(
        "🚀 Aplicando parche v47 (campos extra por checklist en visitas)...",
      );
      // Columna JSON (TEXT) con los valores ingresados
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'campos_extra',
        'TEXT',
      );
      // Tabla maestra de definiciones (se rellena en cada sync)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS formulario_campos_extra (
          id TEXT PRIMARY KEY,
          tipo_actividad TEXT NOT NULL,
          clave TEXT NOT NULL,
          label TEXT NOT NULL,
          tipo TEXT NOT NULL DEFAULT 'texto',
          orden INTEGER NOT NULL DEFAULT 0,
          requerido INTEGER NOT NULL DEFAULT 0,
          activo INTEGER NOT NULL DEFAULT 1,
          UNIQUE (tipo_actividad, clave)
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_formulario_campos_extra_tipo
        ON formulario_campos_extra (tipo_actividad)
      ''');
      debugPrint("✅ Parche v47 aplicado.");
    }

    if (oldVersion < 48) {
      debugPrint("🚀 Aplicando parche v48 (Módulo Hidroser independiente)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hidroser_listas (
          codigo TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          subtitulo TEXT,
          tipo_formulario_items TEXT NOT NULL,
          icono TEXT,
          orden INTEGER NOT NULL DEFAULT 0,
          activo INTEGER NOT NULL DEFAULT 1,
          campos_extra_definicion TEXT NOT NULL DEFAULT '[]'
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hidroser_inspecciones_pendientes (
          id TEXT PRIMARY KEY,
          usuario_id TEXT,
          empresa_id TEXT,
          lista_codigo TEXT NOT NULL,
          fecha_realizacion TEXT,
          correlativo TEXT,
          quien_inspecciona TEXT,
          observaciones TEXT,
          campos_extra TEXT,
          firma_supervisor_nombre TEXT,
          firma_operador_nombre TEXT,
          firma_supervisor_image BLOB,
          firma_operador_image BLOB,
          estado_final TEXT NOT NULL DEFAULT 'Borrador',
          pdf_url TEXT,
          pdf_path_local TEXT,
          subido INTEGER NOT NULL DEFAULT 0,
          eliminado INTEGER NOT NULL DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hidroser_inspecciones_lista ON hidroser_inspecciones_pendientes(lista_codigo)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hidroser_inspecciones_estado ON hidroser_inspecciones_pendientes(estado_final)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hidroser_respuestas_pendientes (
          id TEXT PRIMARY KEY,
          inspeccion_id TEXT NOT NULL,
          item_id TEXT NOT NULL,
          estado TEXT,
          observacion TEXT,
          criticidad TEXT,
          foto_path TEXT,
          subido INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hidroser_respuestas_inspeccion ON hidroser_respuestas_pendientes(inspeccion_id)',
      );
      debugPrint("✅ Parche v48 aplicado.");
    }

    if (oldVersion < 49) {
      debugPrint("🚀 Aplicando parche v49 (Módulo AST)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ast_informes_pendientes (
          id TEXT PRIMARY KEY,
          usuario_id TEXT,
          empresa_id TEXT,
          area_id TEXT,
          centro_id TEXT,
          contratista_id TEXT,
          embarcacion_id TEXT,
          area_nombre TEXT,
          centro_nombre TEXT,
          contratista_nombre TEXT,
          embarcacion_nombre TEXT,
          profesional TEXT,
          fecha_realizacion TEXT,
          descripcion_actividad TEXT,
          observaciones TEXT,
          correlativo TEXT,
          estado_final TEXT NOT NULL DEFAULT 'En Progreso',
          pdf_url TEXT,
          pdf_path_local TEXT,
          fotos_generales TEXT,
          subido INTEGER NOT NULL DEFAULT 0,
          eliminado INTEGER NOT NULL DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ast_informes_estado ON ast_informes_pendientes(estado_final)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ast_hallazgos_pendientes (
          id TEXT PRIMARY KEY,
          informe_id TEXT NOT NULL,
          numero INTEGER NOT NULL DEFAULT 0,
          titulo TEXT,
          detalle TEXT,
          foto_path TEXT,
          subido INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ast_hallazgos_informe ON ast_hallazgos_pendientes(informe_id)',
      );
      debugPrint("✅ Parche v49 aplicado.");
    }

    if (oldVersion < 50) {
      debugPrint(
        "🚀 Aplicando parche v50 (Módulo Equipamiento de Buceo independiente)...",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS buceo_equipamiento_listas (
          codigo TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          subtitulo TEXT,
          icono TEXT,
          orden INTEGER NOT NULL DEFAULT 0,
          activo INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS buceo_equipamiento_items (
          id TEXT PRIMARY KEY,
          lista_codigo TEXT NOT NULL,
          categoria TEXT NOT NULL,
          pregunta TEXT NOT NULL,
          criticidad TEXT,
          peso INTEGER NOT NULL DEFAULT 1,
          orden INTEGER NOT NULL DEFAULT 0,
          activo INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_buceo_eq_items_lista ON buceo_equipamiento_items(lista_codigo)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS buceo_equipamiento_inspecciones_pendientes (
          id TEXT PRIMARY KEY,
          usuario_id TEXT,
          empresa_id TEXT,
          lista_codigo TEXT NOT NULL,
          fecha_realizacion TEXT,
          correlativo TEXT,
          quien_inspecciona TEXT,
          observaciones TEXT,
          campos_extra TEXT,
          firma_supervisor_nombre TEXT,
          firma_operador_nombre TEXT,
          firma_supervisor_image BLOB,
          firma_operador_image BLOB,
          estado_final TEXT NOT NULL DEFAULT 'Borrador',
          pdf_url TEXT,
          pdf_path_local TEXT,
          subido INTEGER NOT NULL DEFAULT 0,
          eliminado INTEGER NOT NULL DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_buceo_eq_insp_lista ON buceo_equipamiento_inspecciones_pendientes(lista_codigo)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_buceo_eq_insp_estado ON buceo_equipamiento_inspecciones_pendientes(estado_final)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS buceo_equipamiento_respuestas_pendientes (
          id TEXT PRIMARY KEY,
          inspeccion_id TEXT NOT NULL,
          item_id TEXT NOT NULL,
          estado TEXT,
          observacion TEXT,
          criticidad TEXT,
          foto_path TEXT,
          subido INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_buceo_eq_resp_inspeccion ON buceo_equipamiento_respuestas_pendientes(inspeccion_id)',
      );
      debugPrint("✅ Parche v50 aplicado.");
    }

    if (oldVersion < 51) {
      debugPrint(
        "🚀 Aplicando parche v51 (Módulo Tickets rediseñado: 100% online, sin tablas locales)...",
      );
      // El nuevo módulo de Tickets vive solo en Supabase (ver docs/planificacion/02_en_progreso/PLAN_TICKETS_MVP.md).
      // Se eliminan las tablas locales del diseño viejo (ticket_categorias, tickets_pendientes).
      await db.execute('DROP TABLE IF EXISTS ticket_categorias');
      await db.execute('DROP TABLE IF EXISTS tickets_pendientes');
      debugPrint("✅ Parche v51 aplicado.");
    }

    if (oldVersion < 52) {
      debugPrint(
        "🚀 Aplicando parche v52 (Módulo Merieux: Visitas + Extintores, independiente)...",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS merieux_visitas_pendientes (
          id TEXT PRIMARY KEY,
          usuario_id TEXT,
          empresa_id TEXT,
          tipo_actividad TEXT NOT NULL,
          checklist_tipo TEXT,
          profesional TEXT,
          fono_profesional TEXT,
          correo_profesional TEXT,
          region TEXT,
          area TEXT,
          jefatura_a_cargo TEXT,
          origen_actividad TEXT,
          fecha_realizacion TEXT,
          hora_inicio TEXT,
          hora_termino TEXT,
          correo_1 TEXT,
          correo_2 TEXT,
          campos_extra TEXT,
          observaciones TEXT,
          correlativo TEXT,
          estado_final TEXT NOT NULL DEFAULT 'En Progreso',
          signature_image BLOB,
          pdf_url TEXT,
          pdf_path_local TEXT,
          subido INTEGER NOT NULL DEFAULT 0,
          eliminado INTEGER NOT NULL DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_merieux_visitas_tipo ON merieux_visitas_pendientes(tipo_actividad)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_merieux_visitas_estado ON merieux_visitas_pendientes(estado_final)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS merieux_visita_respuestas_pendientes (
          id TEXT PRIMARY KEY,
          visita_id TEXT NOT NULL,
          item_id TEXT NOT NULL,
          estado TEXT,
          observacion TEXT,
          criticidad TEXT,
          foto_path TEXT,
          subido INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_merieux_visita_respuestas_visita ON merieux_visita_respuestas_pendientes(visita_id)',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS merieux_extintores_pendientes (
          id TEXT PRIMARY KEY,
          visita_id TEXT NOT NULL,
          numero INTEGER NOT NULL DEFAULT 0,
          planta TEXT,
          ubicacion TEXT,
          ubicacion_sector TEXT,
          ubicacion_2 TEXT,
          certificado TEXT,
          anio INTEGER,
          tipo TEXT,
          peso TEXT,
          kg TEXT,
          fecha_vencimiento TEXT,
          observaciones TEXT,
          respuestas_json TEXT,
          fotos_json TEXT,
          subido INTEGER NOT NULL DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_merieux_extintores_visita ON merieux_extintores_pendientes(visita_id)',
      );
      debugPrint("✅ Parche v52 aplicado.");
    }

    if (oldVersion < 53) {
      debugPrint(
        "🚀 Aplicando parche v53 (Merieux: nombre editable de firma)...",
      );
      await db.transaction((txn) async {
        await _safeAddColumn(
          txn,
          "merieux_visitas_pendientes",
          "firma_nombre",
          "TEXT",
        );
      });
      debugPrint("✅ Parche v53 aplicado.");
    }

    if (oldVersion < 54) {
      debugPrint("🚀 Aplicando parche v54 (Módulo correo)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_plantillas (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          asunto_template TEXT NOT NULL,
          cuerpo_template TEXT NOT NULL,
          modulo TEXT,
          empresa_id TEXT,
          variables_permitidas TEXT,
          activo INTEGER NOT NULL DEFAULT 1,
          version INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          updated_by TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_listas (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          proposito TEXT,
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_lista_destinatarios (
          id TEXT PRIMARY KEY,
          lista_id TEXT NOT NULL,
          nombre TEXT,
          correo TEXT NOT NULL,
          tipo_sugerido TEXT NOT NULL DEFAULT 'to',
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_configuracion (
          id TEXT PRIMARY KEY,
          empresa_id TEXT,
          modulo TEXT NOT NULL,
          plantilla_id TEXT NOT NULL,
          lista_id TEXT NOT NULL,
          prioridad INTEGER NOT NULL DEFAULT 0,
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_eventos (
          id TEXT PRIMARY KEY,
          inspeccion_id TEXT,
          empresa_id TEXT,
          usuario_id TEXT,
          event_type TEXT NOT NULL,
          event_timestamp TEXT NOT NULL,
          resultado_evento TEXT NOT NULL,
          canal TEXT,
          template_id TEXT,
          template_version INTEGER,
          asunto_generado TEXT,
          adjunto_nombre TEXT,
          adjunto_tipo TEXT,
          error_code TEXT,
          error_message TEXT
        )
      ''');
      debugPrint("✅ Parche v54 aplicado.");
    }

    if (oldVersion < 55) {
      debugPrint("🚀 Aplicando parche v55 (Cola de correos offline)...");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_pendientes (
          id TEXT PRIMARY KEY,
          registro_id TEXT NOT NULL,
          modulo_key TEXT NOT NULL,
          empresa_id TEXT,
          usuario_id TEXT,
          config_id TEXT,
          lista_id TEXT,
          estado TEXT NOT NULL DEFAULT 'pendiente',
          payload_json TEXT,
          intentos INTEGER NOT NULL DEFAULT 0,
          ultimo_error TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_correo_pendiente_unique ON correo_pendientes(registro_id, modulo_key)",
      );
      await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_correo_pendiente_estado ON correo_pendientes(estado, updated_at)",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_usuario_asignacion (
          id TEXT PRIMARY KEY,
          usuario_id TEXT NOT NULL,
          config_id TEXT,
          lista_id TEXT,
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_correo_usuario_asig ON correo_usuario_asignacion(usuario_id, activo)",
      );
      debugPrint("✅ Parche v55 aplicado.");
    }

    if (oldVersion < 56) {
      debugPrint(
        "🚀 Aplicando parche v56 (metadatos legibles en correo_eventos)...",
      );
      await _safeAddColumn(db, 'correo_eventos', 'config_id', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'lista_id', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'lista_nombre', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'template_nombre', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'regla_envio_nombre', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'modulo_key', 'TEXT');
      debugPrint("✅ Parche v56 aplicado.");
    }

    if (oldVersion < 57) {
      debugPrint("🚀 Aplicando parche v57 (estado final de faena)...");
      await _safeAddColumn(
        db,
        'actividades_pendientes',
        'estado_faena',
        'TEXT',
      );
      debugPrint("✅ Parche v57 aplicado.");
    }

    if (oldVersion < 58) {
      debugPrint("🚀 Aplicando parche v58 (métricas y sync de correos)...");
      await _safeAddColumn(db, 'correo_eventos', 'config_id', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'lista_id', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'lista_nombre', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'template_nombre', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'regla_envio_nombre', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'destinatarios_json', 'TEXT');
      await _safeAddColumn(
        db,
        'correo_eventos',
        'destinatarios_count',
        'INTEGER',
      );
      await _safeAddColumn(
        db,
        'correo_eventos',
        'subido',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _safeAddColumn(db, 'correo_eventos', 'ultimo_error_sync', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'synced_at', 'TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_correo_eventos_sync ON correo_eventos(subido, event_timestamp)',
      );
      debugPrint("✅ Parche v58 aplicado.");
    }

    if (oldVersion < 59) {
      debugPrint("🚀 Aplicando parche v59 (identidad manual de visitas)...");
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'profesional',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'fono_profesional',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'visitas_tecnicas_pendientes',
        'correo_profesional',
        'TEXT',
      );
      debugPrint("✅ Parche v59 aplicado.");
    }

    if (oldVersion < 60) {
      debugPrint(
        "🚀 Aplicando parche v60 (motor de checklists configurables)...",
      );
      await _createConfigurableChecklistSchema(db);
      debugPrint("✅ Parche v60 aplicado.");
    }
  }

  Future<void> _createConfigurableChecklistSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_form_types (
        form_type_key TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        pdf_template_key TEXT NOT NULL,
        permite_respuestas INTEGER NOT NULL DEFAULT 1,
        permite_fotos INTEGER NOT NULL DEFAULT 1,
        permite_firma INTEGER NOT NULL DEFAULT 1,
        requiere_observacion_nc INTEGER NOT NULL DEFAULT 0,
        requiere_foto_nc INTEGER NOT NULL DEFAULT 0,
        usa_criticidad INTEGER NOT NULL DEFAULT 0,
        requiere_criticidad_nc INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1,
        version INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklists (
        checklist_key TEXT PRIMARY KEY,
        form_type_key TEXT NOT NULL,
        permission_key TEXT NOT NULL,
        report_prefix TEXT NOT NULL,
        nombre TEXT NOT NULL,
        subtitulo TEXT,
        icono TEXT,
        color TEXT,
        published_version INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_versions (
        id TEXT PRIMARY KEY,
        checklist_key TEXT NOT NULL,
        version INTEGER NOT NULL,
        estado TEXT NOT NULL,
        snapshot_preguntas TEXT NOT NULL DEFAULT '[]',
        snapshot_campos_extra TEXT NOT NULL DEFAULT '[]',
        snapshot_reglas TEXT NOT NULL DEFAULT '{}',
        published_at TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_navigation_nodes (
        node_key TEXT PRIMARY KEY,
        empresa_id TEXT NOT NULL,
        parent_node_key TEXT,
        node_type TEXT NOT NULL,
        checklist_key TEXT,
        permission_key TEXT NOT NULL,
        titulo TEXT NOT NULL,
        icono TEXT,
        color TEXT,
        orden INTEGER NOT NULL DEFAULT 0,
        habilitado INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_permission_grants (
        id TEXT PRIMARY KEY,
        empresa_id TEXT NOT NULL,
        checklist_key TEXT NOT NULL,
        usuario_id TEXT,
        rol_id TEXT,
        capacidad TEXT NOT NULL,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_inspecciones_pendientes (
        id TEXT PRIMARY KEY,
        usuario_id TEXT NOT NULL,
        empresa_id TEXT NOT NULL,
        checklist_key TEXT NOT NULL,
        form_type_key TEXT NOT NULL,
        version_id TEXT,
        version INTEGER NOT NULL,
        snapshot TEXT NOT NULL DEFAULT '{}',
        fecha_realizacion TEXT,
        correlativo TEXT,
        quien_inspecciona TEXT,
        supervisor_correo TEXT,
        observaciones TEXT,
        campos_extra TEXT NOT NULL DEFAULT '{}',
        firma_nombre TEXT,
        firma_local_path TEXT,
        estado_final TEXT NOT NULL DEFAULT 'Borrador',
        pdf_url TEXT,
        pdf_path_local TEXT,
        subido INTEGER NOT NULL DEFAULT 0,
        eliminado INTEGER NOT NULL DEFAULT 0,
        codigo_error TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_respuestas_pendientes (
        id TEXT PRIMARY KEY,
        inspeccion_id TEXT NOT NULL,
        item_key TEXT NOT NULL,
        categoria TEXT,
        pregunta TEXT NOT NULL,
        orden INTEGER NOT NULL DEFAULT 0,
        estado TEXT,
        observacion TEXT,
        criticidad TEXT,
        subido INTEGER NOT NULL DEFAULT 0,
        UNIQUE (inspeccion_id, item_key)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_evidencias_pendientes (
        id TEXT PRIMARY KEY,
        inspeccion_id TEXT NOT NULL,
        respuesta_id TEXT,
        tipo TEXT NOT NULL,
        local_path TEXT NOT NULL,
        storage_path TEXT,
        orden INTEGER NOT NULL DEFAULT 0,
        metadata TEXT NOT NULL DEFAULT '{}',
        subido INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // Valores de campos dinámicos (catálogo `checklist_campo_definiciones` +
    // asignación por checklist en Supabase; espejo local solo de VALORES,
    // ya que el catálogo viaja embebido en `checklist_versions.snapshot_campos_extra`).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_campo_valores_pendientes (
        id TEXT PRIMARY KEY,
        inspeccion_id TEXT NOT NULL,
        campo_id TEXT NOT NULL,
        clave TEXT NOT NULL,
        tipo TEXT NOT NULL,
        valor_texto TEXT,
        valor_numero REAL,
        valor_fecha TEXT,
        valor_booleano INTEGER,
        subido INTEGER NOT NULL DEFAULT 0,
        UNIQUE (inspeccion_id, campo_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_checklist_nodes_empresa ON checklist_navigation_nodes(empresa_id, habilitado, orden)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_checklist_insp_estado ON checklist_inspecciones_pendientes(estado_final, eliminado, subido)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_checklist_resp_insp ON checklist_respuestas_pendientes(inspeccion_id, orden)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_checklist_evidencias_insp ON checklist_evidencias_pendientes(inspeccion_id, tipo, orden)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_checklist_campo_valores_insp ON checklist_campo_valores_pendientes(inspeccion_id)',
    );
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
      // El repair tambien cubre upgrades interrumpidos antes de v60.
      await _createConfigurableChecklistSchema(db);
      await _safeAddColumn(
        db,
        "visitas_tecnicas_pendientes",
        "signature_image",
        "BLOB",
      );
      await _safeAddColumn(db, "contratistas", "rut", "TEXT");
      await _safeAddColumn(
        db,
        'actividades_pendientes',
        'estado_faena',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'extintores_pendientes',
        'tipo_extintor',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'extintores_pendientes',
        'peso_extintor',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'extintores_pendientes',
        'fecha_ultima_mantencion',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'extintores_pendientes',
        'fecha_proxima_mantencion',
        'TEXT',
      );

      // Módulo AST: aseguramos tablas aunque un upgrade previo se interrumpiera.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ast_informes_pendientes (
          id TEXT PRIMARY KEY,
          usuario_id TEXT,
          empresa_id TEXT,
          area_id TEXT,
          centro_id TEXT,
          contratista_id TEXT,
          embarcacion_id TEXT,
          area_nombre TEXT,
          centro_nombre TEXT,
          contratista_nombre TEXT,
          embarcacion_nombre TEXT,
          profesional TEXT,
          fecha_realizacion TEXT,
          descripcion_actividad TEXT,
          observaciones TEXT,
          correlativo TEXT,
          estado_final TEXT NOT NULL DEFAULT 'En Progreso',
          pdf_url TEXT,
          pdf_path_local TEXT,
          fotos_generales TEXT,
          subido INTEGER NOT NULL DEFAULT 0,
          eliminado INTEGER NOT NULL DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ast_hallazgos_pendientes (
          id TEXT PRIMARY KEY,
          informe_id TEXT NOT NULL,
          numero INTEGER NOT NULL DEFAULT 0,
          titulo TEXT,
          detalle TEXT,
          foto_path TEXT,
          subido INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Módulo Equipamiento de Buceo: aseguramos tablas aunque un upgrade
      // previo se interrumpiera.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS buceo_equipamiento_listas (
          codigo TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          subtitulo TEXT,
          icono TEXT,
          orden INTEGER NOT NULL DEFAULT 0,
          activo INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS buceo_equipamiento_items (
          id TEXT PRIMARY KEY,
          lista_codigo TEXT NOT NULL,
          categoria TEXT NOT NULL,
          pregunta TEXT NOT NULL,
          criticidad TEXT,
          peso INTEGER NOT NULL DEFAULT 1,
          orden INTEGER NOT NULL DEFAULT 0,
          activo INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS buceo_equipamiento_inspecciones_pendientes (
          id TEXT PRIMARY KEY,
          usuario_id TEXT,
          empresa_id TEXT,
          lista_codigo TEXT NOT NULL,
          fecha_realizacion TEXT,
          correlativo TEXT,
          quien_inspecciona TEXT,
          observaciones TEXT,
          campos_extra TEXT,
          firma_supervisor_nombre TEXT,
          firma_operador_nombre TEXT,
          firma_supervisor_image BLOB,
          firma_operador_image BLOB,
          estado_final TEXT NOT NULL DEFAULT 'Borrador',
          pdf_url TEXT,
          pdf_path_local TEXT,
          subido INTEGER NOT NULL DEFAULT 0,
          eliminado INTEGER NOT NULL DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS buceo_equipamiento_respuestas_pendientes (
          id TEXT PRIMARY KEY,
          inspeccion_id TEXT NOT NULL,
          item_id TEXT NOT NULL,
          estado TEXT,
          observacion TEXT,
          criticidad TEXT,
          foto_path TEXT,
          subido INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Módulo Correo: asegurar esquema aunque no haya corrido onUpgrade.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_plantillas (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          asunto_template TEXT NOT NULL,
          cuerpo_template TEXT NOT NULL,
          modulo TEXT,
          empresa_id TEXT,
          variables_permitidas TEXT,
          activo INTEGER NOT NULL DEFAULT 1,
          version INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          updated_by TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_listas (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          proposito TEXT,
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_lista_destinatarios (
          id TEXT PRIMARY KEY,
          lista_id TEXT NOT NULL,
          nombre TEXT,
          correo TEXT NOT NULL,
          tipo_sugerido TEXT NOT NULL DEFAULT 'to',
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_configuracion (
          id TEXT PRIMARY KEY,
          empresa_id TEXT,
          modulo TEXT NOT NULL,
          plantilla_id TEXT NOT NULL,
          lista_id TEXT NOT NULL,
          prioridad INTEGER NOT NULL DEFAULT 0,
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_eventos (
          id TEXT PRIMARY KEY,
          inspeccion_id TEXT,
          empresa_id TEXT,
          usuario_id TEXT,
          config_id TEXT,
          lista_id TEXT,
          lista_nombre TEXT,
          event_type TEXT NOT NULL,
          event_timestamp TEXT NOT NULL,
          resultado_evento TEXT NOT NULL,
          canal TEXT,
          template_id TEXT,
          template_nombre TEXT,
          template_version INTEGER,
          regla_envio_nombre TEXT,
          asunto_generado TEXT,
          adjunto_nombre TEXT,
          adjunto_tipo TEXT,
          error_code TEXT,
          error_message TEXT
        )
      ''');
      await _safeAddColumn(db, 'correo_eventos', 'config_id', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'lista_id', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'lista_nombre', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'template_nombre', 'TEXT');
      await _safeAddColumn(db, 'correo_eventos', 'regla_envio_nombre', 'TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_pendientes (
          id TEXT PRIMARY KEY,
          registro_id TEXT NOT NULL,
          modulo_key TEXT NOT NULL,
          empresa_id TEXT,
          usuario_id TEXT,
          config_id TEXT,
          lista_id TEXT,
          estado TEXT NOT NULL DEFAULT 'pendiente',
          payload_json TEXT,
          intentos INTEGER NOT NULL DEFAULT 0,
          ultimo_error TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_correo_pendiente_unique ON correo_pendientes(registro_id, modulo_key)",
      );
      await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_correo_pendiente_estado ON correo_pendientes(estado, updated_at)",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS correo_usuario_asignacion (
          id TEXT PRIMARY KEY,
          usuario_id TEXT NOT NULL,
          config_id TEXT,
          lista_id TEXT,
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_correo_usuario_asig ON correo_usuario_asignacion(usuario_id, activo)",
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

  /// [scopeWhere] y [scopeArgs] limitan el DELETE de huérfanos a un subconjunto.
  /// Ejemplo: para areas filtradas por empresa, pasas
  /// scopeWhere='empresa_id = ?' scopeArgs=['uuid-empresa']
  /// Así solo borra areas de ESA empresa que ya no estén en el remote.
  Future<void> guardarMaestros(
    String tabla,
    List<Map<String, dynamic>> datos, {
    String? scopeWhere,
    List<Object?>? scopeArgs,
  }) async {
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
        row['empresa_id'] = item['empresa_id'];
        if (item['roles'] != null && item['roles'] is Map) {
          row['nombre_rol'] = item['roles']['nombre'];
        } else {
          row['nombre_rol'] = null;
        }
      } else if (tabla == 'embarcaciones') {
        row['nombre'] = item['nombre'];
        row['contratista_id'] = item['contratista_id'];
        row['matricula'] = item['matricula'];
        row['subido'] = 1;
      } else if (tabla == 'centros') {
        row['nombre'] = item['nombre'];
        row['area_id'] = item['area_id'];
        row['subido'] = 1;
      } else if (tabla == 'areas') {
        // <-- AGREGAR ESTO
        row['nombre'] = item['nombre'];
        row['empresa_id'] = item['empresa_id'];
      } else if (tabla == 'empresa_modulos') {
        row['empresa_id'] = item['empresa_id'];
        row['modulo_key'] = item['modulo_key'];
        row['habilitado'] =
            (item['habilitado'] == true || item['habilitado'] == 1) ? 1 : 0;
        row['orden'] = item['orden'] ?? 0;
        row['subido'] = 1;
      } else if (tabla == 'usuario_empresas') {
        row['usuario_id'] = item['usuario_id'];
        row['empresa_id'] = item['empresa_id'];
      } else if (tabla == 'empresa_areas') {
        row['empresa_id'] = item['empresa_id'];
        row['area_id'] = item['area_id'];
      } else if (tabla == 'contratistas') {
        row['nombre'] = item['nombre'];
        row['rut'] = item['rut'];
        row['subido'] = 1;
      } else if (tabla == 'empresas') {
        row['nombre'] = item['nombre'];
        row['es_administradora'] =
            (item['es_administradora'] == true ||
                item['es_administradora'] == 1)
            ? 1
            : 0;
        row['logo_url'] = item['logo_url'];
      } else {
        row['nombre'] = item['nombre'];
      }

      batch.insert(tabla, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);

    // Eliminar registros locales que ya no existen en Supabase
    // Si hay scopeWhere, solo borramos huérfanos DENTRO de ese scope
    // (ej: solo áreas de la empresa activa, no de otras empresas)
    final idsRemoto = datos.map((e) => e['id'] as String).toList();
    final placeholders = List.filled(idsRemoto.length, '?').join(',');

    String whereClause = 'id NOT IN ($placeholders)';
    List<Object?> whereArgs = [...idsRemoto];

    if (scopeWhere != null) {
      whereClause = '($whereClause) AND ($scopeWhere)';
      if (scopeArgs != null) whereArgs.addAll(scopeArgs);
    }

    // Proteger registros creados localmente que aún no se han subido
    final hasSubido = await _columnExists(db, tabla, 'subido');
    if (hasSubido) {
      whereClause = '($whereClause) AND (subido = 1)';
    }

    final borrados = await db.delete(
      tabla,
      where: whereClause,
      whereArgs: whereArgs,
    );
    if (borrados > 0) {
      debugPrint("🗑️ $tabla: $borrados registros obsoletos eliminados");
    }

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

    // DELETE + re-insert para eliminar items borrados en Supabase
    batch.delete('formulario_items');

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
        'peso': (item['peso'] as num?)?.toDouble() ?? 1.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    debugPrint("✅ Formulario items guardados: ${items.length} registros");
  }

  /// Reescribe la tabla maestra de campos extra por checklist.
  /// Recibe la lista cruda tal como llega desde Supabase.
  Future<void> guardarCamposExtraOffline(
    List<Map<String, dynamic>> defs,
  ) async {
    final db = await instance.database;
    final batch = db.batch();
    batch.delete('formulario_campos_extra');
    for (var d in defs) {
      batch.insert('formulario_campos_extra', {
        'id': d['id']?.toString() ?? '',
        'tipo_actividad': d['tipo_actividad'],
        'clave': d['clave'],
        'label': d['label'],
        'tipo': (d['tipo'] ?? 'texto').toString(),
        'orden': (d['orden'] is num) ? (d['orden'] as num).toInt() : 0,
        'requerido': (d['requerido'] == true) ? 1 : 0,
        'activo': (d['activo'] == false) ? 0 : 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    debugPrint("✅ Campos extra de checklist guardados: ${defs.length}");
  }

  /// Obtiene los campos extra activos para un tipo de checklist (ordenados).
  Future<List<Map<String, dynamic>>> getCamposExtraByTipo(
    String tipoActividad,
  ) async {
    final db = await instance.database;
    return await db.query(
      'formulario_campos_extra',
      where: 'tipo_actividad = ? AND activo = 1',
      whereArgs: [tipoActividad],
      orderBy: 'orden ASC',
    );
  }

  Map<String, dynamic> _navigationNodeRow(Map<String, dynamic> row) => {
    'node_key': row['node_key'],
    'empresa_id': row['empresa_id'],
    'parent_node_key': row['parent_node_key'],
    'node_type': row['node_type'],
    'checklist_key': row['checklist_key'],
    'permission_key': row['permission_key'],
    'titulo': row['titulo'],
    'icono': row['icono'],
    'color': row['color'],
    'orden': row['orden'] ?? 0,
    'habilitado': _boolInt(row['habilitado']),
    'updated_at': row['updated_at']?.toString(),
  };

  /// Reemplaza el espejo local de nodos de navegacion de una empresa.
  /// Lo usa el panel de administracion para que Inicio refleje el cambio en
  /// el acto, sin esperar a la proxima descarga de datos maestros.
  Future<void> reemplazarNavigationNodesEmpresa(
    String empresaId,
    List<Map<String, dynamic>> nodes,
  ) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'checklist_navigation_nodes',
        where: 'empresa_id = ?',
        whereArgs: [empresaId],
      );
      for (final row in nodes) {
        await txn.insert(
          'checklist_navigation_nodes',
          _navigationNodeRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Guarda el catalogo configurable sin borrar el ultimo catalogo valido
  /// cuando una descarga llega vacia durante una sesion offline.
  ///
  /// [navigationNodes] en `null` significa "no se pudo descargar" (se conserva
  /// lo local); una lista vacia SI borra los nodos locales de la empresa.
  Future<void> guardarChecklistCatalogoOffline({
    required List<Map<String, dynamic>> formTypes,
    required List<Map<String, dynamic>> checklists,
    required List<Map<String, dynamic>> versions,
    required List<Map<String, dynamic>>? navigationNodes,
    required List<Map<String, dynamic>> permissionGrants,
    String? empresaId,
    String? usuarioId,
  }) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      if (formTypes.isNotEmpty) {
        await txn.delete('checklist_form_types');
        for (final row in formTypes) {
          await txn.insert('checklist_form_types', {
            'form_type_key': row['form_type_key'],
            'nombre': row['nombre'],
            'descripcion': row['descripcion'],
            'pdf_template_key': row['pdf_template_key'],
            'permite_respuestas': _boolInt(row['permite_respuestas']),
            'permite_fotos': _boolInt(row['permite_fotos']),
            'permite_firma': _boolInt(row['permite_firma']),
            'requiere_observacion_nc': _boolInt(row['requiere_observacion_nc']),
            'requiere_foto_nc': _boolInt(row['requiere_foto_nc']),
            'usa_criticidad': _boolInt(row['usa_criticidad']),
            'requiere_criticidad_nc': _boolInt(row['requiere_criticidad_nc']),
            'activo': _boolInt(row['activo']),
            'version': row['version'] ?? 1,
            'updated_at': row['updated_at']?.toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (checklists.isNotEmpty) {
        await txn.delete('checklists');
        for (final row in checklists) {
          await txn.insert('checklists', {
            'checklist_key': row['checklist_key'],
            'form_type_key': row['form_type_key'],
            'permission_key': row['permission_key'],
            'report_prefix': row['report_prefix'],
            'nombre': row['nombre'],
            'subtitulo': row['subtitulo'],
            'icono': row['icono'],
            'color': row['color'],
            'published_version': row['published_version'] ?? 0,
            'activo': _boolInt(row['activo']),
            'updated_at': row['updated_at']?.toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (versions.isNotEmpty) {
        await txn.delete('checklist_versions');
        for (final row in versions) {
          await txn.insert('checklist_versions', {
            'id': row['id'],
            'checklist_key': row['checklist_key'],
            'version': row['version'],
            'estado': row['estado'],
            'snapshot_preguntas': _jsonText(row['snapshot_preguntas']),
            'snapshot_campos_extra': _jsonText(row['snapshot_campos_extra']),
            'snapshot_reglas': _jsonText(row['snapshot_reglas']),
            'published_at': row['published_at']?.toString(),
            'created_at': row['created_at']?.toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (empresaId != null && navigationNodes != null) {
        await txn.delete(
          'checklist_navigation_nodes',
          where: 'empresa_id = ?',
          whereArgs: [empresaId],
        );
        for (final row in navigationNodes) {
          await txn.insert(
            'checklist_navigation_nodes',
            _navigationNodeRow(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      if (empresaId != null && permissionGrants.isNotEmpty) {
        await txn.delete(
          'checklist_permission_grants',
          where:
              'empresa_id = ? AND (usuario_id = ? OR rol_id IN (SELECT rol_id FROM usuarios WHERE id = ?))',
          whereArgs: [empresaId, usuarioId, usuarioId],
        );
        for (final row in permissionGrants) {
          await txn.insert(
            'checklist_permission_grants',
            {
              'id': row['id'],
              'empresa_id': row['empresa_id'],
              'checklist_key': row['checklist_key'],
              'usuario_id': row['usuario_id'],
              'rol_id': row['rol_id'],
              'capacidad': row['capacidad'],
              'created_at': row['created_at']?.toString(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  int _boolInt(Object? value) => value == false ? 0 : 1;

  String _jsonText(Object? value) {
    if (value is String) return value;
    return jsonEncode(value ?? {});
  }

  // --- HIDROSER ------------------------------------------------------------

  /// Reescribe el catálogo local de listas de chequeo Hidroser.
  /// Las definiciones de campos extra viajan como JSON (TEXT en SQLite).
  Future<void> guardarHidroserListasOffline(
    List<Map<String, dynamic>> listas,
  ) async {
    if (listas.isEmpty) {
      debugPrint(
        "⚠️ Advertencia: lista vacía para hidroser_listas. Operación cancelada.",
      );
      return;
    }
    final db = await instance.database;
    final batch = db.batch();
    batch.delete('hidroser_listas');
    for (final l in listas) {
      final defs = l['campos_extra_definicion'];
      final defsJson = defs is String ? defs : jsonEncode(defs ?? []);
      batch.insert('hidroser_listas', {
        'codigo': l['codigo'],
        'nombre': l['nombre'],
        'subtitulo': l['subtitulo'],
        'tipo_formulario_items': l['tipo_formulario_items'],
        'icono': l['icono'],
        'orden': (l['orden'] is num) ? (l['orden'] as num).toInt() : 0,
        'activo': (l['activo'] == false) ? 0 : 1,
        'campos_extra_definicion': defsJson,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    debugPrint("✅ Hidroser listas guardadas: ${listas.length}");
  }

  Future<List<Map<String, dynamic>>> getHidroserListasActivas() async {
    final db = await instance.database;
    return await db.query(
      'hidroser_listas',
      where: 'activo = 1',
      orderBy: 'orden ASC, nombre ASC',
    );
  }

  // --- EQUIPAMIENTO DE BUCEO ----------------------------------------------

  /// Reescribe el catálogo local de listas del módulo Equipamiento de Buceo.
  Future<void> guardarBuceoEquipamientoListasOffline(
    List<Map<String, dynamic>> listas,
  ) async {
    if (listas.isEmpty) {
      debugPrint(
        "⚠️ Advertencia: lista vacía para buceo_equipamiento_listas. Operación cancelada.",
      );
      return;
    }
    final db = await instance.database;
    final batch = db.batch();
    batch.delete('buceo_equipamiento_listas');
    for (final l in listas) {
      batch.insert('buceo_equipamiento_listas', {
        'codigo': l['codigo'],
        'nombre': l['nombre'],
        'subtitulo': l['subtitulo'],
        'icono': l['icono'],
        'orden': (l['orden'] is num) ? (l['orden'] as num).toInt() : 0,
        'activo': (l['activo'] == false) ? 0 : 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    debugPrint("✅ Buceo equipamiento listas guardadas: ${listas.length}");
  }

  /// Reescribe el catálogo local de items (preguntas) del módulo Buceo.
  Future<void> guardarBuceoEquipamientoItemsOffline(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) {
      debugPrint(
        "⚠️ Advertencia: lista vacía para buceo_equipamiento_items. Operación cancelada.",
      );
      return;
    }
    final db = await instance.database;
    final batch = db.batch();
    batch.delete('buceo_equipamiento_items');
    for (final it in items) {
      batch.insert('buceo_equipamiento_items', {
        'id': it['id'].toString(),
        'lista_codigo': it['lista_codigo'],
        'categoria': it['categoria'] ?? 'General',
        'pregunta': it['pregunta'] ?? '',
        'criticidad': it['criticidad'],
        'peso': (it['peso'] is num) ? (it['peso'] as num).toInt() : 1,
        'orden': (it['orden'] is num) ? (it['orden'] as num).toInt() : 0,
        'activo': (it['activo'] == false) ? 0 : 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    debugPrint("✅ Buceo equipamiento items guardados: ${items.length}");
  }

  Future<List<Map<String, dynamic>>> getBuceoEquipamientoListasActivas() async {
    final db = await instance.database;
    return await db.query(
      'buceo_equipamiento_listas',
      where: 'activo = 1',
      orderBy: 'orden ASC, nombre ASC',
    );
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

  Future<List<Map<String, dynamic>>> getAreasByEmpresa(String empresaId) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT DISTINCT a.id, a.nombre, a.empresa_id
      FROM areas a
      INNER JOIN empresa_areas ea ON ea.area_id = a.id
      WHERE ea.empresa_id = ?
      ORDER BY a.nombre
    ''',
      [empresaId],
    );
  }

  Future<List<Map<String, dynamic>>> getModulosHabilitados(
    String empresaId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'empresa_modulos',
      where: 'empresa_id = ?',
      whereArgs: [empresaId],
      orderBy: 'orden',
    );
  }

  // --- CRUD para datos maestros (Admin) ---

  Future<void> insertCentro(String id, String nombre, String areaId) async {
    final db = await database;
    await db.insert('centros', {
      'id': id,
      'nombre': nombre,
      'area_id': areaId,
      'subido': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertContratista(String id, String nombre, String? rut) async {
    final db = await database;
    await db.insert('contratistas', {
      'id': id,
      'nombre': nombre,
      'rut': rut,
      'subido': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertEmbarcacion(
    String id,
    String nombre,
    String contratistaId,
    String? matricula,
  ) async {
    final db = await database;
    await db.insert('embarcaciones', {
      'id': id,
      'nombre': nombre,
      'contratista_id': contratistaId,
      'matricula': matricula,
      'subido': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPendingMasterData(String tabla) async {
    final db = await database;
    return await db.query(tabla, where: 'subido = 0');
  }

  Future<void> markMasterDataSynced(String tabla, String id) async {
    final db = await database;
    await db.update(tabla, {'subido': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
