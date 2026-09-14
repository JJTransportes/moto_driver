import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/core/utils/validators.dart' as validators;

void main() {
  const policy = PasswordPolicy(
    minLength: 8,
    maxLength: 72,
    requireUppercase: true,
    requireLowercase: true,
    requireDigit: true,
    requireSpecialChar: true,
  );

  group('evaluatePasswordPolicy', () {
    test('reports every requirement unmet for an empty password', () {
      final requirements = validators.evaluatePasswordPolicy('', policy);
      expect(requirements, hasLength(5));
      expect(requirements.every((r) => !r.satisfied), isTrue);
    });

    test('length requirement respects min/max boundaries', () {
      expect(
        validators.evaluatePasswordPolicy('Ab1!Ab1!', policy).first.satisfied,
        isTrue,
      ); // 8 chars, no exemplo abaixo
      expect(
        validators.evaluatePasswordPolicy('Ab1!Ab1', policy).first.satisfied,
        isFalse,
      ); // 7 chars — abaixo do mínimo
    });

    test('each requirement is evaluated independently', () {
      final requirements = validators.evaluatePasswordPolicy('abcdefgh', policy);
      final byLabel = {for (final r in requirements) r.label: r.satisfied};
      expect(byLabel['Pelo menos 1 letra minúscula'], isTrue);
      expect(byLabel['Pelo menos 1 letra maiúscula'], isFalse);
      expect(byLabel['Pelo menos 1 número'], isFalse);
      expect(byLabel['Pelo menos 1 caractere especial (ex: ! @ # \$ % &)'], isFalse);
    });

    test('a fully valid password satisfies every requirement', () {
      final requirements = validators.evaluatePasswordPolicy('Abcdef1!', policy);
      expect(requirements.every((r) => r.satisfied), isTrue);
    });

    test('disabled requirements in the policy are omitted from the list', () {
      const relaxedPolicy = PasswordPolicy(
        minLength: 8,
        maxLength: 72,
        requireUppercase: false,
        requireLowercase: true,
        requireDigit: true,
        requireSpecialChar: false,
      );
      final requirements = validators.evaluatePasswordPolicy('abcdefg1', relaxedPolicy);
      expect(requirements, hasLength(3)); // length + lowercase + digit
    });
  });

  group('isPasswordValid', () {
    test('true only when every applicable requirement passes', () {
      expect(validators.isPasswordValid('Abcdef1!', policy), isTrue);
      expect(validators.isPasswordValid('abcdefg1', policy), isFalse);
    });
  });

  group('validateEmailFormat', () {
    const validEmails = [
      'igor.almeida@gmail.com',
      'igor@sub.mail.empresa.com.br',
      'a@b.co',
    ];

    const invalidEmails = [
      'igor.almeida@gmail...com',
      'igor@.gmail.com',
      'igor@gmail.com.',
      '.igor@gmail.com',
      'igor..almeida@gmail.com',
      'igor@gmail-.com',
      'igor@-gmail.com',
      'igor@gmail',
    ];

    for (final email in validEmails) {
      test('accepts $email', () {
        expect(validators.validateEmailFormat(email), isNull);
      });
    }

    for (final email in invalidEmails) {
      test('rejects $email', () {
        expect(validators.validateEmailFormat(email), isNotNull);
      });
    }
  });
}
