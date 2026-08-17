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

  /// POST /api/drivers/availability/update
  /// Define a intenção do cliente sobre o modo de atendimento.
  /// [action]: 'activate' (habilita por 4h) | 'deactivate' (desabilita).
  Future<DriverAvailabilityEntity> updateAvailability(String action) async {
    try {
      final response = await _dio.post(
        '/api/drivers/availability/update',
        data: {'action': action},
      );
      return DriverAvailabilityEntity.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Ativa o modo de atendimento por 4h (janela controlada pelo backend).
  /// Usado pelo modal de atendimento ao tocar em "Confirmar".
  Future<DriverAvailabilityEntity> activate() =>
      updateAvailability('activate');

  /// Desativa o modo de atendimento (usado no logout/delete de conta).
  Future<DriverAvailabilityEntity> deactivate() =>
      updateAvailability('deactivate');

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
