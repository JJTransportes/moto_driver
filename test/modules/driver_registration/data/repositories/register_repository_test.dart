import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/modules/driver_registration/data/datasources/i_registration_datasource.dart';
import 'package:moto_driver/modules/driver_registration/data/repositories/register_repository.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';

class MockRegistrationDatasource extends Mock
    implements IRegistrationDatasource {}

void main() {
  late MockRegistrationDatasource mockDatasource;
  late RegisterRepository repository;

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
    mockDatasource = MockRegistrationDatasource();
    repository = RegisterRepository(mockDatasource);
    registerFallbackValue(validParams);
  });

  group('register', () {
    test('returns Success when datasource succeeds', () async {
      when(() => mockDatasource.register(any())).thenAnswer((_) async {});

      final result = await repository.register(validParams);

      expect(result.isSuccess(), isTrue);
    });

    test('returns Failure when datasource throws', () async {
      final exception = Exception('Test error');
      when(() => mockDatasource.register(any())).thenThrow(exception);

      final result = await repository.register(validParams);

      expect(result.isSuccess(), isFalse);
      expect(result.exceptionOrNull(), exception);
    });
  });
}
