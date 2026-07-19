import 'package:moto_driver/modules/user_deletion/domain/repositories/i_user_deletion_repository.dart';
import 'package:moto_driver/modules/user_deletion/domain/usecases/i_delete_account_usecase.dart';
import 'package:result_dart/result_dart.dart';

class DeleteAccountUseCase implements IDeleteAccountUseCase {
  final IUserDeletionRepository _repository;

  DeleteAccountUseCase(this._repository);

  @override
  Future<Result<void>> call(String password) async {
    return _repository.deleteAccount(password);
  }
}
