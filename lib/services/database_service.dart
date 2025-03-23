import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/debt_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseService get instance => _instance;
  
  DatabaseService._internal();
  
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app_database.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE debts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId INTEGER,
            username TEXT,
            amount REAL,
            dueDate TEXT,
            isPaid INTEGER,
            createdAt TEXT,
            notes TEXT
          )
        ''');
      },
    );
  }

  // إضافة دين جديد
  Future<int> addDebt(DebtModel debt) async {
    final db = await database;
    return await db.insert('debts', debt.toMap());
  }

  // الحصول على جميع الديون
  Future<List<DebtModel>> getAllDebts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('debts');
    
    return List.generate(maps.length, (i) {
      return DebtModel.fromMap(maps[i]);
    });
  }

  // الحصول على ديون مستخدم محدد
  Future<List<DebtModel>> getDebtsByUserId(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'debts',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    
    return List.generate(maps.length, (i) {
      return DebtModel.fromMap(maps[i]);
    });
  }

  // تحديث حالة الدين
  Future<int> updateDebtStatus(int id, bool isPaid) async {
    final db = await database;
    return await db.update(
      'debts',
      {'isPaid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // حذف دين
  Future<int> deleteDebt(int id) async {
    final db = await database;
    return await db.delete(
      'debts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // الحصول على إجمالي الديون غير المدفوعة
  Future<double> getTotalUnpaidDebts() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM debts WHERE isPaid = 0'
    );
    
    return result.isNotEmpty ? (result.first['total'] as num?)?.toDouble() ?? 0.0 : 0.0;
  }
}