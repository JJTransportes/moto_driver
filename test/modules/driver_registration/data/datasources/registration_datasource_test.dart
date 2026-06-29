import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/driver_registration/data/datasources/registration_datasource.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late RegistrationDatasource datasource;

  final validParams = RegisterParams(
    fullName: 'João Santos',
    cpf: '987.654.321-00',
    rg: '98.765.432-1',
    birthdate: DateTime(1985, 6, 20),
    email: 'joao@example.com',
    initialPassword: 'securePassword456',
    cnh: '12345678901',
  );

  setUp(() {
    mockDio = MockDio();
    datasource = RegistrationDatasource(mockDio);
  });

  group('register', () {
    test('completes without throwing on 201 success', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 201,
          data: {'registrationId': 'abc-123'},
        ),
      );

      expect(
        () => datasource.register(validParams),
        returnsNormally,
      );
    });

    test('request body contains role Driver and no address field', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 201,
        ),
      );

      await datasource.register(validParams);

      final captured = verify(() => mockDio.post(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;

      final path = captured[0] as String;
      final body = captured[1] as Map<String, dynamic>;

      expect(path, '/api/registrations');
      expect(body['role'], 'Driver');
      expect(body['fullName'], 'João Santos');
      expect(body['email'], 'joao@example.com');
      expect(body['birthdate'], '1985-06-20');
      expect(body.containsKey('address'), isFalse);
      expect(body.containsKey('publicPartitionId'), isFalse);
    });

    test('omits registration and department from body when null', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 201,
        ),
      );

      await datasource.register(validParams);

      final captured = verify(() => mockDio.post(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;
      final body = captured[1] as Map<String, dynamic>;

      expect(body.containsKey('registration'), isFalse);
      expect(body.containsKey('department'), isFalse);
    });

    test('includes registration and department when provided', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 201,
        ),
      );

      final paramsWithOpt = RegisterParams(
        fullName: 'João Santos',
        cpf: '987.654.321-00',
        rg: '98.765.432-1',
        registration: '54321',
        birthdate: DateTime(1985, 6, 20),
        email: 'joao@example.com',
        initialPassword: 'securePassword456',
        department: 'Transportes',
        cnh: '12345678901',
      );

      await datasource.register(paramsWithOpt);

      final captured = verify(() => mockDio.post(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;
      final body = captured[1] as Map<String, dynamic>;

      expect(body['registration'], '54321');
      expect(body['department'], 'Transportes');
    });

    test('throws ValidationException on 400', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 400,
            data: {'error': 'Dados inválidos'},
          ),
        ),
      );

      expect(
        () => datasource.register(validParams),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws DuplicateException on 409', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
            data: {'error': 'Este e-mail já está cadastrado.'},
          ),
        ),
      );

      expect(
        () => datasource.register(validParams),
        throwsA(isA<DuplicateException>()),
      );
    });

    test('throws DuplicateException with field on 409 with CPF duplicate',
        () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
            data: {'error': 'CPF already registered'},
          ),
        ),
      );

      try {
        await datasource.register(validParams);
        fail('Expected DuplicateException');
      } catch (e) {
        expect(e, isA<DuplicateException>());
        expect((e as DuplicateException).field, 'cpf');
      }
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => datasource.register(validParams),
        throwsA(isA<NetworkException>()),
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
        () => datasource.register(validParams),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
