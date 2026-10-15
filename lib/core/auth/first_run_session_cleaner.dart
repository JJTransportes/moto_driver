import 'dart:developer' show log;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Limpa a sessão guardada na Keychain na primeira abertura após a instalação.
///
/// No iOS a Keychain sobrevive à desinstalação do app, mas o
/// `SharedPreferences` não. Uma marca no `SharedPreferences` indica que esta
/// instalação já foi inicializada: sem ela, qualquer token que esteja na
/// Keychain pertence a uma instalação anterior (outro ambiente, outra conta no
/// mesmo aparelho) e é descartado. Só roda no iOS; no Android a desinstalação
/// já apaga o armazenamento seguro.
class FirstRunSessionCleaner {
  FirstRunSessionCleaner({
    FlutterSecureStorage? storage,
    Future<SharedPreferences> Function()? preferences,
    bool? isIOS,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _isIOS = isIOS ?? (!kIsWeb && Platform.isIOS);

  static const markerKey = 'moto_driver.first_run_done';

  final FlutterSecureStorage _storage;
  final Future<SharedPreferences> Function() _preferences;
  final bool _isIOS;

  /// Nunca lança: a limpeza é best-effort e não pode impedir a abertura do app.
  Future<void> run() async {
    if (!_isIOS) return;
    try {
      final prefs = await _preferences();
      if (prefs.getBool(markerKey) == true) return;
      await _storage.deleteAll();
      await prefs.setBool(markerKey, true);
    } catch (e) {
      log(
        '[AUTH] First-run keychain cleanup failed (${e.runtimeType}).',
        name: 'auth',
        level: 900,
      );
    }
  }
}
