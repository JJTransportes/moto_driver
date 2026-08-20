import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';

abstract class IAuthDatasource {
  /// Signs in with the given [email] and [password], reporting the [device]
  /// type (`android` | `ios`) for refresh-token device binding.
  ///
  /// Returns raw [SignInResponseModel] on success.
  /// Throws a typed exception (e.g. [UnauthorizedException], [NetworkException],
  /// [DeviceConflictException] on 409) on failure.
  Future<SignInResponseModel> signIn(String email, String password, String device);

  /// Exchanges a [refreshToken] for a new pair of access + refresh tokens (rotation),
  /// reporting the [device] type for refresh-token device binding.
  ///
  /// Throws a typed exception (e.g. [DeviceMismatchException] on 403) on failure.
  Future<RefreshTokenResponseModel> refreshToken(String refreshToken, String device);

  /// Solicita o código de redefinição de senha para o [email] informado.
  Future<void> requestPasswordReset(String email);

  /// Confirma a redefinição de senha com o [code] recebido por e-mail.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
