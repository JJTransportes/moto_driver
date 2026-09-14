abstract class VerifyResetCodeState {
  const VerifyResetCodeState();
}

class VerifyCodeInitial extends VerifyResetCodeState {
  const VerifyCodeInitial();
}

class VerifyCodeSubmitting extends VerifyResetCodeState {
  const VerifyCodeSubmitting();
}

class VerifyCodeSuccess extends VerifyResetCodeState {
  final String resetToken;

  const VerifyCodeSuccess(this.resetToken);
}

class VerifyCodeError extends VerifyResetCodeState {
  final String message;

  /// true no 429 (bloqueio de 30 min por excesso de tentativas erradas) —
  /// nesse caso não adianta tentar de novo, só pedir um código novo.
  final bool exhausted;

  const VerifyCodeError(this.message, {this.exhausted = false});

  @override
  bool operator ==(Object other) =>
      other is VerifyCodeError && other.message == message && other.exhausted == exhausted;

  @override
  int get hashCode => Object.hash(message, exhausted);
}
