import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/usecases/get_password_policy_usecase.dart';
import 'package:result_dart/result_dart.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository mockRepository;
  late GetPasswordPolicyUsecase usecase;

  setUp(() {
    mockRepository = MockAuthRepository();
    usecase = GetPasswordPolicyUsecase(mockRepository);
  });

  group('call', () {
    test('returns the policy from the backend on repository success', () async {
      when(() => mockRepository.getPasswordPolicy()).thenAnswer(
        (_) async => const Success(
          PasswordPolicy(
            minLength: 10,
            maxLength: 64,
            requireUppercase: true,
            requireLowercase: true,
            requireDigit: false,
            requireSpecialChar: false,
          ),
        ),
      );

      final result = await usecase.call();

      result.fold(
        (policy) {
          expect(policy.minLength, 10);
          expect(policy.maxLength, 64);
          expect(policy.requireDigit, isFalse);
        },
        (_) => fail('Expected success'),
      );
    });

    test('returns PasswordPolicy.fallback() on repository failure — never a Failure', () async {
      when(() => mockRepository.getPasswordPolicy())
          .thenAnswer((_) async => Failure(const NetworkException()));

      final result = await usecase.call();

      result.fold(
        (policy) {
          expect(policy.minLength, 8);
          expect(policy.maxLength, 72);
          expect(policy.requireUppercase, isTrue);
          expect(policy.requireLowercase, isTrue);
          expect(policy.requireDigit, isTrue);
          expect(policy.requireSpecialChar, isTrue);
        },
        (_) => fail('Usecase should always succeed, falling back on failure'),
      );
    });
  });
}
