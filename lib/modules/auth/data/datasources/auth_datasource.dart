import 'package:dio/dio.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/models/password_policy_model.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';

class AuthDatasource implements IAuthDatasource {
  final Dio _dio;

  AuthDatasource(this._dio);

  @override
  Future<SignInResponseModel> signIn(
    String email,
    String password,
    String device, {
    String? expectedRole,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/sign-in',
        data: {
          'email': email,
          'password': password,
          'device': device,
          if (expectedRole != null) 'expectedRole': expectedRole,
        },
      );
      return SignInResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e, isSignIn: true);
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

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _dio.post(
        '/api/auth/password-reset/request',
        data: {'email': email, 'expectedRole': 'Driver'},
      );
    } on DioException catch (e) {
      throw _mapRequestPasswordResetException(e);
    }
  }

  /// 404 (e-mail não cadastrado, inclusive quando existe só em outra role) e
  /// 429 (muitas tentativas), conforme contrato do backend.
  Exception _mapRequestPasswordResetException(DioException e) {
    final serverMessage = _extractErrorMessage(e);
    switch (e.response?.statusCode) {
      case 403:
        return UnapprovedAccountException(
          serverMessage ?? 'Sua conta ainda não foi aprovada. Aguarde a aprovação de um administrador antes de redefinir a senha.',
        );
      case 404:
        return NotFoundException(serverMessage ?? 'Email não cadastrado.');
      case 429:
        return RateLimitedException(
          serverMessage ?? 'Muitas solicitações de redefinição de senha. Aguarde um pouco antes de tentar novamente.',
        );
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

  @override
  Future<String> verifyResetCode({required String email, required String code}) async {
    try {
      final response = await _dio.post(
        '/api/auth/password-reset/verify-code',
        data: {'email': email, 'code': code},
      );
      final data = response.data as Map<String, dynamic>;
      return data['resetToken'] as String;
    } on DioException catch (e) {
      throw _mapVerifyResetCodeException(e);
    }
  }

  /// 400 (código inválido/expirado), 409 (código já usado) e 429 (muitas
  /// tentativas erradas — bloqueio de 30 min), conforme contrato do backend.
  Exception _mapVerifyResetCodeException(DioException e) {
    final serverMessage = _extractErrorMessage(e);
    switch (e.response?.statusCode) {
      case 400:
        return ValidationException(serverMessage ?? 'Código inválido ou expirado.');
      case 409:
        return ConflictException(serverMessage ?? 'Este código já foi utilizado.');
      case 429:
        return RateLimitedException(
          serverMessage ?? 'Muitas tentativas com código incorreto. Aguarde 30 minutos e peça um novo código.',
        );
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

  @override
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/api/auth/password-reset/confirm',
        data: {
          'resetToken': resetToken,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _mapPasswordResetConfirmException(e);
    }
  }

  /// O 400 do confirm cobre dois motivos distintos (token inválido/expirado
  /// ou senha fora da política) — só a mensagem do servidor (campo `error`)
  /// distingue os dois, então ela é repassada como está em vez de um texto
  /// genérico fixo.
  Exception _mapPasswordResetConfirmException(DioException e) {
    final serverMessage = _extractErrorMessage(e);
    switch (e.response?.statusCode) {
      case 400:
        return ValidationException(serverMessage ?? 'Token inválido ou expirado, ou senha não atende aos requisitos.');
      case 409:
        return ConflictException(serverMessage ?? 'Este código já foi utilizado.');
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

  @override
  Future<PasswordPolicy> getPasswordPolicy() async {
    try {
      final response = await _dio.get('/api/auth/password-policy');
      return PasswordPolicyModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e, {bool isSignIn = false}) {
    switch (e.response?.statusCode) {
      case 400:
        return const ValidationException(
          'Dados inválidos. Verifique as informações.',
        );
      case 401:
        // Corpo com mensagem (ex.: conta pendente de aprovação) prevalece
        // sobre o genérico — senha errada continua vindo sem corpo.
        return UnauthorizedException(_extractErrorMessage(e) ?? 'E-mail ou senha inválidos');
      case 403:
        if (isSignIn) {
          // Sign-in com `expectedRole` informado e conta sem esse role.
          return RoleMismatchException(
            _extractErrorMessage(e) ?? 'Esta conta não é de motorista.',
          );
        }
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
      final raw =
          data['error'] ?? data['message'] ?? data['detail'] ?? data['title'];
      if (raw is String && raw.isNotEmpty) return raw;
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }
}
