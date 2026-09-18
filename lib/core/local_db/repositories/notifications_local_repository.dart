import 'dart:developer';

import 'package:moto_driver/core/local_db/local_database_service.dart';

class NotificationsLocalRepository {
  Future<void> savePlayerId(String playerId) async {
    try {
      final db = LocalDatabaseService.instance;
      await db.delete('notifications');
      await db.insert('notifications', {
        'player_id': playerId,
      });

      log('Player id saved!');
    } catch (e) {
      log('Player id saving failed. ${e.runtimeType}');
    }
  }

  Future<String?> getPlayerId() async {
    try {
      final db = LocalDatabaseService.instance;
      final rows = await db.query('notifications', limit: 1);
      if (rows.isEmpty) return null;
      final playerId = rows.first['player_id'] as String?;

      return playerId;
    } catch (_) {
      return null;
    }
  }
}
