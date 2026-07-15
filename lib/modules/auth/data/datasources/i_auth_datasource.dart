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
}
