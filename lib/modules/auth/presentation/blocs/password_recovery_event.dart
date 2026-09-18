abstract class PasswordRecoveryEvent {
  const PasswordRecoveryEvent();
}

class RequestCodeSubmitted extends PasswordRecoveryEvent {
  final String email;

  const RequestCodeSubmitted(this.email);
}
