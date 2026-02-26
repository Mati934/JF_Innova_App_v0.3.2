import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const int _dbVersion = 16;
  static const String _dbName = 'jfinnova_v17_local.db';

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
    );
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
        rol_id TEXT
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
        info_adicional TEXT
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
    await db.execute('CREATE TABLE areas (id TEXT PRIMARY KEY, nombre TEXT)');
    await db.execute(
      'CREATE TABLE centros (id TEXT PRIMARY KEY, nombre TEXT, area_id TEXT)',
    );
    await db.execute(
      'CREATE TABLE contratistas (id TEXT PRIMARY KEY, nombre TEXT)',
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
        observaciones_cierre TEXT
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
        pdf_path_local TEXT,
        pdf_url TEXT
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
  }

  // Helper seguro para migraciones
  Future<void> _safeAddColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    try {
      await db.execute("ALTER TABLE $table ADD COLUMN $column $type");
    } catch (_) {
      // Ignoramos si ya existe
    }
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

    final db = await database; // Usa el getter, no instance.database directo

    await db.transaction((txn) async {
      final batch = txn.batch();

      // Ahora sí, borramos porque traemos datos frescos seguros
      batch.delete(tabla);

      for (var item in datos) {
        Map<String, dynamic> row = {};

        // ... (Tu lógica de mapeo está perfecta, déjala igual) ...
        // ... Copia y pega tu switch/if de mapeo aquí ...
        row['id'] = item['id'];
        if (tabla == 'personal_externo') {
          row['nombre_completo'] =
              item['nombre_completo'] ?? item['nombre'] ?? 'Sin Nombre';
          row['rut'] = item['rut'];
          row['cargo'] = item['cargo'];
          row['matricula'] = item['matricula'];
          row['contratista_id'] = item['contratista_id'];
        } else if (tabla == 'embarcaciones') {
          row['nombre'] = item['nombre'];
          if (item.containsKey('contratista_id'))
            row['contratista_id'] = item['contratista_id'];
          if (item.containsKey('matricula'))
            row['matricula'] = item['matricula'];
        } else if (tabla == 'centros') {
          row['nombre'] = item['nombre'];
          if (item.containsKey('area_id')) row['area_id'] = item['area_id'];
        } else {
          row['nombre'] = item['nombre'];
        }

        batch.insert(tabla, row);
      }

      await batch.commit(noResult: true);
    });
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
    final db = await instance.database;
    final batch = db.batch();
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
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveActividadOffline(Map<String, dynamic> actividad) async {
    final db = await instance.database;
    await db.insert(
      'actividades_pendientes',
      actividad,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
