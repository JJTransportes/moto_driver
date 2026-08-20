import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_login_usecase.dart';
import 'package:result_dart/result_dart.dart';

class LoginUsecase implements ILoginUsecase {
  final IAuthRepository _repository;

  LoginUsecase(this._repository);

  @override
  Future<Result<UserEntity>> call(String email, String password, String device) {
    return _repository.signIn(email, password, device);
  }
}
