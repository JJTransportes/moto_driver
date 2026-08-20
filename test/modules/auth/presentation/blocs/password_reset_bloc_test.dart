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

  PasswordResetBloc build() => PasswordResetBloc(usecase, email: 'joao@moto.com');

  group('PasswordResetBloc', () {
    blocTest<PasswordResetBloc, PasswordResetState>(
      'emite [Submitting, Success] em 200',
      build: () {
        when(() => usecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer((_) async => Success(unit));
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(code: '123456', newPassword: 'NovaSenha@1')),
      expect: () => [
        const PasswordResetSubmitting(),
        const PasswordResetSuccess(),
      ],
      verify: (_) {
        verify(() => usecase.call(
              email: 'joao@moto.com',
              code: '123456',
              newPassword: 'NovaSenha@1',
            )).called(1);
      },
    );

    // 400 cobre código inválido/expirado E senha fora da política com o
    // mesmo status — a mensagem do servidor é repassada como está, sem CTA
    // de "pedir novo código" (não dá pra saber qual dos dois motivos foi).
    blocTest<PasswordResetBloc, PasswordResetState>(
      'em 400, expõe a mensagem do servidor sem marcar o código como consumido',
      build: () {
        when(() => usecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer(
          (_) async => Failure(const ValidationException('Código inválido ou expirado.')),
        );
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(code: '000000', newPassword: 'x')),
      expect: () => [
        const PasswordResetSubmitting(),
        isA<PasswordResetState>()
            .having((s) => (s as PasswordResetError).message, 'message', 'Código inválido ou expirado.')
            .having((s) => (s as PasswordResetError).codeConsumed, 'codeConsumed', isFalse),
      ],
    );

    // 409 é o único caso em que o status HTTP sozinho garante a causa
    // (código já utilizado) — por isso oferece a ação de pedir um novo código.
    blocTest<PasswordResetBloc, PasswordResetState>(
      'em 409, marca o código como consumido',
      build: () {
        when(() => usecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer(
          (_) async => Failure(const ConflictException('Este código já foi utilizado.')),
        );
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(code: '123456', newPassword: 'NovaSenha@1')),
      expect: () => [
        const PasswordResetSubmitting(),
        isA<PasswordResetState>()
            .having((s) => (s as PasswordResetError).codeConsumed, 'codeConsumed', isTrue),
      ],
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'em 429, expõe a mensagem de rate limit',
      build: () {
        when(() => usecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer(
          (_) async => Failure(const RateLimitedException()),
        );
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(code: '123456', newPassword: 'NovaSenha@1')),
      expect: () => [
        const PasswordResetSubmitting(),
        isA<PasswordResetError>().having((e) => e.codeConsumed, 'codeConsumed', isFalse),
      ],
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'usa o email fixo do bloc, não um vindo do evento',
      build: () {
        when(() => usecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer((_) async => Success(unit));
        return build();
      },
      act: (bloc) => bloc.add(const ResetConfirmSubmitted(code: '123456', newPassword: 'NovaSenha@1')),
      verify: (_) {
        verify(() => usecase.call(
              email: 'joao@moto.com',
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).called(1);
      },
    );
  });
}
