import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:moto_driver/core/local_db/schema.dart';

class LocalDatabaseService {
  static Database? _db;

  static Future<void> init() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'moto_driver.db');

      _db = await openDatabase(
        path,
        version: Schema.currentVersion,
        onCreate: Schema.onCreate,
        onUpgrade: Schema.onUpgrade,
      );
    } catch (_) {
      throw Exception('Local persistence bootstrap failure.');
    }
  }

  static Database get instance {
    if (_db == null) {
      throw StateError(
        'LocalDatabaseService not initialized. '
        'Call LocalDatabaseService.init() before accessing the database.',
      );
    }
    return _db!;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
