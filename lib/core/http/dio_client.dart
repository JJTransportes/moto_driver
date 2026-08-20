import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/config/app_config.dart';

class AuthInterceptor extends Interceptor {
  final AuthStorage _storage;

  AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.getToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      // Falha ao ler o token (Keystore corrompido no Android, OperationError do
      // Web Crypto, etc). Segue sem Authorization: o backend responde 401 e o
      // fluxo de sessão trata. O que não pode acontecer é a cadeia do Dio ficar
      // sem next()/reject() — isso pendura a requisição para sempre.
      debugPrint('AuthInterceptor: falha ao ler token, seguindo sem Authorization — $e');
    }
    handler.next(options);
  }
}

class DioClient {
  DioClient._();

  static Dio create(AuthStorage authStorage) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.getBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(AuthInterceptor(authStorage));
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    return dio;
  }
}
