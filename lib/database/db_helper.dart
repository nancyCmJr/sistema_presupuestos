import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  // =========================
  // GET DB
  // =========================
  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('presupuestos.db');
    return _database!;
  }

  // =========================
  // INIT DB
  // =========================
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // =========================
  // MIGRACIÓN
  // =========================
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE clientes ADD COLUMN sync INTEGER DEFAULT 0");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE clientes ADD COLUMN updated_at TEXT");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE clientes ADD COLUMN deleted INTEGER DEFAULT 0");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE materiales ADD COLUMN sync INTEGER DEFAULT 0");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE materiales ADD COLUMN updated_at TEXT");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE materiales ADD COLUMN deleted INTEGER DEFAULT 0");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE presupuestos ADD COLUMN updated_at TEXT");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE presupuestos ADD COLUMN deleted INTEGER DEFAULT 0");
      } catch (_) {}
    }

    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE clientes ADD COLUMN local_uid TEXT");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE materiales ADD COLUMN local_uid TEXT");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE presupuestos ADD COLUMN local_uid TEXT");
      } catch (_) {}
    }
  }

  // =========================
  // CREAR DB
  // =========================
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_uid TEXT,
        nombre TEXT NOT NULL,
        telefono TEXT,
        direccion TEXT,
        email TEXT,
        sync INTEGER DEFAULT 0,
        updated_at TEXT,
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE materiales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_uid TEXT,
        nombre TEXT NOT NULL,
        precio REAL NOT NULL,
        unidad TEXT,
        origen TEXT,
        sync INTEGER DEFAULT 0,
        updated_at TEXT,
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE presupuestos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_uid TEXT,
        cliente_id INTEGER NOT NULL,
        fecha TEXT DEFAULT CURRENT_TIMESTAMP,
        total REAL DEFAULT 0,
        descripcion TEXT,
        estado TEXT DEFAULT 'pendiente',
        sync INTEGER DEFAULT 0,
        updated_at TEXT,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE mano_obra (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion TEXT NOT NULL,
        precio REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        presupuesto_id INTEGER,
        descripcion TEXT,
        monto REAL NOT NULL,
        FOREIGN KEY (presupuesto_id) REFERENCES presupuestos(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE detalle_materiales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        presupuesto_id INTEGER,
        material_id INTEGER,
        cantidad REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (presupuesto_id) REFERENCES presupuestos(id) ON DELETE CASCADE,
        FOREIGN KEY (material_id) REFERENCES materiales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE detalle_mano_obra (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        presupuesto_id INTEGER,
        mano_obra_id INTEGER,
        cantidad REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (presupuesto_id) REFERENCES presupuestos(id) ON DELETE CASCADE,
        FOREIGN KEY (mano_obra_id) REFERENCES mano_obra(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE historial_precios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material TEXT,
        tienda TEXT,
        precio REAL,
        fecha TEXT
      )
    ''');
  }

  // =========================
  // HELPERS
  // =========================
  String now() {
    return DateTime.now().toIso8601String();
  }

  String generarLocalUid(String tabla) {
    return "${tabla}_${DateTime.now().microsecondsSinceEpoch}";
  }

  // =========================
  // CLIENTES
  // =========================
  Future<int> insertarCliente(Map<String, dynamic> cliente) async {
    final db = await database;

    return db.insert('clientes', {
      ...cliente,
      "local_uid": cliente["local_uid"] ?? generarLocalUid("cliente"),
      "sync": 0,
      "updated_at": now(),
      "deleted": 0,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerClientes() async {
    final db = await database;

    return db.query(
      'clientes',
      where: 'deleted = 0',
      orderBy: 'nombre ASC',
    );
  }

  Future<int> actualizarCliente(Map<String, dynamic> cliente) async {
    final db = await database;

    return db.update(
      'clientes',
      {
        ...cliente,
        "sync": 0,
        "updated_at": now(),
        "deleted": cliente["deleted"] ?? 0,
      },
      where: 'id = ?',
      whereArgs: [cliente['id']],
    );
  }

  Future<int> eliminarCliente(int id) async {
    final db = await database;

    return db.update(
      'clientes',
      {
        "deleted": 1,
        "sync": 0,
        "updated_at": now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================
  // PRESUPUESTOS
  // =========================
  Future<int> crearPresupuesto(Map<String, dynamic> presupuesto) async {
    final db = await database;

    return db.insert('presupuestos', {
      ...presupuesto,
      "local_uid": presupuesto["local_uid"] ?? generarLocalUid("presupuesto"),
      "sync": 0,
      "updated_at": now(),
      "deleted": 0,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerPresupuestos() async {
    final db = await database;

    return db.query(
      'presupuestos',
      where: 'deleted = 0',
      orderBy: 'fecha DESC',
    );
  }

  Future<int> actualizarPresupuesto(Map<String, dynamic> presupuesto) async {
    final db = await database;

    return db.update(
      'presupuestos',
      {
        ...presupuesto,
        "sync": 0,
        "updated_at": now(),
      },
      where: 'id = ?',
      whereArgs: [presupuesto["id"]],
    );
  }

  Future<int> eliminarPresupuesto(int id) async {
    final db = await database;

    return db.update(
      'presupuestos',
      {
        "deleted": 1,
        "sync": 0,
        "updated_at": now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================
  // DETALLES
  // =========================
  Future<int> agregarMaterial(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('detalle_materiales', data);
  }

  Future<int> agregarManoObra(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('detalle_mano_obra', data);
  }

  Future<int> agregarGasto(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('gastos', data);
  }

  // =========================
  // CATÁLOGOS
  // =========================
  Future<List<Map<String, dynamic>>> obtenerManoObra() async {
    final db = await database;

    return db.query(
      'mano_obra',
      orderBy: 'descripcion ASC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerGastosCatalogo() async {
    final db = await database;

    return db.query(
      'gastos',
      where: 'presupuesto_id IS NULL',
      orderBy: 'descripcion ASC',
    );
  }

  // =========================
  // HISTORIAL
  // =========================
  Future<void> guardarHistorial(List precios, String material) async {
    final db = await database;

    for (var p in precios) {
      await db.insert('historial_precios', {
        'material': material,
        'tienda': p['tienda'],
        'precio': (p['precio'] as num).toDouble(),
        'fecha': now(),
      });
    }
  }

  // =========================
  // REPORTES
  // =========================
  Future<Map<String, dynamic>> dashboardKPIs() async {
    final db = await database;

    final ingresos = await db.rawQuery(
      "SELECT IFNULL(SUM(total),0) as total FROM presupuestos WHERE estado='aprobado' AND deleted=0",
    );

    final pendientes = await db.rawQuery(
      "SELECT COUNT(*) as total FROM presupuestos WHERE estado='pendiente' AND deleted=0",
    );

    final clientes = await db.rawQuery(
      "SELECT COUNT(*) as total FROM clientes WHERE deleted=0",
    );

    final gastos = await db.rawQuery(
      "SELECT IFNULL(SUM(monto),0) as total FROM gastos WHERE presupuesto_id IS NOT NULL",
    );

    return {
      "ingresos": (ingresos.first["total"] as num).toDouble(),
      "pendientes": pendientes.first["total"],
      "clientes": clientes.first["total"],
      "gastos": (gastos.first["total"] as num).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> ingresosPorDia() async {
    final db = await database;

    return db.rawQuery('''
      SELECT DATE(fecha) as dia, IFNULL(SUM(total),0) as total
      FROM presupuestos
      WHERE estado = 'aprobado' AND deleted = 0
      GROUP BY DATE(fecha)
      ORDER BY DATE(fecha)
    ''');
  }

  Future<List<Map<String, dynamic>>> distribucionCostos() async {
    final db = await database;

    final materiales = await db.rawQuery('''
      SELECT 'Materiales' as tipo, IFNULL(SUM(dm.subtotal),0) as total
      FROM detalle_materiales dm
      INNER JOIN presupuestos p ON p.id = dm.presupuesto_id
      WHERE p.deleted = 0
    ''');

    final manoObra = await db.rawQuery('''
      SELECT 'Mano de obra' as tipo, IFNULL(SUM(dmo.subtotal),0) as total
      FROM detalle_mano_obra dmo
      INNER JOIN presupuestos p ON p.id = dmo.presupuesto_id
      WHERE p.deleted = 0
    ''');

    final gastos = await db.rawQuery('''
      SELECT 'Gastos' as tipo, IFNULL(SUM(g.monto),0) as total
      FROM gastos g
      INNER JOIN presupuestos p ON p.id = g.presupuesto_id
      WHERE p.deleted = 0
    ''');

    return [
      materiales.first,
      manoObra.first,
      gastos.first,
    ];
  }

  // =========================
  // LIMPIAR DB
  // =========================
  Future<void> limpiarBaseDatos() async {
    final db = await database;

    await db.delete('detalle_materiales');
    await db.delete('detalle_mano_obra');
    await db.delete('gastos');
    await db.delete('presupuestos');
    await db.delete('clientes');
    await db.delete('materiales');
    await db.delete('mano_obra');
    await db.delete('historial_precios');
  }
}