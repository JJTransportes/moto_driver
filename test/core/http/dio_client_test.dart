import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/http/dio_client.dart';

class MockAuthStorage extends Mock implements AuthStorage {}

/// Adapter que captura as opções da requisição em vez de ir à rede.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? captured;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late MockAuthStorage storage;
  late _CapturingAdapter adapter;
  late Dio dio;

  setUp(() {
    storage = MockAuthStorage();
    adapter = _CapturingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(storage));
  });

  group('AuthInterceptor', () {
    test('injeta o header Authorization quando há token', () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'tok_123');

      await dio.get('/qualquer');

      expect(adapter.captured?.headers['Authorization'], 'Bearer tok_123');
    });

    test('envia a requisição sem Authorization quando não há token', () async {
      when(() => storage.getToken()).thenAnswer((_) async => null);

      await dio.get('/qualquer');

      expect(adapter.captured, isNotNull);
      expect(adapter.captured?.headers.containsKey('Authorization'), isFalse);
    });

    // R1: o defeito original — a leitura do token lançava e o onRequest
    // terminava sem next()/reject(), pendurando a requisição para sempre.
    test(
      'quando a leitura do token falha, a requisição ainda é enviada, sem Authorization',
      () async {
        when(() => storage.getToken()).thenThrow(Exception('OperationError'));

        final response = await dio
            .get('/qualquer')
            .timeout(const Duration(seconds: 2));

        expect(response.statusCode, 200);
        expect(adapter.captured, isNotNull,
            reason: 'a requisição precisa chegar ao adapter');
        expect(adapter.captured?.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('a falha na leitura do token não pendura o Future', () async {
      when(() => storage.getToken()).thenThrow(Exception('OperationError'));

      // Se o interceptor não chamar next()/reject(), isso estoura por timeout.
      await expectLater(
        dio.get('/qualquer').timeout(const Duration(seconds: 2)),
        completes,
      );
    });
  });
}
