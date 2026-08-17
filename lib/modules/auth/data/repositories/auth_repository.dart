import 'package:moto_driver/core/notifications/inotification_service.dart';
import 'package:moto_driver/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:result_dart/result_dart.dart';

class AuthRepository implements IAuthRepository {
  final IAuthDatasource _datasource;
  final INotificationService _notificationService;

  AuthRepository(this._datasource, this._notificationService);

  @override
  Future<Result<UserEntity>> signIn(
    String email,
    String password,
  ) async {
    try {
      final model = await _datasource.signIn(email, password);
      await _notificationService.login(model.userId, model.accessToken);

      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<RefreshTokenResponseModel>> refreshToken(
    String refreshToken,
  ) async {
    try {
      final model = await _datasource.refreshToken(refreshToken);
      return Success(model);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
