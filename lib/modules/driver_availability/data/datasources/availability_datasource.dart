import 'package:dio/dio.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/driver_availability/domain/entities/driver_availability_entity.dart';

class AvailabilityDatasource {
  final Dio _dio;

  AvailabilityDatasource(this._dio);

  /// GET /api/drivers/availability
  Future<DriverAvailabilityEntity> getAvailability() async {
    try {
      final response = await _dio.get('/api/drivers/availability');
      return DriverAvailabilityEntity.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// POST /api/drivers/availability/activate
  /// Ativa o modo de atendimento por 4h (janela controlada pelo backend).
  Future<DriverAvailabilityEntity> activate() async {
    try {
      final response = await _dio.post('/api/drivers/availability/activate');
      return DriverAvailabilityEntity.fromJson(
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
