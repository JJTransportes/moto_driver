import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/local_db/schema.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// F18: reproduz o schema da v1 (antes das colunas passenger_name/
// departure_address/destination_address existirem em active_travel) num
// banco em memória, roda o `onUpgrade` real de Schema e confirma que o
// upgrade é seguro em cima de dados de usuários que já tinham o app
// instalado — não só que o SQL do onUpgrade compila.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const v1ActiveTravelCreate = '''
    CREATE TABLE IF NOT EXISTS active_travel (
      id                  INTEGER PRIMARY KEY CHECK (id = 1),
      travel_id           TEXT NOT NULL UNIQUE,
      status              TEXT NOT NULL,
      driver_name         TEXT,
      created_at          TEXT NOT NULL,
      cached_at           TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''';

  Future<Database> openV1Database(String path) {
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS metadata (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
          ''');
        await db.execute(v1ActiveTravelCreate);
        await db.insert('metadata', {'key': 'db_version', 'value': '1'});
      },
    );
  }

  test('v1 database has no passenger_name/address columns on active_travel', () async {
    final path = join(Directory.systemTemp.path, 'f18_v1_columns_test.db');
    final existing = File(path);
    if (existing.existsSync()) existing.deleteSync();

    final db = await openV1Database(path);
    final columns = await db.rawQuery('PRAGMA table_info(active_travel)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();

    expect(columnNames, isNot(contains('passenger_name')));
    expect(columnNames, isNot(contains('departure_address')));
    expect(columnNames, isNot(contains('destination_address')));

    await db.close();
    existing.deleteSync();
  });

  test('onUpgrade from v1 to v2 adds the new columns without losing existing rows', () async {
    final path = join(Directory.systemTemp.path, 'f18_upgrade_test.db');
    final existing = File(path);
    if (existing.existsSync()) existing.deleteSync();

    final v1 = await openV1Database(path);
    await v1.insert('active_travel', {
      'id': 1,
      'travel_id': 'travel-123',
      'status': 'InProgress',
      'driver_name': 'João Motorista',
      'created_at': '2026-01-01T10:00:00Z',
    });
    await v1.close();

    // Reabre o MESMO arquivo em disco com a versão atual — é isso que o
    // sqflite faz de verdade num device: mesma instalação, novo build, nova
    // `Schema.currentVersion`.
    final v2 = await openDatabase(
      path,
      version: Schema.currentVersion,
      onCreate: Schema.onCreate,
      onUpgrade: Schema.onUpgrade,
    );

    final columns = await v2.rawQuery('PRAGMA table_info(active_travel)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();
    expect(columnNames, containsAll(['passenger_name', 'departure_address', 'destination_address']));

    final rows = await v2.query('active_travel', where: 'travel_id = ?', whereArgs: ['travel-123']);
    expect(rows, hasLength(1));
    expect(rows.first['driver_name'], 'João Motorista');
    expect(rows.first['status'], 'InProgress');
    // Colunas novas ficam NULL pra linhas que já existiam antes do upgrade —
    // não há como preencher retroativamente um dado que nunca foi salvo.
    expect(rows.first['passenger_name'], isNull);

    final metadataRows = await v2.query('metadata', where: 'key = ?', whereArgs: ['db_version']);
    expect(metadataRows.first['value'], Schema.currentVersion.toString());

    // A viagem ativa continua insertable/updatable normalmente com as
    // colunas novas depois do upgrade — não é só leitura que precisa
    // funcionar.
    await v2.update(
      'active_travel',
      {'passenger_name': 'Maria Passageira'},
      where: 'travel_id = ?',
      whereArgs: ['travel-123'],
    );
    final updated = await v2.query('active_travel', where: 'travel_id = ?', whereArgs: ['travel-123']);
    expect(updated.first['passenger_name'], 'Maria Passageira');

    await v2.close();
    existing.deleteSync();
  });

  test('a fresh v2 database (new install) creates active_travel with all columns directly', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: Schema.currentVersion,
      onCreate: Schema.onCreate,
      onUpgrade: Schema.onUpgrade,
    );

    final columns = await db.rawQuery('PRAGMA table_info(active_travel)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();
    expect(columnNames, containsAll(['passenger_name', 'departure_address', 'destination_address']));

    final metadataRows = await db.query('metadata', where: 'key = ?', whereArgs: ['db_version']);
    expect(metadataRows.first['value'], Schema.currentVersion.toString());

    await db.close();
  });
}
