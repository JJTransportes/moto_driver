import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';

abstract class IAuthDatasource {
  /// Signs in with the given [email] and [password].
  ///
  /// Returns raw [SignInResponseModel] on success.
  /// Throws a typed exception (e.g. [UnauthorizedException], [NetworkException]) on failure.
  Future<SignInResponseModel> signIn(String email, String password);

  /// Exchanges a [refreshToken] for a new pair of access + refresh tokens (rotation).
  ///
  /// Throws a typed exception on failure.
  Future<RefreshTokenResponseModel> refreshToken(String refreshToken);

  /// Solicita o código de redefinição de senha para [email].
  ///
  /// Não lança para e-mail não cadastrado (HTTP 404) — por design anti
  /// enumeração o backend/app tratam "e-mail existe" e "e-mail não existe"
  /// da mesma forma para quem está do lado de fora. Só [RateLimitedException]
  /// e falhas de rede/servidor são propagadas.
  Future<void> requestPasswordReset(String email);

  /// Confirma a redefinição de senha com o [code] de 6 dígitos recebido por
  /// e-mail e a [newPassword].
  ///
  /// Lança [ValidationException] (código inválido/expirado ou senha fora da
  /// política — a mensagem do servidor distingue os dois), [ConflictException]
  /// (código já utilizado) ou [RateLimitedException].
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
