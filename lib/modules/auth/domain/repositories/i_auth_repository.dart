import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:result_dart/result_dart.dart';

abstract class IAuthRepository {
  Future<Result<UserEntity>> signIn(String email, String password, String device);

  /// Exchanges a [refreshToken] for a new pair of access + refresh tokens (rotation).
  Future<Result<RefreshTokenResponseModel>> refreshToken(String refreshToken, String device);
}
