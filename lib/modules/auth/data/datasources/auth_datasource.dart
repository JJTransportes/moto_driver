import 'package:dio/dio.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';

class AuthDatasource implements IAuthDatasource {
  final Dio _dio;

  AuthDatasource(this._dio);

  @override
  Future<SignInResponseModel> signIn(String email, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/sign-in',
        data: {'email': email, 'password': password},
      );
      return SignInResponseModel.fromJson(
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
      case 404:
        return const NotFoundException('Usuário não encontrado');
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
}
