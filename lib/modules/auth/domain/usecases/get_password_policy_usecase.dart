import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_get_password_policy_usecase.dart';
import 'package:result_dart/result_dart.dart';

class GetPasswordPolicyUsecase implements IGetPasswordPolicyUsecase {
  final IAuthRepository _repository;

  GetPasswordPolicyUsecase(this._repository);

  @override
  Future<Result<PasswordPolicy>> call() async {
    final result = await _repository.getPasswordPolicy();
    return result.fold(
      (policy) => Success(policy),
      // Rede/5xx: a política nunca deve bloquear reset ou cadastro.
      (_) => const Success(PasswordPolicy.fallback()),
    );
  }
}
