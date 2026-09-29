abstract class VerifyResetCodeEvent {
  const VerifyResetCodeEvent();
}

class VerifyCodeSubmitted extends VerifyResetCodeEvent {
  final String code;

  const VerifyCodeSubmitted(this.code);
}
