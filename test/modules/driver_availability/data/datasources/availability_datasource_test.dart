import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/driver_availability/data/datasources/availability_datasource.dart';
import 'package:moto_driver/modules/driver_availability/domain/entities/driver_availability_entity.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AvailabilityDatasource datasource;

  setUp(() {
    mockDio = MockDio();
    datasource = AvailabilityDatasource(mockDio);
  });

  const activeResponse = {
    'status': 'active',
    'activatedAt': '2026-08-14T10:00:00Z',
    'expiresAt': '2026-08-14T14:00:00Z',
  };

  const inactiveResponse = {
    'status': 'inactive',
    'activatedAt': null,
    'expiresAt': null,
  };

  group('getAvailability', () {
    test('returns entity on success (active)', () async {
      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: activeResponse,
          statusCode: 200,
        ),
      );

      final result = await datasource.getAvailability();

      expect(result, isA<DriverAvailabilityEntity>());
      expect(result.status, 'active');
      expect(result.isActive, isTrue);
      expect(result.expiresAt, DateTime.parse('2026-08-14T14:00:00Z'));

      verify(() => mockDio.get('/api/drivers/availability')).called(1);
    });

    test('returns entity on success (inactive)', () async {
      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: inactiveResponse,
          statusCode: 200,
        ),
      );

      final result = await datasource.getAvailability();

      expect(result.isActive, isFalse);
      expect(result.activatedAt, isNull);
      expect(result.expiresAt, isNull);
    });

    test('throws UnauthorizedException on 401', () async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
          ),
        ),
      );

      expect(
        () => datasource.getAvailability(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ServerException on 500', () async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 500,
          ),
        ),
      );

      expect(
        () => datasource.getAvailability(),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NetworkException on connection error', () async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => datasource.getAvailability(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('activate', () {
    test('envia POST no endpoint de intenção com body action=activate',
        () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: activeResponse,
          statusCode: 200,
        ),
      );

      final result = await datasource.activate();

      expect(result, isA<DriverAvailabilityEntity>());
      expect(result.status, 'active');
      expect(result.isActive, isTrue);

      verify(
        () => mockDio.post(
          '/api/drivers/availability/update',
          data: {'action': 'activate'},
        ),
      ).called(1);
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
        () => datasource.activate(),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NetworkException on connection error', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => datasource.activate(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('deactivate', () {
    test('envia POST no endpoint de intenção com body action=deactivate',
        () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: inactiveResponse,
          statusCode: 200,
        ),
      );

      final result = await datasource.deactivate();

      expect(result.isActive, isFalse);
      expect(result.activatedAt, isNull);
      expect(result.expiresAt, isNull);

      verify(
        () => mockDio.post(
          '/api/drivers/availability/update',
          data: {'action': 'deactivate'},
        ),
      ).called(1);
    });

    test('mapeia 401 para UnauthorizedException', () async {
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
        () => datasource.deactivate(),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}
