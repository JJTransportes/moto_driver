import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_verify_reset_code_usecase.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/verify_reset_code_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/verify_reset_code_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/verify_reset_code_state.dart';
import 'package:result_dart/result_dart.dart';

class MockVerifyResetCodeUsecase extends Mock implements IVerifyResetCodeUsecase {}

void main() {
  late MockVerifyResetCodeUsecase usecase;

  setUp(() {
    usecase = MockVerifyResetCodeUsecase();
  });

  VerifyResetCodeBloc build() => VerifyResetCodeBloc(usecase, email: 'joao@moto.com');

  group('VerifyResetCodeBloc', () {
    blocTest<VerifyResetCodeBloc, VerifyResetCodeState>(
      'emite [Submitting, Success] com o resetToken em 200',
      build: () {
        when(() => usecase.call(email: any(named: 'email'), code: any(named: 'code')))
            .thenAnswer((_) async => Success('reset-tok-1'));
        return build();
      },
      act: (bloc) => bloc.add(const VerifyCodeSubmitted('123456')),
      expect: () => [
        const VerifyCodeSubmitting(),
        isA<VerifyCodeSuccess>().having((s) => s.resetToken, 'resetToken', 'reset-tok-1'),
      ],
      verify: (_) {
        verify(() => usecase.call(email: 'joao@moto.com', code: '123456')).called(1);
      },
    );

    blocTest<VerifyResetCodeBloc, VerifyResetCodeState>(
      'nas duas primeiras tentativas erradas, não avisa contagem',
      build: () {
        when(() => usecase.call(email: any(named: 'email'), code: any(named: 'code')))
            .thenAnswer((_) async => Failure(const ValidationException('Código inválido ou expirado.')));
        return build();
      },
      act: (bloc) async {
        bloc.add(const VerifyCodeSubmitted('000000'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const VerifyCodeSubmitted('000001'));
      },
      expect: () => [
        const VerifyCodeSubmitting(),
        isA<VerifyCodeError>().having((e) => e.message, 'message', 'Código inválido ou expirado.'),
        const VerifyCodeSubmitting(),
        isA<VerifyCodeError>().having((e) => e.message, 'message', 'Código inválido ou expirado.'),
      ],
    );

    blocTest<VerifyResetCodeBloc, VerifyResetCodeState>(
      'a partir da 3ª tentativa errada, avisa quantas tentativas restam',
      build: () {
        when(() => usecase.call(email: any(named: 'email'), code: any(named: 'code')))
            .thenAnswer((_) async => Failure(const ValidationException('Código inválido ou expirado.')));
        return build();
      },
      act: (bloc) async {
        for (var i = 0; i < 3; i++) {
          bloc.add(VerifyCodeSubmitted('00000$i'));
          await Future<void>.delayed(Duration.zero);
        }
      },
      skip: 4, // primeiras duas tentativas (Submitting + Error x2)
      expect: () => [
        const VerifyCodeSubmitting(),
        isA<VerifyCodeError>()
            .having((e) => e.message, 'message', 'Código inválido ou expirado. Restam 2 tentativas.'),
      ],
    );

    blocTest<VerifyResetCodeBloc, VerifyResetCodeState>(
      'em 429, emite erro com exhausted = true',
      build: () {
        when(() => usecase.call(email: any(named: 'email'), code: any(named: 'code')))
            .thenAnswer((_) async => Failure(const RateLimitedException()));
        return build();
      },
      act: (bloc) => bloc.add(const VerifyCodeSubmitted('123456')),
      expect: () => [
        const VerifyCodeSubmitting(),
        isA<VerifyCodeError>().having((e) => e.exhausted, 'exhausted', isTrue),
      ],
    );

    blocTest<VerifyResetCodeBloc, VerifyResetCodeState>(
      'em 409, expõe a mensagem do servidor sem marcar exhausted',
      build: () {
        when(() => usecase.call(email: any(named: 'email'), code: any(named: 'code')))
            .thenAnswer((_) async => Failure(const ConflictException('Este código já foi utilizado.')));
        return build();
      },
      act: (bloc) => bloc.add(const VerifyCodeSubmitted('123456')),
      expect: () => [
        const VerifyCodeSubmitting(),
        isA<VerifyCodeError>()
            .having((e) => e.message, 'message', 'Este código já foi utilizado.')
            .having((e) => e.exhausted, 'exhausted', isFalse),
      ],
    );
  });
}
