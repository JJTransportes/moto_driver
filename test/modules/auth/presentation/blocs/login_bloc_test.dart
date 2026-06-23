import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_login_usecase.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:result_dart/result_dart.dart';

void main() {
  late MockLoginUsecase mockUsecase;
  late MockAuthStorage mockAuthStorage;
  late MockAuthLocalRepository mockAuthLocal;

  setUp(() {
    mockUsecase = MockLoginUsecase();
    mockAuthStorage = MockAuthStorage();
    mockAuthLocal = MockAuthLocalRepository();
  });

  const user = UserEntity(
    id: 'user_1',
    token: 'tok_123',
    roles: ['Driver'],
  );

  group('LoginBloc', () {
    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginSuccess] when login succeeds and persists token',
      build: () {
        when(() => mockUsecase.call(any(), any()))
            .thenAnswer((_) async => Success(user));
        when(() => mockAuthStorage.saveToken(any(), any()))
            .thenAnswer((_) async {});
        when(() => mockAuthLocal.saveAuth(
              userId: any(named: 'userId'),
              accessToken: any(named: 'accessToken'),
              roles: any(named: 'roles'),
            )).thenAnswer((_) async {});
        return LoginBloc(mockUsecase, mockAuthStorage, mockAuthLocal);
      },
      act: (bloc) => bloc.add(
        const LoginSubmitted(email: 'joao@moto.com', password: '123456'),
      ),
      expect: () => [
        const LoginLoading(),
        LoginSuccess(user),
      ],
      verify: (_) {
        verify(() => mockAuthStorage.saveToken('tok_123', 'user_1'))
            .called(1);
        verify(() => mockAuthLocal.saveAuth(
              userId: 'user_1',
              accessToken: 'tok_123',
              roles: ['Driver'],
            )).called(1);
      },
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginFailure] when login fails and does not persist',
      build: () {
        when(() => mockUsecase.call(any(), any())).thenAnswer(
          (_) async => Failure(Exception('E-mail ou senha inválidos')),
        );
        return LoginBloc(mockUsecase, mockAuthStorage, mockAuthLocal);
      },
      act: (bloc) => bloc.add(
        const LoginSubmitted(email: 'joao@moto.com', password: 'wrong'),
      ),
      expect: () => [
        const LoginLoading(),
        const LoginFailure('E-mail ou senha inválidos'),
      ],
      verify: (_) {
        verifyNever(() => mockAuthStorage.saveToken(any(), any()));
        verifyNever(() => mockAuthLocal.saveAuth(
              userId: any(named: 'userId'),
              accessToken: any(named: 'accessToken'),
              roles: any(named: 'roles'),
            ));
      },
    );

    blocTest<LoginBloc, LoginState>(
      'calls usecase with correct credentials',
      build: () {
        when(() => mockUsecase.call(any(), any()))
            .thenAnswer((_) async => Success(user));
        when(() => mockAuthStorage.saveToken(any(), any()))
            .thenAnswer((_) async {});
        when(() => mockAuthLocal.saveAuth(
              userId: any(named: 'userId'),
              accessToken: any(named: 'accessToken'),
              roles: any(named: 'roles'),
            )).thenAnswer((_) async {});
        return LoginBloc(mockUsecase, mockAuthStorage, mockAuthLocal);
      },
      act: (bloc) => bloc.add(
        const LoginSubmitted(
            email: 'driver@moto.com', password: 'secret123'),
      ),
      verify: (_) {
        verify(() => mockUsecase.call('driver@moto.com', 'secret123'))
            .called(1);
      },
    );
  });
}

class MockAuthStorage extends Mock implements AuthStorage {}

class MockAuthLocalRepository extends Mock implements AuthLocalRepository {}

class MockLoginUsecase extends Mock implements ILoginUsecase {}
