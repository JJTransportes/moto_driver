part of 'register_bloc.dart';

sealed class RegisterState {
  const RegisterState();
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

final class RegisterLoading extends RegisterState {
  const RegisterLoading();
}

final class RegisterSuccess extends RegisterState {
  const RegisterSuccess();
}

final class RegisterFailure extends RegisterState {
  final String message;

  /// Campo específico rejeitado pelo backend (ex.: 'email', 'cpf', 'cnh'),
  /// quando aplicável — usado pela tela para destacar o input errado e
  /// bloquear o botão até ele ser corrigido. Null para erros genéricos
  /// (rede, servidor, etc.).
  final String? field;

  const RegisterFailure(this.message, {this.field});
}
