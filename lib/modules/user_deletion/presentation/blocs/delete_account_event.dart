abstract class DeleteAccountEvent {
  const DeleteAccountEvent();
}

class DeleteAccountRequested extends DeleteAccountEvent {
  final String password;

  const DeleteAccountRequested({required this.password});
}
