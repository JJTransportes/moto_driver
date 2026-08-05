import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TermsStorage {
  final FlutterSecureStorage _storage;
  static const _acceptedTermsKey = 'moto_driver_accepted_terms_id';

  TermsStorage() : _storage = const FlutterSecureStorage();

  Future<void> saveAcceptedTermId(String usageTermId) =>
      _storage.write(key: _acceptedTermsKey, value: usageTermId);

  Future<String?> getAcceptedTermId() => _safeRead(_acceptedTermsKey);

  Future<void> clear() => _storage.delete(key: _acceptedTermsKey);

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      // Android Keystore corruption (BadPaddingException after
      // uninstall/reinstall or signing-key change).
      // Clear corrupted entries and return null so the app
      // gracefully falls back to the login screen.
      if (e.code == 'Exception encountered' && e.message?.contains('read') == true) {
        debugPrint('TermsStorage: corrupted secure storage — clearing');
        await _storage.deleteAll();
        return null;
      }
      rethrow;
    }
  }
}
