import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/utils/masks.dart';

void main() {
  group('AlphanumericInputFormatter', () {
    final formatter = AlphanumericInputFormatter(maxLength: 20);

    TextEditingValue format(String text) => formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
        );

    test('strips dots, dashes, slashes and spaces', () {
      expect(format('12.345.678-9').text, '123456789');
      expect(format('SSP/MG 123456789').text, 'SSPMG123456789');
    });

    test('keeps letters and digits as typed, including case', () {
      expect(format('SSPMG123456789A').text, 'SSPMG123456789A');
    });

    test('caps at maxLength', () {
      expect(format('A' * 25).text.length, 20);
    });

    test('empty input stays empty', () {
      expect(format('').text, '');
    });

    test('respects a different maxLength (Matrícula = 30)', () {
      final matriculaFormatter = AlphanumericInputFormatter(maxLength: 30);
      final result = matriculaFormatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1234567890-A/B.C D'),
      );
      expect(result.text, '1234567890ABCD');
    });

    test('caps at 12 for the RG field configuration', () {
      final rgFormatter = AlphanumericInputFormatter(maxLength: 12);
      final result = rgFormatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'SSPMG123456789A'),
      );
      expect(result.text, 'SSPMG1234567'); // 12 primeiros caracteres alfanuméricos
    });
  });

  group('PhoneInputFormatter', () {
    final formatter = PhoneInputFormatter();

    TextEditingValue format(String text) => formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
        );

    test('formats a mobile number (11 digits) as (00) 00000-0000', () {
      expect(format('12912345678').text, '(12) 91234-5678');
    });

    test('formats a landline (10 digits) as (00) 0000-0000', () {
      expect(format('1234567890').text, '(12) 3456-7890');
    });

    test('shifts the split from 4+4 to 5+4 the moment the 9th local digit is typed', () {
      // 8 dígitos locais ainda são fixo-like (4+4)
      expect(format('123456789').text, '(12) 3456-789');
      // o 9º dígito local vira celular (5+4)
      expect(format('1234567890').text, '(12) 3456-7890');
    });

    test('ignores non-digit input already present (paste with mask)', () {
      expect(format('(12) 91234-5678').text, '(12) 91234-5678');
    });

    test('caps at 11 digits', () {
      expect(format('129123456789999').text, '(12) 91234-5678');
    });

    test('empty input stays empty', () {
      expect(format('').text, '');
    });

    test('partial input while typing shows only what has been entered', () {
      expect(format('1').text, '(1');
      expect(format('12').text, '(12');
      expect(format('123').text, '(12) 3');
    });
  });
}
