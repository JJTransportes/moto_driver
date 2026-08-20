import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/usecases/login_usecase.dart';
import 'package:result_dart/result_dart.dart';

void main() {
  late MockAuthRepository mockRepository;
  late LoginUsecase usecase;

  setUp(() {
    mockRepository = MockAuthRepository();
    usecase = LoginUsecase(mockRepository);
  });

  const user = UserEntity(
    id: 'user_1',
    token: 'tok_123',
    roles: ['Driver'],
  );

  group('call', () {
    test('returns Success on repository success', () async {
      when(() => mockRepository.signIn(any(), any(), any())).thenAnswer((_) async => Success(user));

      final result = await usecase.call('joao@moto.com', '123456', 'android');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (u) {
          expect(u.id, 'user_1');
          expect(u.token, 'tok_123');
          expect(u.roles, ['Driver']);
        },
        (_) => fail('Expected success'),
      );
      verify(() => mockRepository.signIn('joao@moto.com', '123456', 'android')).called(1);
    });

    test('returns Failure on repository failure', () async {
      when(() => mockRepository.signIn(any(), any(), any())).thenAnswer(
        (_) async => Failure(Exception('E-mail ou senha inválidos')),
      );

      final result = await usecase.call('joao@moto.com', 'wrong', 'android');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error.toString(), 'E-mail ou senha inválidos'),
      );
    });
  });
}

class MockAuthRepository extends Mock implements IAuthRepository {}
