import 'package:sqflite/sqflite.dart';
import 'package:moto_driver/core/local_db/local_database_service.dart';
import 'package:moto_driver/core/local_db/models/local_data_models.dart';

class ProfileLocalRepository {
  Future<void> saveProfile({
    required String userId,
    required String fullName,
    required String email,
  }) async {
    try {
      final db = LocalDatabaseService.instance;
      await db.insert(
        'user_profile',
        {
          'user_id': userId,
          'full_name': fullName,
          'email': email,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<ProfileLocalData?> getProfile(String userId) async {
    try {
      final db = LocalDatabaseService.instance;
      final rows = await db.query(
        'user_profile',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ProfileLocalData.fromMap(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearProfile() async {
    try {
      final db = LocalDatabaseService.instance;
      await db.delete('user_profile');
    } catch (_) {}
  }
}
