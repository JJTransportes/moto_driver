import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_request_password_reset_usecase.dart';
import 'package:result_dart/result_dart.dart';

class RequestPasswordResetUsecase implements IRequestPasswordResetUsecase {
  final IAuthRepository _repository;

  RequestPasswordResetUsecase(this._repository);

  @override
  Future<Result<Unit>> call(String email) {
    return _repository.requestPasswordReset(email);
  }
}
