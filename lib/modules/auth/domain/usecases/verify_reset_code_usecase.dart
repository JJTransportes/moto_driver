import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_verify_reset_code_usecase.dart';
import 'package:result_dart/result_dart.dart';

class VerifyResetCodeUsecase implements IVerifyResetCodeUsecase {
  final IAuthRepository _repository;

  VerifyResetCodeUsecase(this._repository);

  @override
  Future<Result<String>> call({required String email, required String code}) {
    return _repository.verifyResetCode(email: email, code: code);
  }
}
