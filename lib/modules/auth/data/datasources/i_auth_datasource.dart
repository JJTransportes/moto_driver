import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';

abstract class IAuthDatasource {

  Future<SignInResponseModel> signIn(String email, String password);

  Future<RefreshTokenResponseModel> refreshToken(String refreshToken);

  Future<void> requestPasswordReset(String email);

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
