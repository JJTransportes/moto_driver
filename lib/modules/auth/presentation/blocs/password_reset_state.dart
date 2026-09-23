abstract class PasswordResetState {
  const PasswordResetState();
}

class PasswordResetInitial extends PasswordResetState {
  const PasswordResetInitial();
}

class PasswordResetSubmitting extends PasswordResetState {
  const PasswordResetSubmitting();
}

class PasswordResetSuccess extends PasswordResetState {
  const PasswordResetSuccess();
}

class PasswordResetError extends PasswordResetState {
  final String message;

  /// No novo contrato (resetToken em vez de email+code), tanto o 409 (token
  /// já usado) quanto o 400 (token inválido/expirado) tornam o resetToken
  /// atual inutilizável — nos dois casos oferecemos a ação "pedir um novo
  /// código", que manda o usuário de volta para a tela 1. A mensagem do
  /// servidor continua exibida como está (o 400 também pode ser "senha fora
  /// da política", mas isso é filtrado client-side antes do submit — ver
  /// design D3/D5 — então na prática quase sempre é token).
  final bool canRequestNewCode;

  const PasswordResetError(this.message, {this.canRequestNewCode = false});

  @override
  bool operator ==(Object other) =>
      other is PasswordResetError && other.message == message && other.canRequestNewCode == canRequestNewCode;

  @override
  int get hashCode => Object.hash(message, canRequestNewCode);
}
