import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/modules/driver_registration/domain/repositories/i_register_repository.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_usecase.dart';
import 'package:result_dart/result_dart.dart';

class MockRegisterRepository extends Mock implements IRegisterRepository {}

void main() {
  late MockRegisterRepository mockRepository;
  late RegisterUsecase usecase;

  final validParams = RegisterParams(
    fullName: 'João Santos',
    cpf: '987.654.321-00',
    rg: '98.765.432-1',
    registration: '12345',
    birthdate: DateTime(1985, 6, 20),
    email: 'joao@example.com',
    initialPassword: 'securePassword456',
    cnh: '12345678901',
  );

  setUp(() {
    mockRepository = MockRegisterRepository();
    usecase = RegisterUsecase(mockRepository);
    registerFallbackValue(validParams);
  });

  group('call', () {
    test('returns Success when repository succeeds', () async {
      when(() => mockRepository.register(any()))
          .thenAnswer((_) async => const Success(unit));

      final result = await usecase.call(validParams);

      expect(result.isSuccess(), isTrue);
    });

    test('returns Failure when repository fails', () async {
      final exception = Exception('Test error');
      when(() => mockRepository.register(any()))
          .thenAnswer((_) async => Failure(exception));

      final result = await usecase.call(validParams);

      expect(result.isSuccess(), isFalse);
      expect(result.exceptionOrNull(), exception);
    });

    test('delegates to repository with correct params', () async {
      when(() => mockRepository.register(any()))
          .thenAnswer((_) async => const Success(unit));

      await usecase.call(validParams);

      verify(() => mockRepository.register(validParams)).called(1);
    });
  });
}
