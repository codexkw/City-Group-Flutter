import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Local SQLite buffer for speed readings.
/// Readings are buffered locally and batch-uploaded to the server.
class SpeedLogDb {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'speed_logs.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE speed_readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            taskId TEXT NOT NULL,
            recordedAt TEXT NOT NULL,
            speedKmh REAL NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Insert a new speed reading.
  static Future<int> insertReading({
    required String taskId,
    required DateTime recordedAt,
    required double speedKmh,
    required double latitude,
    required double longitude,
  }) async {
    final db = await database;
    return db.insert('speed_readings', {
      'taskId': taskId,
      'recordedAt': recordedAt.toUtc().toIso8601String(),
      'speedKmh': speedKmh,
      'latitude': latitude,
      'longitude': longitude,
      'synced': 0,
    });
  }

  /// Get unsynced readings for a task (up to [limit]).
  static Future<List<Map<String, dynamic>>> getUnsyncedReadings({
    String? taskId,
    int limit = 5,
  }) async {
    final db = await database;
    final where = taskId != null ? 'synced = 0 AND taskId = ?' : 'synced = 0';
    final whereArgs = taskId != null ? [taskId] : null;
    return db.query(
      'speed_readings',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'recordedAt ASC',
      limit: limit,
    );
  }

  /// Mark readings as synced.
  static Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.update(
      'speed_readings',
      {'synced': 1},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Delete synced readings older than [duration].
  static Future<int> cleanOldSynced({Duration duration = const Duration(days: 7)}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(duration).toUtc().toIso8601String();
    return db.delete(
      'speed_readings',
      where: 'synced = 1 AND recordedAt < ?',
      whereArgs: [cutoff],
    );
  }

  /// Count of unsynced readings.
  static Future<int> unsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM speed_readings WHERE synced = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
