import 'dart:developer' show log;

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
    String device,
  ) async {
    final UserEntity user;
    try {
      final model = await _datasource.signIn(email, password, device);
      user = model.toEntity();
    } on Exception catch (e) {
      return Failure(e);
    }


    try {
      await _notificationService.login(user.id, user.token);
    } catch (e) {
      log('[AUTH] push registration failed after successful login: $e', name: 'auth');
    }

    return Success(user);
  }

  @override
  Future<Result<RefreshTokenResponseModel>> refreshToken(
    String refreshToken,
    String device,
  ) async {
    try {
      final model = await _datasource.refreshToken(refreshToken, device);
      return Success(model);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<Unit>> requestPasswordReset(String email) async {
    try {
      await _datasource.requestPasswordReset(email);
      return Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<Unit>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _datasource.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
