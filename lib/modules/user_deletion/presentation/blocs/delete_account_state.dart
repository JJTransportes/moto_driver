abstract class DeleteAccountState {
  const DeleteAccountState();
}

class DeleteAccountInitial extends DeleteAccountState {
  const DeleteAccountInitial();
}

class DeleteAccountLoading extends DeleteAccountState {
  const DeleteAccountLoading();
}

class DeleteAccountSuccess extends DeleteAccountState {
  const DeleteAccountSuccess();
}

class DeleteAccountFailure extends DeleteAccountState {
  final Exception error;

  const DeleteAccountFailure(this.error);
}
