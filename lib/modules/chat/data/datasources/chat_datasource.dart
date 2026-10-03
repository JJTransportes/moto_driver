import 'package:dio/dio.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_datasource.dart';

class ChatDatasource implements IChatDatasource {
  final Dio _dio;

  ChatDatasource(this._dio);

  @override
  Future<Map<String, dynamic>> sendMessage(
    String travelId,
    String text,
    String clientMessageId,
  ) async {
    try {
      final response = await _dio.post(
        '/api/travels/$travelId/chat/messages',
        data: {'text': text, 'clientMessageId': clientMessageId},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getHistory(String travelId) async {
    try {
      final response = await _dio.get('/api/travels/$travelId/chat/messages');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> markRead(String travelId) async {
    try {
      await _dio.post('/api/travels/$travelId/chat/read');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getPassengerContact(String travelId) async {
    try {
      final response = await _dio.get('/api/travels/$travelId/passenger-contact');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// O backend responde `{ "error": "mensagem em português" }`; essa mensagem
  /// já é para o usuário, então é repassada na exceção.
  Exception _mapDioException(DioException e) {
    final body = e.response?.data;
    final serverMessage = body is Map ? body['error'] as String? : null;

    switch (e.response?.statusCode) {
      case 400:
        return ValidationException(serverMessage ?? 'Mensagem inválida.');
      case 401:
        return const UnauthorizedException();
      case 403:
        return ForbiddenException(
          serverMessage ?? 'Você não participa desta viagem.',
        );
      case 404:
        return NotFoundException(serverMessage ?? 'Viagem não encontrada.');
      case 409:
        return ConflictException(
          serverMessage ?? 'O chat não está disponível para esta viagem.',
        );
      case 429:
        return RateLimitedException(
          serverMessage ?? 'Você está enviando mensagens rápido demais.',
        );
      case var code when code != null && code >= 500:
        return ServerException(
          serverMessage ?? 'Não foi possível enviar a mensagem. Tente novamente.',
        );
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError) {
          return const NetworkException();
        }
        return NetworkException(e.message ?? 'Erro inesperado');
    }
  }
}
