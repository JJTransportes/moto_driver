import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_request_password_reset_usecase.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_recovery_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_recovery_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_recovery_state.dart';
import 'package:result_dart/result_dart.dart';

class MockRequestPasswordResetUsecase extends Mock implements IRequestPasswordResetUsecase {}

void main() {
  late MockRequestPasswordResetUsecase usecase;

  setUp(() {
    usecase = MockRequestPasswordResetUsecase();
  });

  group('PasswordRecoveryBloc', () {
    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'emite [Loading, Sent] em sucesso (202)',
      build: () {
        when(() => usecase.call(any())).thenAnswer((_) async => Success(unit));
        return PasswordRecoveryBloc(usecase);
      },
      act: (bloc) => bloc.add(const RequestCodeSubmitted('joao@moto.com')),
      expect: () => [
        const PasswordRecoveryLoading(),
        const PasswordRecoverySent('joao@moto.com'),
      ],
    );

    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'emite erro "Email não cadastrado." em 404, sem navegar',
      build: () {
        when(() => usecase.call(any())).thenAnswer(
          (_) async => Failure(const NotFoundException('Email não cadastrado.')),
        );
        return PasswordRecoveryBloc(usecase);
      },
      act: (bloc) => bloc.add(const RequestCodeSubmitted('inexistente@moto.com')),
      expect: () => [
        const PasswordRecoveryLoading(),
        isA<PasswordRecoveryError>().having(
          (e) => e.message,
          'message',
          'Email não cadastrado.',
        ),
      ],
    );

    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'emite mensagem de rate limit em 429',
      build: () {
        when(() => usecase.call(any())).thenAnswer(
          (_) async => Failure(const RateLimitedException()),
        );
        return PasswordRecoveryBloc(usecase);
      },
      act: (bloc) => bloc.add(const RequestCodeSubmitted('joao@moto.com')),
      expect: () => [
        const PasswordRecoveryLoading(),
        isA<PasswordRecoveryError>().having(
          (e) => e.message,
          'message',
          const RateLimitedException().message,
        ),
      ],
    );

    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'emite mensagem genérica de conexão em falha de rede',
      build: () {
        when(() => usecase.call(any())).thenAnswer(
          (_) async => Failure(const NetworkException()),
        );
        return PasswordRecoveryBloc(usecase);
      },
      act: (bloc) => bloc.add(const RequestCodeSubmitted('joao@moto.com')),
      expect: () => [
        const PasswordRecoveryLoading(),
        isA<PasswordRecoveryError>(),
      ],
    );
  });
}
