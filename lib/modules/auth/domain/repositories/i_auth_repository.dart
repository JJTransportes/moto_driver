import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:result_dart/result_dart.dart';

abstract class IAuthRepository {
  Future<Result<UserEntity>> signIn(
    String email,
    String password,
    String device, {
    String? expectedRole,
  });

  /// Exchanges a [refreshToken] for a new pair of access + refresh tokens (rotation).
  Future<Result<RefreshTokenResponseModel>> refreshToken(String refreshToken, String device);

  /// Solicita o código de redefinição de senha. Falha com [NotFoundException]
  /// quando o e-mail não está cadastrado (404) — ver [IAuthDatasource].
  Future<Result<Unit>> requestPasswordReset(String email);

  /// Verifica o código recebido por e-mail (tela 1). Sucesso devolve o
  /// `resetToken` de uso único a ser usado em [confirmPasswordReset].
  Future<Result<String>> verifyResetCode({required String email, required String code});

  /// Confirma a redefinição de senha com o `resetToken` obtido em
  /// [verifyResetCode].
  Future<Result<Unit>> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  });

  /// Busca a política de senha vigente. Falha propaga como [Failure] — o
  /// fallback estático (design D4) fica no usecase, não aqui.
  Future<Result<PasswordPolicy>> getPasswordPolicy();
}
