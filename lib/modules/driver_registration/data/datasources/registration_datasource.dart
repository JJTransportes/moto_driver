import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/driver_registration/data/datasources/i_registration_datasource.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';

class RegistrationDatasource implements IRegistrationDatasource {
  final Dio _dio;

  RegistrationDatasource(this._dio);

  @override
  Future<void> register(RegisterParams params) async {
    try {
      final body = <String, dynamic>{
        'role': 'Driver',
        'fullName': params.fullName,
        'cpf': params.cpf,
        'rg': params.rg,
        'birthdate': DateFormat('yyyy-MM-dd').format(params.birthdate),
        'email': params.email.trim().toLowerCase(),
        'initialPassword': params.initialPassword,
        'cnh': params.cnh,
      };

      if (params.registration != null && params.registration!.trim().isNotEmpty) {
        body['registration'] = params.registration!.trim();
      }

      if (params.department != null && params.department!.trim().isNotEmpty) {
        body['department'] = params.department!.trim();
      }

      if (params.phone != null && params.phone!.trim().isNotEmpty) {
        body['phone'] = params.phone!.trim();
      }

      await _dio.post(
        '/api/registrations',
        data: body,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        final serverMessage = e.response?.data?['error'] as String?;
        return ValidationException(
          serverMessage ?? 'Dados inválidos. Verifique as informações e tente novamente.',
        );
      case 409:
        final serverError = e.response?.data?['error'] as String? ?? '';
        final field = _extractDuplicateField(serverError);
        final message = _duplicateMessage(field, serverError);
        return DuplicateException(message, field: field);
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

  String? _extractDuplicateField(String error) {
    final lowered = error.toLowerCase();
    if (lowered.contains('e-mail') || lowered.contains('email')) return 'email';
    if (lowered.contains('cpf')) return 'cpf';
    if (lowered.contains('cnh')) return 'cnh';
    return null;
  }

  String _duplicateMessage(String? field, String serverError) {
    if (serverError.isNotEmpty && !serverError.toLowerCase().contains('duplicate')) {
      return serverError;
    }
    return switch (field) {
      'email' => 'Este e-mail já está cadastrado.',
      'cpf' => 'Este CPF já está cadastrado.',
      'cnh' => 'Esta CNH já está cadastrada.',
      _ => 'Já existe um cadastro com estes dados.',
    };
  }
}
