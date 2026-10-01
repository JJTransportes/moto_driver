import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_confirm_password_reset_usecase.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_state.dart';
import 'package:result_dart/result_dart.dart';

class MockConfirmPasswordResetUsecase extends Mock implements IConfirmPasswordResetUsecase {}

void main() {
  late MockConfirmPasswordResetUsecase usecase;

  setUp(() {
    usecase = MockConfirmPasswordResetUsecase();
    registerFallbackValue('');
  });

  PasswordResetBloc build() => PasswordResetBloc(usecase, resetToken: 'reset-tok-1');

  group('PasswordResetBloc', () {
    blocTest<PasswordResetBloc, PasswordResetState>(
      'emite [Submitting, Success] em 200',
      build: () {
        when(() => usecase.call(
              resetToken: any(named: 'resetToken'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer((_) async => Success(unit));
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(newPassword: 'NovaSenha@1')),
      expect: () => [
        const PasswordResetSubmitting(),
        const PasswordResetSuccess(),
      ],
      verify: (_) {
        verify(() => usecase.call(
              resetToken: 'reset-tok-1',
              newPassword: 'NovaSenha@1',
            )).called(1);
      },
    );

    // 400 no novo contrato é quase sempre token inválido/expirado (a senha já
    // foi validada client-side antes do submit) — oferece "pedir novo código".
    blocTest<PasswordResetBloc, PasswordResetState>(
      'em 400, expõe a mensagem do servidor e habilita pedir novo código',
      build: () {
        when(() => usecase.call(
              resetToken: any(named: 'resetToken'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer(
          (_) async => Failure(const ValidationException('Token inválido ou expirado.')),
        );
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(newPassword: 'x')),
      expect: () => [
        const PasswordResetSubmitting(),
        isA<PasswordResetState>()
            .having((s) => (s as PasswordResetError).message, 'message', 'Token inválido ou expirado.')
            .having((s) => (s as PasswordResetError).canRequestNewCode, 'canRequestNewCode', isTrue),
      ],
    );

    // 409 (token já usado) também habilita a ação de pedir um novo código.
    blocTest<PasswordResetBloc, PasswordResetState>(
      'em 409, habilita pedir novo código',
      build: () {
        when(() => usecase.call(
              resetToken: any(named: 'resetToken'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer(
          (_) async => Failure(const ConflictException('Este código já foi utilizado.')),
        );
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(newPassword: 'NovaSenha@1')),
      expect: () => [
        const PasswordResetSubmitting(),
        isA<PasswordResetState>()
            .having((s) => (s as PasswordResetError).canRequestNewCode, 'canRequestNewCode', isTrue),
      ],
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'em 429, expõe a mensagem de rate limit sem oferecer novo código',
      build: () {
        when(() => usecase.call(
              resetToken: any(named: 'resetToken'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer(
          (_) async => Failure(const RateLimitedException()),
        );
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(newPassword: 'NovaSenha@1')),
      expect: () => [
        const PasswordResetSubmitting(),
        isA<PasswordResetError>().having((e) => e.canRequestNewCode, 'canRequestNewCode', isFalse),
      ],
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'usa o resetToken fixo do bloc, não um vindo do evento',
      build: () {
        when(() => usecase.call(
              resetToken: any(named: 'resetToken'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer((_) async => Success(unit));
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(newPassword: 'NovaSenha@1')),
      verify: (_) {
        verify(() => usecase.call(
              resetToken: 'reset-tok-1',
              newPassword: any(named: 'newPassword'),
            )).called(1);
      },
    );
  });
}
