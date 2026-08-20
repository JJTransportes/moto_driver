import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/data/datasources/auth_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AuthDatasource datasource;

  setUp(() {
    mockDio = MockDio();
    datasource = AuthDatasource(mockDio);
  });

  DioException withStatus(int code, {Object? data}) => DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: code,
          data: data,
        ),
      );

  group('requestPasswordReset', () {
    test('não lança em 202 (aceito)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 202),
      );

      await expectLater(datasource.requestPasswordReset('joao@moto.com'), completes);
    });

    // Anti-enumeração: e-mail não cadastrado não pode ser distinguível de
    // "código enviado" do ponto de vista de quem chama.
    test('não lança em 404 (e-mail não cadastrado) — tratado como sucesso', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(404));

      await expectLater(datasource.requestPasswordReset('inexistente@moto.com'), completes);
    });

    test('lança RateLimitedException em 429', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(429));

      expect(
        () => datasource.requestPasswordReset('joao@moto.com'),
        throwsA(isA<RateLimitedException>()),
      );
    });

    test('lança ServerException em 500', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(500));

      expect(
        () => datasource.requestPasswordReset('joao@moto.com'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('confirmPasswordReset', () {
    test('não lança em 200', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
      );

      await expectLater(
        datasource.confirmPasswordReset(email: 'joao@moto.com', code: '123456', newPassword: 'NovaSenha@1'),
        completes,
      );
    });

    test('lança ValidationException em 400 com a mensagem do servidor (campo "error")', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        withStatus(400, data: {'error': 'Código inválido ou expirado.'}),
      );

      expect(
        () => datasource.confirmPasswordReset(email: 'joao@moto.com', code: '000000', newPassword: 'x'),
        throwsA(
          isA<ValidationException>().having((e) => e.message, 'message', 'Código inválido ou expirado.'),
        ),
      );
    });

    test('lança ConflictException em 409 com a mensagem do servidor', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        withStatus(409, data: {'error': 'Este código já foi utilizado.'}),
      );

      expect(
        () => datasource.confirmPasswordReset(email: 'joao@moto.com', code: '123456', newPassword: 'NovaSenha@1'),
        throwsA(
          isA<ConflictException>().having((e) => e.message, 'message', 'Este código já foi utilizado.'),
        ),
      );
    });

    test('usa mensagem padrão quando o corpo não traz o campo "error"', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(400));

      expect(
        () => datasource.confirmPasswordReset(email: 'joao@moto.com', code: '000000', newPassword: 'x'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('lança RateLimitedException em 429', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(429));

      expect(
        () => datasource.confirmPasswordReset(email: 'joao@moto.com', code: '123456', newPassword: 'NovaSenha@1'),
        throwsA(isA<RateLimitedException>()),
      );
    });
  });
}
