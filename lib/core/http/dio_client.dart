import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/config/device_type.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ObservabilityInterceptor extends Interceptor {
  static final _uuidSegment = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String _normalizedPath(Uri uri) => uri.pathSegments
      .map(
        (segment) =>
            _uuidSegment.hasMatch(segment) || int.tryParse(segment) != null
            ? '{id}'
            : segment,
      )
      .join('/');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(
      'X-Correlation-ID',
      () => '${DateTime.now().microsecondsSinceEpoch}-${options.hashCode}',
    );
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    if (status == null || status >= 500) {
      Sentry.captureException(
        StateError('HTTP request failed: ${err.type.name}'),
        stackTrace: err.stackTrace,
        withScope: (scope) {
          scope.setTag('http.method', err.requestOptions.method);
          scope.setTag('http.path', _normalizedPath(err.requestOptions.uri));
          scope.setTag('http.status_code', status?.toString() ?? 'network');
          scope.setTag(
            'correlation_id',
            err.requestOptions.headers['X-Correlation-ID']?.toString() ?? '',
          );
        },
      );
    }
    handler.next(err);
  }
}

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
      debugPrint(
        'AuthInterceptor: falha ao ler token, seguindo sem Authorization — $e',
      );
    }
    handler.next(options);
  }
}

/// F06 do relatório de auditoria: fora do fluxo de push (`OrderRefreshPage`)
/// e do `UsageTermsBloc`, nenhum lugar do app reagia a um 401 tentando
/// refresh — a sessão ficava "presa" até o motorista fechar/reabrir o app.
///
/// Este interceptor centraliza esse tratamento para toda chamada HTTP
/// autenticada: em um 401 (fora dos próprios endpoints de auth), tenta
/// `refreshToken` uma única vez, atualiza o storage e reenvia a requisição
/// original. Só encerra a sessão quando o backend confirma que o refresh
/// token é inválido; falhas transitórias preservam a sessão e a viagem ativa.
///
/// É um [QueuedInterceptor] para que requisições concorrentes que recebam
/// 401 ao mesmo tempo aguardem o mesmo refresh em vez de disparar N chamadas
/// de refresh em paralelo (o que invalidaria o token um do outro, já que o
/// backend faz rotação de refresh token).
class RefreshAuthInterceptor extends QueuedInterceptor {
  final AuthStorage _storage;
  final Dio _dio;

  RefreshAuthInterceptor(this._storage, this._dio);

  static const _authPathPrefix = '/api/auth/';
  static const _retriedExtraKey = 'moto_driver_refresh_retried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final requestOptions = err.requestOptions;

    final isUnauthorized = response?.statusCode == 401;
    final isAuthEndpoint = requestOptions.path.contains(_authPathPrefix);
    final alreadyRetried = requestOptions.extra[_retriedExtraKey] == true;

    if (!isUnauthorized || isAuthEndpoint || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        await _signOut();
        handler.next(err);
        return;
      }

      // Obtido via Modular.get em vez de injetado no construtor: evita
      // dependência circular na montagem do Dio (IAuthRepository depende de
      // um datasource que também usa Dio). Como este código só roda depois
      // que o Dio já está totalmente construído e registrado, é seguro.
      final authRepository = Modular.get<IAuthRepository>();
      final result = await authRepository.refreshToken(
        refreshToken,
        deviceType,
      );

      final success = result.getOrNull();
      if (success == null) {
        final error = result.exceptionOrNull();
        if (_isInvalidSession(error)) {
          await _signOut();
        } else {
          debugPrint(
            'RefreshAuthInterceptor: renovação indisponível; sessão preservada — $error',
          );
        }
        handler.next(err);
        return;
      }

      await Future.wait([
        _storage.saveToken(success.accessToken, success.userId),
        _storage.saveRefreshToken(success.refreshToken),
      ]);

      final retryOptions = requestOptions.copyWith(
        extra: {...requestOptions.extra, _retriedExtraKey: true},
      );
      retryOptions.headers['Authorization'] = 'Bearer ${success.accessToken}';

      final retryResponse = await _dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (e) {
      debugPrint('RefreshAuthInterceptor: falha ao renovar sessão — $e');
      // Exceções inesperadas (rede, timeout, armazenamento momentaneamente
      // indisponível) não provam que a sessão é inválida. Preserva os dados
      // locais e a viagem para tentar novamente na próxima requisição.
      handler.next(err);
    }
  }

  bool _isInvalidSession(Object? error) =>
      error is UnauthorizedException ||
      error is ValidationException ||
      error is DeviceMismatchException;

  Future<void> _signOut() async {
    try {
      await Modular.get<SignOutService>().signOut();
    } catch (e) {
      debugPrint('RefreshAuthInterceptor: falha ao chamar SignOutService — $e');
    }
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
    dio.interceptors.add(ObservabilityInterceptor());
    dio.interceptors.add(RefreshAuthInterceptor(authStorage, dio));
    if (kDebugMode) {
      // LogInterceptor imprime headers (inclusive Authorization: Bearer <token>)
      // e corpo de request/response (inclusive senha em texto plano no login).
      // Nunca deve rodar fora de debug — ver F02 do relatório de auditoria.
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
        ),
      );
    }

    return dio;
  }
}
