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

  /// 409 (código já utilizado): o único caso em que o status HTTP sozinho
  /// garante a causa, então oferecemos uma ação específica — pedir um código
  /// novo. O 400 cobre código inválido/expirado E senha fora da política com
  /// o mesmo status; só a mensagem do servidor distingue os dois, e ela já é
  /// exibida — não tentamos adivinhar qual campo corrigir.
  final bool codeConsumed;

  const PasswordResetError(this.message, {this.codeConsumed = false});

  @override
  bool operator ==(Object other) =>
      other is PasswordResetError && other.message == message && other.codeConsumed == codeConsumed;

  @override
  int get hashCode => Object.hash(message, codeConsumed);
}
