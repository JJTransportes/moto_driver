import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/utils/validators.dart' as validators;

void main() {
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
