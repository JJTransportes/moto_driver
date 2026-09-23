abstract class PasswordRecoveryState {
  const PasswordRecoveryState();
}

class PasswordRecoveryInitial extends PasswordRecoveryState {
  const PasswordRecoveryInitial();
}

class PasswordRecoveryLoading extends PasswordRecoveryState {
  const PasswordRecoveryLoading();
}

/// Emitido em caso de sucesso da requisição (202).
class PasswordRecoverySent extends PasswordRecoveryState {
  final String email;

  const PasswordRecoverySent(this.email);

  @override
  bool operator ==(Object other) => other is PasswordRecoverySent && other.email == email;

  @override
  int get hashCode => email.hashCode;
}

/// Erro exibido na própria tela, sem navegar — inclui e-mail não
/// cadastrado (404), rate limit, rede e servidor.
class PasswordRecoveryError extends PasswordRecoveryState {
  final String message;

  const PasswordRecoveryError(this.message);

  @override
  bool operator ==(Object other) => other is PasswordRecoveryError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}
