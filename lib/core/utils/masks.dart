import 'package:flutter/services.dart';

/// Strips everything but digits.
String unmaskDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Strips everything but digits and the letter X (used in some RG check digits).
String unmaskRg(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

/// Formats as the user types: 000.000.000-00
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = unmaskDigits(newValue.text).substring(
      0,
      unmaskDigits(newValue.text).length > 11
          ? 11
          : unmaskDigits(newValue.text).length,
    );

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 2 || i == 5) {
        if (i != digits.length - 1) buffer.write('.');
      } else if (i == 8) {
        if (i != digits.length - 1) buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats as the user types: (00) 0000-0000 for landlines (10 digits) or
/// (00) 00000-0000 for mobiles (11 digits). The split shifts from 4+4 to
/// 5+4 automatically the moment a 9th local digit is typed — same
/// incremental behavior as the CPF/RG formatters above.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = unmaskDigits(newValue.text);
    final capped = digits.length > 11 ? digits.substring(0, 11) : digits;

    if (capped.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    final ddd = capped.length > 2 ? capped.substring(0, 2) : capped;
    final rest = capped.length > 2 ? capped.substring(2) : '';

    String formatted;
    if (rest.isEmpty) {
      formatted = '($ddd';
    } else {
      // 9 dígitos locais = celular (5+4); 8 ou menos = fixo/ainda digitando (4+4).
      final splitAt = rest.length > 8 ? 5 : 4;
      final part1 = rest.length > splitAt ? rest.substring(0, splitAt) : rest;
      final part2 = rest.length > splitAt ? rest.substring(splitAt) : '';
      formatted = '($ddd) $part1';
      if (part2.isNotEmpty) formatted += '-$part2';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Restricts input to letters and digits (optionally capped at
/// [maxLength]) — no dots, dashes, slashes or spaces. Used for RG and
/// Matrícula: the backend rejects any punctuation in both fields
/// (`^[A-Za-z0-9]+$`), and RG formats vary by state (letters mixed in,
/// different lengths), so a fixed visual mask doesn't fit either field.
class AlphanumericInputFormatter extends TextInputFormatter {
  AlphanumericInputFormatter({this.maxLength});

  final int? maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final cap = maxLength;
    if (cap != null && text.length > cap) {
      text = text.substring(0, cap);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
