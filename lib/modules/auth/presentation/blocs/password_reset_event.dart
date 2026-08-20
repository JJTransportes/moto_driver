abstract class PasswordResetEvent {
  const PasswordResetEvent();
}

class ResetConfirmSubmitted extends PasswordResetEvent {
  final String code;
  final String newPassword;

  const ResetConfirmSubmitted({
    required this.code,
    required this.newPassword,
  });
}
