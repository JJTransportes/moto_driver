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
    test('não lança em 202 (aceito) e envia expectedRole "Driver"', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 202),
      );

      await expectLater(datasource.requestPasswordReset('joao@moto.com'), completes);

      verify(() => mockDio.post(
            '/api/auth/password-reset/request',
            data: {'email': 'joao@moto.com', 'expectedRole': 'Driver'},
          )).called(1);
    });

    test('lança NotFoundException em 404 (e-mail não cadastrado) com a mensagem do servidor', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        withStatus(404, data: {'error': 'Email não cadastrado.'}),
      );

      expect(
        () => datasource.requestPasswordReset('inexistente@moto.com'),
        throwsA(
          isA<NotFoundException>().having((e) => e.message, 'message', 'Email não cadastrado.'),
        ),
      );
    });

    test('lança NotFoundException com mensagem padrão quando o corpo não traz o campo "error"', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(404));

      expect(
        () => datasource.requestPasswordReset('inexistente@moto.com'),
        throwsA(
          isA<NotFoundException>().having((e) => e.message, 'message', 'Email não cadastrado.'),
        ),
      );
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

  group('verifyResetCode', () {
    test('retorna o resetToken em 200', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {'resetToken': '8f4a1c2e-guid'},
        ),
      );

      final token = await datasource.verifyResetCode(email: 'joao@moto.com', code: '123456');

      expect(token, '8f4a1c2e-guid');
      verify(() => mockDio.post(
            '/api/auth/password-reset/verify-code',
            data: {'email': 'joao@moto.com', 'code': '123456'},
          )).called(1);
    });

    test('lança ValidationException em 400 (código inválido/expirado)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        withStatus(400, data: {'error': 'Código inválido ou expirado.'}),
      );

      expect(
        () => datasource.verifyResetCode(email: 'joao@moto.com', code: '000000'),
        throwsA(
          isA<ValidationException>().having((e) => e.message, 'message', 'Código inválido ou expirado.'),
        ),
      );
    });

    test('lança ConflictException em 409 (código já usado)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        withStatus(409, data: {'error': 'Este código já foi utilizado.'}),
      );

      expect(
        () => datasource.verifyResetCode(email: 'joao@moto.com', code: '123456'),
        throwsA(
          isA<ConflictException>().having((e) => e.message, 'message', 'Este código já foi utilizado.'),
        ),
      );
    });

    test('lança RateLimitedException em 429 (muitas tentativas erradas)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(429));

      expect(
        () => datasource.verifyResetCode(email: 'joao@moto.com', code: '123456'),
        throwsA(isA<RateLimitedException>()),
      );
    });
  });

  group('confirmPasswordReset', () {
    test('não lança em 200', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
      );

      await expectLater(
        datasource.confirmPasswordReset(resetToken: 'reset-tok-1', newPassword: 'NovaSenha@1'),
        completes,
      );
    });

    test('envia apenas resetToken e newPassword (sem email/code)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
      );

      await datasource.confirmPasswordReset(resetToken: 'reset-tok-1', newPassword: 'NovaSenha@1');

      verify(() => mockDio.post(
            '/api/auth/password-reset/confirm',
            data: {'resetToken': 'reset-tok-1', 'newPassword': 'NovaSenha@1'},
          )).called(1);
    });

    test('lança ValidationException em 400 com a mensagem do servidor (campo "error")', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        withStatus(400, data: {'error': 'Token inválido ou expirado.'}),
      );

      expect(
        () => datasource.confirmPasswordReset(resetToken: 'reset-tok-1', newPassword: 'x'),
        throwsA(
          isA<ValidationException>().having((e) => e.message, 'message', 'Token inválido ou expirado.'),
        ),
      );
    });

    test('lança ConflictException em 409 com a mensagem do servidor', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        withStatus(409, data: {'error': 'Este código já foi utilizado.'}),
      );

      expect(
        () => datasource.confirmPasswordReset(resetToken: 'reset-tok-1', newPassword: 'NovaSenha@1'),
        throwsA(
          isA<ConflictException>().having((e) => e.message, 'message', 'Este código já foi utilizado.'),
        ),
      );
    });

    test('usa mensagem padrão quando o corpo não traz o campo "error"', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(400));

      expect(
        () => datasource.confirmPasswordReset(resetToken: 'reset-tok-1', newPassword: 'x'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('lança RateLimitedException em 429', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(withStatus(429));

      expect(
        () => datasource.confirmPasswordReset(resetToken: 'reset-tok-1', newPassword: 'NovaSenha@1'),
        throwsA(isA<RateLimitedException>()),
      );
    });
  });
}
