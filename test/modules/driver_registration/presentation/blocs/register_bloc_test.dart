import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/i_register_usecase.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';
import 'package:moto_driver/modules/driver_registration/presentation/blocs/register_bloc.dart';
import 'package:result_dart/result_dart.dart';

class MockRegisterUsecase extends Mock implements IRegisterUsecase {}

void main() {
  late MockRegisterUsecase mockUsecase;

  final validParams = RegisterParams(
    fullName: 'João Santos',
    cpf: '987.654.321-00',
    rg: '98.765.432-1',
    birthdate: DateTime(1985, 6, 20),
    email: 'joao@example.com',
    initialPassword: 'securePassword456',
    cnh: '12345678901',
  );

  setUpAll(() {
    registerFallbackValue(validParams);
  });

  setUp(() {
    mockUsecase = MockRegisterUsecase();
  });

  group('RegisterBloc', () {
    blocTest<RegisterBloc, RegisterState>(
      'emits [RegisterLoading, RegisterSuccess] when registration succeeds',
      build: () {
        when(() => mockUsecase.call(any()))
            .thenAnswer((_) async => const Success(unit));
        return RegisterBloc(mockUsecase);
      },
      act: (bloc) => bloc.add(RegisterSubmitted(validParams)),
      expect: () => [
        isA<RegisterLoading>(),
        isA<RegisterSuccess>(),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      'emits [RegisterLoading, RegisterFailure] when registration fails',
      build: () {
        when(() => mockUsecase.call(any())).thenAnswer(
          (_) async => Failure(Exception('Este e-mail já está cadastrado.')),
        );
        return RegisterBloc(mockUsecase);
      },
      act: (bloc) => bloc.add(RegisterSubmitted(validParams)),
      expect: () => [
        isA<RegisterLoading>(),
        isA<RegisterFailure>(),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      'calls usecase with correct params',
      build: () {
        when(() => mockUsecase.call(any()))
            .thenAnswer((_) async => const Success(unit));
        return RegisterBloc(mockUsecase);
      },
      act: (bloc) => bloc.add(RegisterSubmitted(validParams)),
      verify: (_) {
        verify(() => mockUsecase.call(validParams)).called(1);
      },
    );
  });
}
