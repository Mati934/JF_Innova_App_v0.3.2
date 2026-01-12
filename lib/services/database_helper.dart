import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(
      'jfinnova_local_v2.db',
    ); // Cambié el nombre para forzar creación nueva
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
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

    // --- NUEVAS TABLAS DE DATOS MAESTROS (PARA EL SETUP OFFLINE) ---

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
    // 4. ACTIVIDADES PENDIENTES (NUEVA TABLA IMPORTANTE)
    // Aquí guardamos la "carpeta" si no hay internet al crearla.
    await db.execute('''
      CREATE TABLE actividades_pendientes (
        id TEXT PRIMARY KEY, -- Usaremos el UUID que generamos
        usuario_id TEXT,
        centro_id TEXT,
        contratista_id TEXT,
        embarcacion_id TEXT,
        tipo_actividad TEXT,
        fecha_realizacion TEXT,
        puerto_abierto INTEGER, -- 0 o 1
        observaciones_generales TEXT,
        estado_final TEXT,
        subido INTEGER DEFAULT 0
      )
    ''');
  }

  // --- MÉTODOS CRUD GENÉRICOS PARA MAESTROS ---

  Future<void> guardarMaestros(
    String tabla,
    List<Map<String, dynamic>> datos,
  ) async {
    final db = await instance.database;
    final batch = db.batch();

    // Borramos lo viejo y ponemos lo nuevo
    batch.delete(tabla);

    for (var item in datos) {
      // Filtramos solo los campos que nos interesan para evitar errores si la API manda más cosas
      Map<String, dynamic> row = {'id': item['id'], 'nombre': item['nombre']};
      // Agregamos claves foráneas si existen
      if (item.containsKey('area_id')) row['area_id'] = item['area_id'];
      if (item.containsKey('contratista_id'))
        row['contratista_id'] = item['contratista_id'];

      batch.insert(tabla, row);
    }
    await batch.commit(noResult: true);
  }

  // Métodos de lectura para la UI
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

  // Formulario Items (Ya lo tenías)
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

  // Guardar actividad creada offline
  // Asegúrate de que este método esté así:
  Future<void> saveActividadOffline(Map<String, dynamic> actividad) async {
    final db = await instance.database;
    await db.insert(
      'actividades_pendientes',
      actividad,
      conflictAlgorithm: ConflictAlgorithm.replace, // <--- IMPORTANTE
    );
  }
}
