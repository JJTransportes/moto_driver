import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'moto_driver_token';
  static const _refreshTokenKey = 'moto_driver_refresh_token';
  static const _userIdKey = 'moto_driver_user_id';

  AuthStorage() : _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token, String userId) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userIdKey, value: userId),
    ]);
  }

  Future<String?> getToken() => _safeRead(_tokenKey);

  Future<String?> getUserId() => _safeRead(_userIdKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> getRefreshToken() => _safeRead(_refreshTokenKey);

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
    ]);
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      // Android Keystore corruption (BadPaddingException after
      // uninstall/reinstall or signing-key change).
      // Clear corrupted entries and return null so the app
      // gracefully falls back to the login screen.
      if (e.code == 'Exception encountered' && e.message?.contains('read') == true) {
        debugPrint('AuthStorage: corrupted secure storage — clearing and re-authenticating');
        await _storage.deleteAll();
        return null;
      }
      rethrow;
    }
  }
}
