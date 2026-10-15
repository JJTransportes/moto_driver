import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/auth/first_run_session_cleaner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage storage;

  setUp(() {
    storage = _MockSecureStorage();
    when(() => storage.deleteAll()).thenAnswer((_) async {});
  });

  FirstRunSessionCleaner cleaner({bool isIOS = true}) => FirstRunSessionCleaner(
    storage: storage,
    preferences: SharedPreferences.getInstance,
    isIOS: isIOS,
  );

  test('primeira abertura no iOS: limpa a Keychain e grava a marca', () async {
    SharedPreferences.setMockInitialValues({});

    await cleaner().run();

    verify(() => storage.deleteAll()).called(1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FirstRunSessionCleaner.markerKey), isTrue);
  });

  test('aberturas seguintes: não limpa de novo', () async {
    SharedPreferences.setMockInitialValues({
      FirstRunSessionCleaner.markerKey: true,
    });

    await cleaner().run();

    verifyNever(() => storage.deleteAll());
  });

  test('fora do iOS: não toca na Keychain nem grava a marca', () async {
    SharedPreferences.setMockInitialValues({});

    await cleaner(isIOS: false).run();

    verifyNever(() => storage.deleteAll());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FirstRunSessionCleaner.markerKey), isNull);
  });

  test('falha na limpeza não lança e não grava a marca', () async {
    SharedPreferences.setMockInitialValues({});
    when(() => storage.deleteAll()).thenThrow(Exception('keychain'));

    await cleaner().run();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FirstRunSessionCleaner.markerKey), isNull);
  });
}
