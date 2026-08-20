import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:result_dart/result_dart.dart';

abstract class IAuthRepository {
  Future<Result<UserEntity>> signIn(String email, String password, String device);

  /// Exchanges a [refreshToken] for a new pair of access + refresh tokens (rotation).
  Future<Result<RefreshTokenResponseModel>> refreshToken(String refreshToken, String device);

  /// Solicita o código de redefinição de senha. Sempre bem-sucedido do ponto
  /// de vista do chamador, exceto rate limit/rede — ver [IAuthDatasource].
  Future<Result<Unit>> requestPasswordReset(String email);

  /// Confirma a redefinição de senha com o código recebido por e-mail.
  Future<Result<Unit>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
