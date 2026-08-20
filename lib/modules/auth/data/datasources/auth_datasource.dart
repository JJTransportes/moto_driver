import 'package:dio/dio.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';

class AuthDatasource implements IAuthDatasource {
  final Dio _dio;

  AuthDatasource(this._dio);

  @override
  Future<SignInResponseModel> signIn(
    String email,
    String password,
    String device,
  ) async {
    try {
      final response = await _dio.post(
        '/api/auth/sign-in',
        data: {'email': email, 'password': password, 'device': device},
      );
      return SignInResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<RefreshTokenResponseModel> refreshToken(
    String refreshToken,
    String device,
  ) async {
    try {
      final response = await _dio.post(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken, 'device': device},
      );
      return RefreshTokenResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return const ValidationException(
          'Dados inválidos. Verifique as informações.',
        );
      case 401:
        return const UnauthorizedException('E-mail ou senha inválidos');
      case 403:
        // Refresh com token vinculado a outro tipo de dispositivo.
        return DeviceMismatchException(
          _extractErrorMessage(e) ??
              'Sessão vinculada a outro tipo de dispositivo. Faça logout no dispositivo original.',
        );
      case 404:
        return const NotFoundException('Usuário não encontrado');
      case 409:
        // Sign-in com sessão ativa vinculada a outro tipo de dispositivo.
        return DeviceConflictException(
          _extractErrorMessage(e) ??
              'Já existe uma sessão ativa em outro tipo de dispositivo. Faça logout lá primeiro.',
        );
      case 429:
        return const RateLimitedException();
      case var code when code != null && code >= 500:
        return const ServerException();
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          return const NetworkException();
        }
        return NetworkException(e.message ?? 'Erro inesperado');
    }
  }

  /// Extrai a mensagem do corpo de erro do backend (se presente) para
  /// repassar ao usuário nos conflitos de dispositivo.
  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final raw = data['message'] ?? data['detail'] ?? data['title'];
      if (raw is String && raw.isNotEmpty) return raw;
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }
}
