import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/core/models/password_policy.dart';
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
      when(() => mockDatasource.signIn(any(), any(), any(), expectedRole: any(named: 'expectedRole')))
          .thenAnswer((_) async => model);

      final result = await repository.signIn('joao@moto.com', '123456', 'android');

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
      when(() => mockDatasource.signIn(any(), any(), any(), expectedRole: any(named: 'expectedRole')))
          .thenThrow(
        const UnauthorizedException('E-mail ou senha inválidos'),
      );

      final result = await repository.signIn('joao@moto.com', 'wrong', 'android');

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
      when(() => mockDatasource.signIn(any(), any(), any(), expectedRole: any(named: 'expectedRole')))
          .thenThrow(const NetworkException());

      final result = await repository.signIn('joao@moto.com', '123', 'android');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error, isA<NetworkException>()),
      );
    });
  });

  group('refreshToken', () {
    test('returns Success with RefreshTokenResponseModel on success', () async {
      when(() => mockDatasource.refreshToken(any(), any())).thenAnswer((_) async => refreshModel);

      final result = await repository.refreshToken('old_refresh', 'android');

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

      verify(() => mockDatasource.refreshToken('old_refresh', 'android')).called(1);
    });

    test('returns Failure on UnauthorizedException', () async {
      when(() => mockDatasource.refreshToken(any(), any())).thenThrow(
        const UnauthorizedException('Refresh token inválido'),
      );

      final result = await repository.refreshToken('invalid_refresh', 'android');

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
      when(() => mockDatasource.refreshToken(any(), any())).thenThrow(
        const NetworkException(),
      );

      final result = await repository.refreshToken('some_token', 'android');

      expect(result, isA<Result<RefreshTokenResponseModel>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error, isA<NetworkException>()),
      );
    });
  });

  group('verifyResetCode', () {
    test('returns Success with resetToken on datasource success', () async {
      when(() => mockDatasource.verifyResetCode(email: any(named: 'email'), code: any(named: 'code')))
          .thenAnswer((_) async => 'reset-tok-1');

      final result = await repository.verifyResetCode(email: 'joao@moto.com', code: '123456');

      expect(result, isA<Result<String>>());
      result.fold(
        (token) => expect(token, 'reset-tok-1'),
        (_) => fail('Expected success'),
      );
    });

    test('returns Failure on ValidationException', () async {
      when(() => mockDatasource.verifyResetCode(email: any(named: 'email'), code: any(named: 'code')))
          .thenThrow(const ValidationException('Código inválido ou expirado.'));

      final result = await repository.verifyResetCode(email: 'joao@moto.com', code: '000000');

      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error, isA<ValidationException>()),
      );
    });
  });

  group('confirmPasswordReset', () {
    test('returns Success on datasource success', () async {
      when(() => mockDatasource.confirmPasswordReset(
            resetToken: any(named: 'resetToken'),
            newPassword: any(named: 'newPassword'),
          )).thenAnswer((_) async {});

      final result = await repository.confirmPasswordReset(resetToken: 'reset-tok-1', newPassword: 'NovaSenha@1');

      expect(result, isA<Result<Unit>>());
      result.fold(
        (_) {},
        (_) => fail('Expected success'),
      );

      verify(() => mockDatasource.confirmPasswordReset(
            resetToken: 'reset-tok-1',
            newPassword: 'NovaSenha@1',
          )).called(1);
    });

    test('returns Failure on ConflictException', () async {
      when(() => mockDatasource.confirmPasswordReset(
            resetToken: any(named: 'resetToken'),
            newPassword: any(named: 'newPassword'),
          )).thenThrow(const ConflictException('Este código já foi utilizado.'));

      final result = await repository.confirmPasswordReset(resetToken: 'reset-tok-1', newPassword: 'NovaSenha@1');

      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error, isA<ConflictException>()),
      );
    });
  });

  group('getPasswordPolicy', () {
    test('returns Success with the policy on datasource success', () async {
      when(() => mockDatasource.getPasswordPolicy()).thenAnswer(
        (_) async => const PasswordPolicy(
          minLength: 8,
          maxLength: 72,
          requireUppercase: true,
          requireLowercase: true,
          requireDigit: true,
          requireSpecialChar: true,
        ),
      );

      final result = await repository.getPasswordPolicy();

      result.fold(
        (policy) => expect(policy.minLength, 8),
        (_) => fail('Expected success'),
      );
    });

    test('returns Failure on ServerException', () async {
      when(() => mockDatasource.getPasswordPolicy()).thenThrow(const ServerException());

      final result = await repository.getPasswordPolicy();

      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error, isA<ServerException>()),
      );
    });
  });
}

class MockAuthDatasource extends Mock implements IAuthDatasource {}
