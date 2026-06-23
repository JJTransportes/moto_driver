import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'moto_driver_token';
  static const _userIdKey = 'moto_driver_user_id';

  AuthStorage() : _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token, String userId) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userIdKey, value: userId),
    ]);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userIdKey),
    ]);
  }
}
