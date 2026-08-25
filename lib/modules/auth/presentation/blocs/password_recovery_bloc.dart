import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_request_password_reset_usecase.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_recovery_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_recovery_state.dart';

class PasswordRecoveryBloc extends Bloc<PasswordRecoveryEvent, PasswordRecoveryState> {
  final IRequestPasswordResetUsecase _requestPasswordResetUsecase;

  PasswordRecoveryBloc(this._requestPasswordResetUsecase) : super(const PasswordRecoveryInitial()) {
    on<RequestCodeSubmitted>(_onRequestCodeSubmitted);
  }

  Future<void> _onRequestCodeSubmitted(
    RequestCodeSubmitted event,
    Emitter<PasswordRecoveryState> emit,
  ) async {
    emit(const PasswordRecoveryLoading());

    final result = await _requestPasswordResetUsecase.call(event.email);

    result.fold(
      (_) => emit(PasswordRecoverySent(event.email)),
      (error) {
        final message = switch (error) {
          RateLimitedException() => error.message,
          _ => 'Erro ao enviar o código. Verifique sua conexão e tente novamente.',
        };
        emit(PasswordRecoveryError(message));
      },
    );
  }
}
