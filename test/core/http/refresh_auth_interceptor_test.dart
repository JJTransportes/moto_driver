import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/http/dio_client.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:result_dart/result_dart.dart';

class MockAuthStorage extends Mock implements AuthStorage {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockSignOutService extends Mock implements SignOutService {}

class _FakeModule extends Module {
  final IAuthRepository authRepository;
  final SignOutService signOutService;

  _FakeModule(this.authRepository, this.signOutService);

  @override
  void binds(i) {
    i.addInstance<IAuthRepository>(authRepository);
    i.addInstance<SignOutService>(signOutService);
  }
}

/// Adapter que responde 401 na primeira chamada a `/protected` e 200 na
/// segunda (simulando sucesso após o replay com token renovado); qualquer
/// outro caminho responde 200 direto.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int _protectedCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path.contains('/protected')) {
      _protectedCalls++;
      if (_protectedCalls == 1) {
        return ResponseBody.fromString('{"error":"unauthorized"}', 401);
      }
      return ResponseBody.fromString('{"ok":true}', 200);
    }

    return ResponseBody.fromString('{}', 200);
  }
}

/// Adapter em que TODA chamada a `/protected` responde 401 (refresh falha).
class _AlwaysUnauthorizedAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"error":"unauthorized"}', 401);
  }
}

void main() {
  late MockAuthStorage storage;
  late MockAuthRepository authRepository;
  late MockSignOutService signOutService;

  setUp(() {
    storage = MockAuthStorage();
    authRepository = MockAuthRepository();
    signOutService = MockSignOutService();
    when(() => signOutService.signOut()).thenAnswer((_) async {});
  });

  tearDown(() {
    Modular.destroy();
  });

  group('RefreshAuthInterceptor', () {
    test(
      '401 fora do endpoint de auth: renova o token e reenvia a requisição original',
      () async {
        Modular.init(_FakeModule(authRepository, signOutService));

        when(() => storage.getRefreshToken()).thenAnswer((_) async => 'old_refresh');
        when(() => storage.saveToken(any(), any())).thenAnswer((_) async {});
        when(() => storage.saveRefreshToken(any())).thenAnswer((_) async {});
        when(() => authRepository.refreshToken(any(), any())).thenAnswer(
          (_) async => Success(
            RefreshTokenResponseModel(
              accessToken: 'new_token',
              refreshToken: 'new_refresh',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              userId: 'user_1',
              roles: const ['Driver'],
            ),
          ),
        );

        final adapter = _ScriptedAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(RefreshAuthInterceptor(storage, dio));

        final response = await dio.get('/protected');

        expect(response.statusCode, 200);
        expect(adapter.requests.where((r) => r.path.contains('/protected')).length, 2);
        verify(() => authRepository.refreshToken('old_refresh', any())).called(1);
        verify(() => storage.saveToken('new_token', 'user_1')).called(1);
        verify(() => storage.saveRefreshToken('new_refresh')).called(1);
        verifyNever(() => signOutService.signOut());
      },
    );

    test(
      '401 no próprio endpoint de auth não dispara refresh',
      () async {
        Modular.init(_FakeModule(authRepository, signOutService));

        final adapter = _AlwaysUnauthorizedAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(RefreshAuthInterceptor(storage, dio));

        await expectLater(
          dio.post('/api/auth/sign-in'),
          throwsA(isA<DioException>()),
        );

        verifyNever(() => authRepository.refreshToken(any(), any()));
      },
    );

    test(
      '401 quando o refresh também falha: chama SignOutService.signOut()',
      () async {
        Modular.init(_FakeModule(authRepository, signOutService));

        when(() => storage.getRefreshToken()).thenAnswer((_) async => 'old_refresh');
        when(() => authRepository.refreshToken(any(), any()))
            .thenAnswer((_) async => Failure(Exception('refresh expirado')));

        final adapter = _AlwaysUnauthorizedAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(RefreshAuthInterceptor(storage, dio));

        await expectLater(
          dio.get('/protected'),
          throwsA(isA<DioException>()),
        );

        verify(() => signOutService.signOut()).called(1);
      },
    );

    test(
      '401 sem refresh token salvo: chama SignOutService.signOut() sem tentar refresh',
      () async {
        Modular.init(_FakeModule(authRepository, signOutService));

        when(() => storage.getRefreshToken()).thenAnswer((_) async => null);

        final adapter = _AlwaysUnauthorizedAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(RefreshAuthInterceptor(storage, dio));

        await expectLater(
          dio.get('/protected'),
          throwsA(isA<DioException>()),
        );

        verify(() => signOutService.signOut()).called(1);
        verifyNever(() => authRepository.refreshToken(any(), any()));
      },
    );
  });
}
