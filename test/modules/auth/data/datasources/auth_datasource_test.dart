import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/data/datasources/auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AuthDatasource datasource;

  setUp(() {
    mockDio = MockDio();
    datasource = AuthDatasource(mockDio);
  });

  const validResponse = {
    'accessToken': 'tok_123',
    'expiresAt': '2026-06-09T00:15:00Z',
    'userId': 'user_1',
    'roles': ['Driver'],
  };

  group('signIn', () {
    test('returns SignInResponseModel on success', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: validResponse,
          statusCode: 200,
        ),
      );

      final result = await datasource.signIn('joao@moto.com', '123456');

      expect(result, isA<SignInResponseModel>());
      expect(result.accessToken, 'tok_123');
      expect(result.userId, 'user_1');
      expect(result.roles, ['Driver']);
      expect(result.expiresAt, DateTime.utc(2026, 6, 9, 0, 15));

      verify(() => mockDio.post(
            '/api/auth/sign-in',
            data: {'email': 'joao@moto.com', 'password': '123456'},
          )).called(1);
    });

    test('throws UnauthorizedException on 401', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
          ),
        ),
      );

      expect(
        () => datasource.signIn('joao@moto.com', 'wrong'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws NotFoundException on 404', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 404,
          ),
        ),
      );

      expect(
        () => datasource.signIn('unknown@moto.com', '123'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('throws ValidationException on 400', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 400,
          ),
        ),
      );

      expect(
        () => datasource.signIn('', ''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws RateLimitedException on 429', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 429,
          ),
        ),
      );

      expect(
        () => datasource.signIn('joao@moto.com', '123'),
        throwsA(isA<RateLimitedException>()),
      );
    });

    test('throws ServerException on 500', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 500,
          ),
        ),
      );

      expect(
        () => datasource.signIn('joao@moto.com', '123'),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NetworkException on connection error', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => datasource.signIn('joao@moto.com', '123'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
