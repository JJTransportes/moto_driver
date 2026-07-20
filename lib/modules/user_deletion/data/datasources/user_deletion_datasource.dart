import 'package:dio/dio.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/user_deletion/data/datasources/i_user_deletion_datasource.dart';
import 'package:moto_driver/modules/user_deletion/data/models/delete_account_request_model.dart';

class UserDeletionDatasource implements IUserDeletionDatasource {
  final Dio _dio;

  UserDeletionDatasource(this._dio);

  @override
  Future<void> deleteAccount(String password) async {
    try {
      final body = DeleteAccountRequestModel(password: password).toJson();
      await _dio.delete('/api/account', data: body);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return ValidationException(
          e.response?.data?['message'] as String? ??
              'Requisição inválida. Verifique os dados e tente novamente.',
        );
      case 401:
        return const UnauthorizedException('Senha incorreta.');
      case 409:
        return const ValidationException(
          'Não é possível excluir a conta enquanto houver viagens em andamento.',
        );
      case var code when code != null && code >= 500:
        return const ServerException(
          'Erro interno do servidor. Tente novamente mais tarde.',
        );
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          return const NetworkException(
            'Erro de conexão. Verifique sua internet e tente novamente.',
          );
        }
        return NetworkException(e.message ?? 'Erro inesperado. Tente novamente.');
    }
  }
}
