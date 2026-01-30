import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // CAMBIAMOS A v9 PARA ASEGURARNOS QUE SE CREE DESDE CERO SI O SI
    _database = await _initDB('jfinnova_local_v9.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // CAMBIO AQUI: version: 2 y agregamos onUpgrade
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // TABLA USUARIOS
    await db.execute('''
      CREATE TABLE usuarios (
        id TEXT PRIMARY KEY,
        rut TEXT,
        nombre_completo TEXT,
        email TEXT,
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
        activo INTEGER
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
    await db.execute(
      'CREATE TABLE embarcaciones (id TEXT PRIMARY KEY, nombre TEXT, contratista_id TEXT)',
    );

    // 4. ACTIVIDADES PENDIENTES (Incluye numero_reporte)
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
        subido INTEGER DEFAULT 0
      )
    ''');

    // --- 5. TABLAS ESPECÍFICAS DE BUCEO (ACTUALIZADA CORRECTAMENTE) ---

    // Verificaciones Críticas
    await db.execute('''
      CREATE TABLE verificaciones_buceo (
        actividad_id TEXT PRIMARY KEY,
        autorizacion_autoridad_maritima INTEGER DEFAULT 0,
        induccion_centro_cultivo INTEGER DEFAULT 0,
        permiso_buceo_centro_correcto INTEGER DEFAULT 0,
        plan_contingencias_centro_ok INTEGER DEFAULT 0,
        examenes_ocupacionales_vigentes INTEGER DEFAULT 0,
        observacion_general TEXT,
        estado_manual TEXT,
        
        -- DATOS TÉCNICOS
        supervisor_nombre TEXT,
        supervisor_rut TEXT,

        encargado_centro TEXT,     -- NUEVO: Jefe de Centro (AquaChile)
        supervisor_centro TEXT,    -- NUEVO: Supervisor de Turno (AquaChile)

        -- HORARIOS (ESTO ERA LO QUE FALTABA)
        hora_inicio TEXT,
        hora_termino TEXT,

        -- COMPRESOR 1
        compresor_1_matricula TEXT,
        compresor_1_vigencia TEXT,
        compresor_1_vigencia_ph TEXT, -- NUEVO
        compresor_1_buzos_cargo INTEGER,

        -- COMPRESOR 2
        compresor_2_matricula TEXT,
        compresor_2_vigencia TEXT,
        compresor_2_vigencia_ph TEXT, -- NUEVO
        compresor_2_buzos_cargo INTEGER,

        -- CERTIFICADO EQUIPOS (Aun lo dejamos por seguridad si lo tienes en el repo viejo, si no, no molesta)
        certificado_equipos_ok INTEGER DEFAULT 0,
        certificado_equipos_vigencia TEXT
      )
    ''');

    // Tabla Maestra de Personal Externo
    await db.execute('''
      CREATE TABLE personal_externo (
        id TEXT PRIMARY KEY,
        rut TEXT,
        nombre_completo TEXT NOT NULL,
        cargo TEXT,
        matricula TEXT, 
        activo INTEGER DEFAULT 1
      )
    ''');

    // Tabla Intermedia (Relación M:N Inspección <-> Personal)
    await db.execute('''
      CREATE TABLE actividad_participantes (
        actividad_id TEXT,
        personal_id TEXT,
        rol_en_faena TEXT,
        condiciones_optimas INTEGER DEFAULT 1,
        PRIMARY KEY (actividad_id, personal_id)
      )
    ''');

    print("✅ Base de datos v9 inicializada con TODAS las columnas nuevas.");
  }
  // --- MÉTODOS CRUD GENÉRICOS ---

  // 🟢 NUEVO MÉTODO DE MIGRACIÓN
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
      "🔧 DETECTADA ACTUALIZACIÓN DE BD: v$oldVersion -> v$newVersion",
    );

    if (oldVersion < 2) {
      debugPrint("🚀 Aplicando parche v2: Agregar numero_seguimiento...");
      try {
        // Inyectamos la columna que falta sin borrar la tabla
        await db.execute(
          "ALTER TABLE actividades_pendientes ADD COLUMN numero_seguimiento INTEGER DEFAULT 0",
        );
        debugPrint("✅ Columna 'numero_seguimiento' agregada con éxito.");
      } catch (e) {
        // Si por alguna razón ya existía (ej: reiniciaste muchas veces), no rompemos nada.
        debugPrint("⚠️ Advertencia en migración: $e");
      }
    }
  }

  Future<void> guardarMaestros(
    String tabla,
    List<Map<String, dynamic>> datos,
  ) async {
    final db = await database;
    final batch = db.batch();

    batch.delete(tabla);

    for (var item in datos) {
      Map<String, dynamic> row = {'id': item['id'], 'nombre': item['nombre']};
      if (item.containsKey('area_id')) row['area_id'] = item['area_id'];
      if (item.containsKey('contratista_id'))
        row['contratista_id'] = item['contratista_id'];

      batch.insert(tabla, row);
    }
    await batch.commit(noResult: true);
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
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveActividadOffline(Map<String, dynamic> actividad) async {
    final db = await instance.database;
    debugPrint("--- Guardando en SQLite ---");
    debugPrint("ID: ${actividad['id']}");
    debugPrint("Contratista: ${actividad['contratista_id']}");
    debugPrint("Embarcación: ${actividad['embarcacion_id']}");
    await db.insert(
      'actividades_pendientes',
      actividad,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
