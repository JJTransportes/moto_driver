import 'package:sqflite/sqflite.dart';

class Schema {
  static const currentVersion = 2;

  static final createStatements = [
    '''
    CREATE TABLE IF NOT EXISTS metadata (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS auth (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id       TEXT    NOT NULL,
      access_token  TEXT    NOT NULL,
      roles         TEXT    NOT NULL,
      expires_at    TEXT,
      created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS user_profile (
      user_id    TEXT PRIMARY KEY,
      full_name  TEXT NOT NULL,
      email      TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS travels (
      travel_id           TEXT PRIMARY KEY,
      status              TEXT NOT NULL,
      driver_name         TEXT,
      passenger_name      TEXT,
      departure_address   TEXT,
      destination_address TEXT,
      created_at          TEXT NOT NULL,
      started_at          TEXT,
      finished_at         TEXT,
      cached_at           TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS active_travel (
      id                  INTEGER PRIMARY KEY CHECK (id = 1),
      travel_id           TEXT NOT NULL UNIQUE,
      status              TEXT NOT NULL,
      driver_name         TEXT,
      passenger_name      TEXT,
      departure_address   TEXT,
      destination_address TEXT,
      created_at          TEXT NOT NULL,
      cached_at           TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS notifications (
      player_id           TEXT NOT NULL
    )
    ''',
  ];

  static Future<void> onCreate(Database db, int version) async {
    for (final stmt in createStatements) {
      await db.execute(stmt);
    }
    await db.insert('metadata', {
      'key': 'db_version',
      'value': version.toString(),
    });
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE active_travel ADD COLUMN passenger_name TEXT
      ''');
      await db.execute('''
        ALTER TABLE active_travel ADD COLUMN departure_address TEXT
      ''');
      await db.execute('''
        ALTER TABLE active_travel ADD COLUMN destination_address TEXT
      ''');
    }
    await db.update(
      'metadata',
      {'value': newVersion.toString()},
      where: 'key = ?',
      whereArgs: ['db_version'],
    );
  }
}
