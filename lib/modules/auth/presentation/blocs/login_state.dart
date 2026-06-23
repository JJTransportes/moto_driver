part of 'login_bloc.dart';

sealed class LoginState {
  const LoginState();
}

final class LoginInitial extends LoginState {
  const LoginInitial();
}

final class LoginLoading extends LoginState {
  const LoginLoading();
}

final class LoginSuccess extends LoginState {
  final UserEntity user;

  const LoginSuccess(this.user);
}

final class LoginFailure extends LoginState {
  final String message;

  const LoginFailure(this.message);
}
