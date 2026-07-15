import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';

void main() {
  group('RefreshTokenResponseModel', () {
    test('fromJson parses full response correctly', () {
      final json = {
        'accessToken': 'new_access_123',
        'refreshToken': 'new_refresh_456',
        'expiresAt': '2026-07-13T12:30:00Z',
        'refreshExpiresAt': '2026-08-12T12:30:00Z',
        'userId': 'user_1',
        'roles': ['Driver'],
      };

      final model = RefreshTokenResponseModel.fromJson(json);

      expect(model.accessToken, 'new_access_123');
      expect(model.refreshToken, 'new_refresh_456');
      expect(model.expiresAt, DateTime.utc(2026, 7, 13, 12, 30));
      expect(model.refreshExpiresAt, DateTime.utc(2026, 8, 12, 12, 30));
      expect(model.userId, 'user_1');
      expect(model.roles, ['Driver']);
    });

    test('fromJson parses response without refreshExpiresAt', () {
      final json = {
        'accessToken': 'new_access_123',
        'refreshToken': 'new_refresh_456',
        'expiresAt': '2026-07-13T12:30:00Z',
        'userId': 'user_1',
        'roles': ['Driver'],
      };

      final model = RefreshTokenResponseModel.fromJson(json);

      expect(model.accessToken, 'new_access_123');
      expect(model.refreshToken, 'new_refresh_456');
      expect(model.refreshExpiresAt, isNull);
      expect(model.userId, 'user_1');
      expect(model.roles, ['Driver']);
    });

    test('fromJson handles multiple roles', () {
      final json = {
        'accessToken': 'tok_123',
        'refreshToken': 'ref_456',
        'expiresAt': '2026-07-13T12:30:00Z',
        'userId': 'user_1',
        'roles': ['Driver', 'Admin'],
      };

      final model = RefreshTokenResponseModel.fromJson(json);

      expect(model.roles, ['Driver', 'Admin']);
    });
  });
}
