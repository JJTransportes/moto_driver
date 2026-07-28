import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_login_usecase.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final ILoginUsecase _loginUsecase;
  final AuthStorage _authStorage;
  final AuthLocalRepository _authLocal;

  LoginBloc(this._loginUsecase, this._authStorage, this._authLocal) : super(const LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());

    final result = await _loginUsecase.call(event.email, event.password);

    if (result.isSuccess()) {
      final user = result.getOrNull()!;
      await _authStorage.saveToken(user.token, user.id);
      if (user.refreshToken != null) {
        await _authStorage.saveRefreshToken(user.refreshToken!);
      }
      await _authLocal.saveAuth(
        userId: user.id,
        accessToken: user.token,
        roles: user.roles,
      );
      await NotificationService.login(user.id);
      emit(LoginSuccess(user));
    } else {
      emit(LoginFailure(result.exceptionOrNull()!.toString()));
    }
  }
}
