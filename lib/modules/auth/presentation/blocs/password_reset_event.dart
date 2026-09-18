abstract class PasswordResetEvent {
  const PasswordResetEvent();
}

class ResetConfirmSubmitted extends PasswordResetEvent {
  final String newPassword;

  const ResetConfirmSubmitted({required this.newPassword});
}
