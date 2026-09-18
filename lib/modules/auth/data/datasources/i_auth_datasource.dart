import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';

abstract class IAuthDatasource {
  /// Signs in with the given [email] and [password], reporting the [device]
  /// type (`android` | `ios`) for refresh-token device binding.
  ///
  /// [expectedRole] is optional; when sent, the backend rejects the login
  /// with a 403 ([RoleMismatchException]) if the account doesn't have that role.
  ///
  /// Returns raw [SignInResponseModel] on success.
  /// Throws a typed exception (e.g. [UnauthorizedException], [NetworkException],
  /// [DeviceConflictException] on 409, [RoleMismatchException] on 403) on failure.
  Future<SignInResponseModel> signIn(
    String email,
    String password,
    String device, {
    String? expectedRole,
  });

  /// Exchanges a [refreshToken] for a new pair of access + refresh tokens (rotation),
  /// reporting the [device] type for refresh-token device binding.
  ///
  /// Throws a typed exception (e.g. [DeviceMismatchException] on 403) on failure.
  Future<RefreshTokenResponseModel> refreshToken(String refreshToken, String device);

  /// Solicita o código de redefinição de senha para o [email] informado.
  /// Envia `expectedRole: "Driver"` fixo, exigido pelo backend.
  ///
  /// Throws [NotFoundException] (404, e-mail não cadastrado — inclusive
  /// quando existe só em outra role) ou [RateLimitedException] (429).
  Future<void> requestPasswordReset(String email);

  /// Verifica o [code] recebido por e-mail para o [email] informado (tela 1
  /// do reset). Retorna o `resetToken` de uso único (expira em 10 min) a ser
  /// usado em [confirmPasswordReset].
  ///
  /// Throws [ValidationException] (400, código inválido/expirado),
  /// [ConflictException] (409, código já usado) ou [RateLimitedException]
  /// (429, muitas tentativas erradas — bloqueio de 30 min).
  Future<String> verifyResetCode({required String email, required String code});

  /// Confirma a redefinição de senha com o [resetToken] obtido em
  /// [verifyResetCode] (tela 2). Não envia mais `email`/`code`.
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  });

  /// Busca a política de senha vigente (`GET /api/auth/password-policy`,
  /// público, sem auth). Usada no checklist dinâmico do reset e do cadastro.
  Future<PasswordPolicy> getPasswordPolicy();
}
