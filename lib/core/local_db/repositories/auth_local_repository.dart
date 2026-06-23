import 'package:moto_driver/core/local_db/local_database_service.dart';
import 'package:moto_driver/core/local_db/models/local_data_models.dart';

class AuthLocalRepository {
  Future<void> saveAuth({
    required String userId,
    required String accessToken,
    required List<String> roles,
  }) async {
    try {
      final db = LocalDatabaseService.instance;
      await db.delete('auth');
      await db.insert('auth', {
        'user_id': userId,
        'access_token': accessToken,
        'roles': roles.join(','),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Silently fail — app works without cache
    }
  }

  Future<AuthLocalData?> getAuth() async {
    try {
      final db = LocalDatabaseService.instance;
      final rows = await db.query('auth', limit: 1);
      if (rows.isEmpty) return null;
      return AuthLocalData.fromMap(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAuth() async {
    try {
      final db = LocalDatabaseService.instance;
      await db.delete('auth');
    } catch (_) {}
  }
}
