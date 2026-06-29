part of 'register_bloc.dart';

sealed class RegisterEvent {
  const RegisterEvent();
}

final class RegisterSubmitted extends RegisterEvent {
  final RegisterParams params;

  const RegisterSubmitted(this.params);
}
