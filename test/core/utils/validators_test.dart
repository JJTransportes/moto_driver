import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/utils/validators.dart';

void main() {
  group('validateAlphanumericFormat', () {
    test('accepts letters and digits only', () {
      expect(validateAlphanumericFormat('SSPMG123456789A', 'RG', 20), isNull);
      expect(validateAlphanumericFormat('12345', 'Matrícula', 30), isNull);
    });

    // Regressão: o backend rejeita qualquer pontuação em RG e Matrícula
    // (regex ^[A-Za-z0-9]+$). O formulário não deve mais deixar isso passar
    // — nem digitar, nem colar por fora do formatter.
    test('rejects punctuation', () {
      expect(validateAlphanumericFormat('12.345.678-9', 'RG', 20), isNotNull);
      expect(validateAlphanumericFormat('123 456', 'Matrícula', 30), isNotNull);
    });

    test('rejects value longer than maxLength', () {
      expect(validateAlphanumericFormat('A' * 21, 'RG', 20), isNotNull);
      expect(validateAlphanumericFormat('A' * 20, 'RG', 20), isNull);
    });
  });

  group('validateRg', () {
    // Faixa 7–12 caracteres, alfanumérico, sem pontuação — mesma regra do
    // backend (^[0-9A-Za-z]{7,12}$ após limpar pontuação).
    test('accepts values within 7-12 characters', () {
      expect(validateRg('1234567'), isNull); // 7 — limite mínimo
      expect(validateRg('123456789012'), isNull); // 12 — limite máximo
      expect(validateRg('SSPMG123A'), isNull); // 9, com letras
    });

    test('rejects fewer than 7 characters', () {
      expect(validateRg('123456'), isNotNull); // 6
    });

    test('rejects more than 12 characters', () {
      expect(validateRg('1234567890123'), isNotNull); // 13
    });

    test('rejects punctuation even within the length range', () {
      expect(validateRg('12.345.678-9'), isNotNull);
    });
  });

  group('validatePhone', () {
    test('accepts a landline (10 digits) or mobile (11 digits), masked or not', () {
      expect(validatePhone('(12) 3456-7890'), isNull);
      expect(validatePhone('(12) 91234-5678'), isNull);
      expect(validatePhone('1234567890'), isNull);
      expect(validatePhone('12912345678'), isNull);
    });

    test('rejects fewer than 10 digits', () {
      expect(validatePhone('123456789'), isNotNull); // 9
    });

    test('rejects more than 11 digits', () {
      expect(validatePhone('123456789012'), isNotNull); // 12
    });
  });
}
