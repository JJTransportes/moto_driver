part of 'login_bloc.dart';

sealed class LoginState {
  const LoginState();
}

final class LoginInitial extends LoginState {
  const LoginInitial();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LoginInitial && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class LoginLoading extends LoginState {
  const LoginLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LoginLoading && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class LoginSuccess extends LoginState {
  final UserEntity user;

  const LoginSuccess(this.user);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginSuccess && runtimeType == other.runtimeType && user == other.user;

  @override
  int get hashCode => user.hashCode;
}

final class LoginFailure extends LoginState {
  final String message;

  const LoginFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginFailure && runtimeType == other.runtimeType && message == other.message;

  @override
  int get hashCode => message.hashCode;
}
