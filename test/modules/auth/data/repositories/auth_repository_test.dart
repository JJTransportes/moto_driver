import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/core/notifications/inotification_service.dart';
import 'package:moto_driver/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/auth/data/models/sign_in_response_model.dart';
import 'package:moto_driver/modules/auth/data/repositories/auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:result_dart/result_dart.dart';

class MockNotificationService extends Mock implements INotificationService {}

void main() {
  late MockAuthDatasource mockDatasource;
  late MockNotificationService mockNotificationService;
  late AuthRepository repository;

  setUp(() {
    String idFake = 'idFake';
    mockDatasource = MockAuthDatasource();
    mockNotificationService = MockNotificationService();
    when(() => mockNotificationService.login(any(), any())).thenAnswer((_) async => idFake);
    repository = AuthRepository(mockDatasource, mockNotificationService);
  });

  final model = SignInResponseModel(
    accessToken: 'tok_123',
    expiresAt: DateTime(2026, 6, 9, 0, 15),
    userId: 'user_1',
    roles: ['Driver'],
  );

  final refreshModel = RefreshTokenResponseModel(
    accessToken: 'new_access_123',
    refreshToken: 'new_refresh_456',
    expiresAt: DateTime(2026, 7, 13, 12, 30),
    userId: 'user_1',
    roles: ['Driver'],
  );

  group('signIn', () {
    test('returns Success with UserEntity on datasource success', () async {
      when(() => mockDatasource.signIn(any(), any())).thenAnswer((_) async => model);

      final result = await repository.signIn('joao@moto.com', '123456');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (user) {
          expect(user.id, 'user_1');
          expect(user.token, 'tok_123');
          expect(user.roles, ['Driver']);
          expect(user.isDriver, isTrue);
        },
        (_) => fail('Expected success'),
      );
    });

    test('returns Failure on UnauthorizedException', () async {
      when(() => mockDatasource.signIn(any(), any())).thenThrow(
        const UnauthorizedException('E-mail ou senha inválidos'),
      );

      final result = await repository.signIn('joao@moto.com', 'wrong');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) {
          expect(error, isA<UnauthorizedException>());
          expect(error.toString(), 'E-mail ou senha inválidos');
        },
      );
    });

    test('returns Failure on NetworkException', () async {
      when(() => mockDatasource.signIn(any(), any())).thenThrow(const NetworkException());

      final result = await repository.signIn('joao@moto.com', '123');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error, isA<NetworkException>()),
      );
    });
  });

  group('refreshToken', () {
    test('returns Success with RefreshTokenResponseModel on success', () async {
      when(() => mockDatasource.refreshToken(any())).thenAnswer((_) async => refreshModel);

      final result = await repository.refreshToken('old_refresh');

      expect(result, isA<Result<RefreshTokenResponseModel>>());
      result.fold(
        (model) {
          expect(model.accessToken, 'new_access_123');
          expect(model.refreshToken, 'new_refresh_456');
          expect(model.userId, 'user_1');
          expect(model.roles, ['Driver']);
        },
        (_) => fail('Expected success'),
      );

      verify(() => mockDatasource.refreshToken('old_refresh')).called(1);
    });

    test('returns Failure on UnauthorizedException', () async {
      when(() => mockDatasource.refreshToken(any())).thenThrow(
        const UnauthorizedException('Refresh token inválido'),
      );

      final result = await repository.refreshToken('invalid_refresh');

      expect(result, isA<Result<RefreshTokenResponseModel>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) {
          expect(error, isA<UnauthorizedException>());
          expect(error.toString(), 'Refresh token inválido');
        },
      );
    });

    test('returns Failure on NetworkException', () async {
      when(() => mockDatasource.refreshToken(any())).thenThrow(
        const NetworkException(),
      );

      final result = await repository.refreshToken('some_token');

      expect(result, isA<Result<RefreshTokenResponseModel>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error, isA<NetworkException>()),
      );
    });
  });
}

class MockAuthDatasource extends Mock implements IAuthDatasource {}
