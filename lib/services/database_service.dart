import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/receipt.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  /// Get the database instance, initializing if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'receipts.db');

    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  /// Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        image_taken TEXT NOT NULL,
        amount REAL NOT NULL,
        recipient TEXT,
        merchant_name TEXT,
        category TEXT,
        raw_ocr_text TEXT,
        raw_json_data TEXT
      )
    ''');

    print('Database created successfully');
  }

  /// Insert a new receipt
  Future<int> insertReceipt(Receipt receipt) async {
    final db = await database;
    final id = await db.insert(
      'receipts',
      receipt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Inserted receipt with ID: $id');
    return id;
  }

  /// Get all receipts
  Future<List<Receipt>> getAllReceipts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      orderBy: 'image_taken DESC',
    );

    return List.generate(maps.length, (i) => Receipt.fromMap(maps[i]));
  }

  /// Get a receipt by ID
  Future<Receipt?> getReceiptById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Receipt.fromMap(maps.first);
    }
    return null;
  }

  /// Update a receipt
  Future<int> updateReceipt(Receipt receipt) async {
    final db = await database;
    return await db.update(
      'receipts',
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  /// Delete a receipt
  Future<int> deleteReceipt(int id) async {
    final db = await database;
    return await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all receipts from the database
  Future<int> deleteAllReceipts() async {
    final db = await database;
    final count = await db.delete('receipts');
    print('Deleted $count receipts from database');
    return count;
  }

  /// Get receipts within a date range
  Future<List<Receipt>> getReceiptsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      where: 'image_taken BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'image_taken DESC',
    );

    return List.generate(maps.length, (i) => Receipt.fromMap(maps[i]));
  }

  /// Get total amount spent
  Future<double> getTotalAmount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM receipts',
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as double;
    }
    return 0.0;
  }

  /// Search receipts by merchant name or recipient
  Future<List<Receipt>> searchReceipts(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      where: 'merchant_name LIKE ? OR recipient LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'image_taken DESC',
    );

    return List.generate(maps.length, (i) => Receipt.fromMap(maps[i]));
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
