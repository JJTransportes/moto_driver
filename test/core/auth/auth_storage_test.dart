import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage secure;
  late AuthStorage storage;

  /// Maior número de operações simultâneas observado.
  late int maxConcurrent;

  setUp(() {
    secure = MockSecureStorage();
    storage = AuthStorage(storage: secure);
    maxConcurrent = 0;
  });

  /// Faz a operação demorar alguns ms e registra a concorrência real.
  void trackConcurrency(void Function() stub) {
    var active = 0;
    Future<void> body() async {
      active++;
      maxConcurrent = max(maxConcurrent, active);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      active--;
    }

    when(() => secure.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) => body());
    when(() => secure.delete(key: any(named: 'key')))
        .thenAnswer((_) => body());
    stub();
  }

  group('saveToken', () {
    // R2: escritas concorrentes fazem o flutter_secure_storage_web gerar duas
    // chaves AES, e a última sobrescreve a outra — o valor da primeira escrita
    // fica indecifrável (OperationError).
    test('grava token e userId sequencialmente, nunca em paralelo', () async {
      trackConcurrency(() {});

      await storage.saveToken('tok_123', 'user_1');

      expect(maxConcurrent, 1,
          reason: 'as escritas no secure storage não podem se sobrepor');
    });

    test('grava as duas chaves, na ordem', () async {
      trackConcurrency(() {});

      await storage.saveToken('tok_123', 'user_1');

      verifyInOrder([
        () => secure.write(key: 'moto_driver_token', value: 'tok_123'),
        () => secure.write(key: 'moto_driver_user_id', value: 'user_1'),
      ]);
    });
  });

  group('clear', () {
    test('remove as três chaves sequencialmente', () async {
      trackConcurrency(() {});

      await storage.clear();

      expect(maxConcurrent, 1);
      verifyInOrder([
        () => secure.delete(key: 'moto_driver_token'),
        () => secure.delete(key: 'moto_driver_refresh_token'),
        () => secure.delete(key: 'moto_driver_user_id'),
      ]);
    });
  });

  group('leitura', () {
    test('getToken devolve o valor armazenado', () async {
      when(() => secure.read(key: 'moto_driver_token'))
          .thenAnswer((_) async => 'tok_123');

      expect(await storage.getToken(), 'tok_123');
    });

    test('getToken propaga erro não tratado para o chamador', () async {
      // O AuthInterceptor é quem protege a requisição (ver dio_client_test).
      when(() => secure.read(key: 'moto_driver_token'))
          .thenThrow(Exception('OperationError'));

      expect(() => storage.getToken(), throwsA(isA<Exception>()));
    });
  });
}
