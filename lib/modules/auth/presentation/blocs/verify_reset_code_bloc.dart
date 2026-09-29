import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_verify_reset_code_usecase.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/verify_reset_code_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/verify_reset_code_state.dart';

class VerifyResetCodeBloc extends Bloc<VerifyResetCodeEvent, VerifyResetCodeState> {
  final IVerifyResetCodeUsecase _verifyResetCodeUsecase;
  final String email;

  /// O backend permite no máximo 5 tentativas erradas por e-mail antes de
  /// bloquear com 429 (ver contexto do backend). O app não recebe esse
  /// contador — só sabe que estourou quando toma o 429 — então mantemos uma
  /// contagem local só para orientar visualmente o usuário.
  static const _maxAttempts = 5;
  int _wrongAttempts = 0;

  VerifyResetCodeBloc(this._verifyResetCodeUsecase, {required this.email}) : super(const VerifyCodeInitial()) {
    on<VerifyCodeSubmitted>(_onVerifyCodeSubmitted);
  }

  Future<void> _onVerifyCodeSubmitted(
    VerifyCodeSubmitted event,
    Emitter<VerifyResetCodeState> emit,
  ) async {
    emit(const VerifyCodeSubmitting());

    final result = await _verifyResetCodeUsecase.call(email: email, code: event.code);

    result.fold(
      (resetToken) => emit(VerifyCodeSuccess(resetToken)),
      (error) {
        switch (error) {
          case RateLimitedException():
            // 429: bloqueio de 30 min — não adianta tentar de novo agora.
            emit(VerifyCodeError(error.message, exhausted: true));
          case ValidationException():
            _wrongAttempts++;
            emit(VerifyCodeError(_buildAttemptsMessage(error.message)));
          case ConflictException():
            emit(VerifyCodeError(error.message));
          default:
            emit(const VerifyCodeError(
              'Erro ao verificar o código. Verifique sua conexão e tente novamente.',
            ));
        }
      },
    );
  }

  /// A partir da 3ª tentativa errada, avisa quantas tentativas restam antes
  /// do bloqueio (RF1) — heurística local, o backend não devolve contador.
  String _buildAttemptsMessage(String serverMessage) {
    if (_wrongAttempts < 3) return serverMessage;
    final remaining = _maxAttempts - _wrongAttempts;
    if (remaining <= 0) return serverMessage;
    return '$serverMessage Restam $remaining tentativas.';
  }
}
