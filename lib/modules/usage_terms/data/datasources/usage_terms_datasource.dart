import 'package:dio/dio.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/usage_terms/domain/entities/usage_term_entity.dart';

class UsageTermsDatasource {
  final Dio _dio;

  UsageTermsDatasource(this._dio);

  /// GET /api/usage-terms/acceptance-status
  Future<AcceptanceStatusEntity> getAcceptanceStatus() async {
    try {
      final response = await _dio.get('/api/usage-terms/acceptance-status');
      return AcceptanceStatusEntity.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// GET /api/usage-terms/active
  Future<UsageTermEntity> getActiveTerms() async {
    try {
      final response = await _dio.get('/api/usage-terms/active');
      return UsageTermEntity.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// POST /api/usage-terms/accept
  Future<AcceptResponseEntity> acceptTerms() async {
    try {
      final response = await _dio.post('/api/usage-terms/accept');
      return AcceptResponseEntity.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return const ValidationException('Dados inválidos.');
      case 401:
        return const UnauthorizedException(
          'Sessão expirada. Faça login novamente.',
        );
      case 500:
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
