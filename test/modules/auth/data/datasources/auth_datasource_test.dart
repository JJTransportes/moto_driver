import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/data/datasources/auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
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

  const refreshResponse = {
    'accessToken': 'new_access_123',
    'refreshToken': 'new_refresh_456',
    'expiresAt': '2026-07-13T12:30:00Z',
    'refreshExpiresAt': '2026-08-12T12:30:00Z',
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

      final result = await datasource.signIn('joao@moto.com', '123456', 'android');

      expect(result, isA<SignInResponseModel>());
      expect(result.accessToken, 'tok_123');
      expect(result.userId, 'user_1');
      expect(result.roles, ['Driver']);
      expect(result.expiresAt, DateTime.utc(2026, 6, 9, 0, 15));

      verify(() => mockDio.post(
            '/api/auth/sign-in',
            data: {
              'email': 'joao@moto.com',
              'password': '123456',
              'device': 'android',
            },
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
        () => datasource.signIn('joao@moto.com', 'wrong', 'android'),
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
        () => datasource.signIn('unknown@moto.com', '123', 'android'),
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
        () => datasource.signIn('', '', 'android'),
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
        () => datasource.signIn('joao@moto.com', '123', 'android'),
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
        () => datasource.signIn('joao@moto.com', '123', 'android'),
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
        () => datasource.signIn('joao@moto.com', '123', 'android'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws DeviceConflictException on 409 (device binding)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
            data: {
              'message': 'A session is already active on a different device type. Sign out there first.',
            },
          ),
        ),
      );

      expect(
        () => datasource.signIn('joao@moto.com', '123', 'ios'),
        throwsA(isA<DeviceConflictException>()),
      );
    });
  });

  group('refreshToken', () {
    test('returns RefreshTokenResponseModel on success', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: refreshResponse,
          statusCode: 200,
        ),
      );

      final result = await datasource.refreshToken('old_refresh_token', 'android');

      expect(result, isA<RefreshTokenResponseModel>());
      expect(result.accessToken, 'new_access_123');
      expect(result.refreshToken, 'new_refresh_456');
      expect(result.userId, 'user_1');
      expect(result.roles, ['Driver']);
      expect(result.expiresAt, DateTime.utc(2026, 7, 13, 12, 30));
      expect(result.refreshExpiresAt, DateTime.utc(2026, 8, 12, 12, 30));

      verify(() => mockDio.post(
            '/api/auth/refresh',
            data: {'refreshToken': 'old_refresh_token', 'device': 'android'},
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
        () => datasource.refreshToken('expired_refresh', 'android'),
        throwsA(isA<UnauthorizedException>()),
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
        () => datasource.refreshToken('', 'android'),
        throwsA(isA<ValidationException>()),
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
        () => datasource.refreshToken('some_token', 'android'),
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
        () => datasource.refreshToken('some_token', 'android'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws DeviceMismatchException on 403 (device binding)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 403,
          ),
        ),
      );

      expect(
        () => datasource.refreshToken('some_token', 'ios'),
        throwsA(isA<DeviceMismatchException>()),
      );
    });
  });
}
