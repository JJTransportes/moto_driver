import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/modules/user_deletion/domain/usecases/i_delete_account_usecase.dart';
import 'package:moto_driver/modules/user_deletion/presentation/blocs/delete_account_event.dart';
import 'package:moto_driver/modules/user_deletion/presentation/blocs/delete_account_state.dart';

class DeleteAccountBloc extends Bloc<DeleteAccountEvent, DeleteAccountState> {
  final IDeleteAccountUseCase _deleteAccountUseCase;

  DeleteAccountBloc(this._deleteAccountUseCase)
      : super(const DeleteAccountInitial()) {
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
  }

  Future<void> _onDeleteAccountRequested(
    DeleteAccountRequested event,
    Emitter<DeleteAccountState> emit,
  ) async {
    emit(const DeleteAccountLoading());

    final result = await _deleteAccountUseCase.call(event.password);

    result.fold(
      (_) => emit(const DeleteAccountSuccess()),
      (failure) => emit(DeleteAccountFailure(failure)),
    );
  }
}
