abstract class PasswordRecoveryState {
  const PasswordRecoveryState();
}

class PasswordRecoveryInitial extends PasswordRecoveryState {
  const PasswordRecoveryInitial();
}

class PasswordRecoveryLoading extends PasswordRecoveryState {
  const PasswordRecoveryLoading();
}

/// Sempre emitido em caso de sucesso da requisição — inclusive quando o
/// e-mail não está cadastrado (404), de propósito: a tela não pode revelar
/// se um e-mail existe ou não na base.
class PasswordRecoverySent extends PasswordRecoveryState {
  final String email;

  const PasswordRecoverySent(this.email);

  @override
  bool operator ==(Object other) => other is PasswordRecoverySent && other.email == email;

  @override
  int get hashCode => email.hashCode;
}

/// Só chega aqui em falha real (rate limit, rede, servidor) — nunca por
/// e-mail não encontrado.
class PasswordRecoveryError extends PasswordRecoveryState {
  final String message;

  const PasswordRecoveryError(this.message);

  @override
  bool operator ==(Object other) => other is PasswordRecoveryError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}
