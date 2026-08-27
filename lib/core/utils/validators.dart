import 'masks.dart';

/// Validates a Brazilian CPF using the standard check-digit algorithm.
/// Mirrors the same logic used in the admin web panel, the passenger app,
/// and the backend's PersonValidator, so all layers agree on what counts
/// as a valid CPF. Returns null for a valid CPF (does NOT check for blank —
/// callers already handle the "campo obrigatório" case separately).
String? validateCpf(String cpf) {
  final digits = unmaskDigits(cpf);
  if (digits.length != 11) return 'CPF inválido.';
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return 'CPF inválido.';

  int calcDigit(String d, int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += int.parse(d[i]) * (length + 1 - i);
    }
    final rem = (sum * 10) % 11;
    return (rem == 10 || rem == 11) ? 0 : rem;
  }

  if (calcDigit(digits, 9) != int.parse(digits[9])) return 'CPF inválido.';
  if (calcDigit(digits, 10) != int.parse(digits[10])) return 'CPF inválido.';
  return null;
}

/// Enforces alphanumeric-only content (no punctuation/spaces) within
/// [minLength]..[maxLength] — the shape the backend requires. Does not
/// check for blank (empty is rejected by the [minLength] check only if
/// greater than zero; callers handle "campo obrigatório" separately).
String? validateAlphanumericFormat(
  String value,
  String fieldName,
  int maxLength, {
  int minLength = 1,
}) {
  final trimmed = value.trim();
  if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed)) {
    return '$fieldName deve conter apenas letras e números, sem pontuação.';
  }
  if (trimmed.length < minLength) {
    return '$fieldName deve ter no mínimo $minLength caracteres.';
  }
  if (trimmed.length > maxLength) {
    return '$fieldName deve ter no máximo $maxLength caracteres.';
  }
  return null;
}

/// RGs brasileiros válidos variam de 7 (estados/DF com numeração antiga e
/// curta) a 12 caracteres (casos raros com 11 dígitos + verificador, ou
/// legados com dígito verificador alfanumérico). Mesma faixa usada no
/// backend, já limpo de pontuação: ^[0-9A-Za-z]{7,12}$
String? validateRg(String rg) => validateAlphanumericFormat(rg, 'RG', 12, minLength: 7);

/// Telefone é opcional. Quando preenchido, precisa ter DDD + número (fixo
/// de 8 dígitos ou celular de 9) — 10 ou 11 dígitos ao todo. O backend não
/// valida formato de telefone; esta é só uma checagem de conveniência do
/// cliente para pegar número obviamente incompleto antes de enviar.
String? validatePhone(String phone) {
  final digits = unmaskDigits(phone);
  if (digits.length < 10 || digits.length > 11) {
    return 'Telefone inválido.';
  }
  return null;
}

/// CNH must be exactly 11 digits, matching the backend's CnhRegex.
String? validateCnh(String cnh) {
  final digits = unmaskDigits(cnh);
  if (digits.length != 11) return 'CNH deve conter exatamente 11 dígitos.';
  return null;
}

String? validateEmailFormat(String email) {
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'E-mail inválido.';
  }
  final safeTextError = validateSafeText(email, 'E-mail');
  if (safeTextError != null) return safeTextError;
  return null;
}

/// Matches the backend's InitialPasswordPolicy (min 8, max 72).
String? validatePasswordLength(String password) {
  if (password.length < 8) return 'Senha deve ter no mínimo 8 caracteres.';
  if (password.length > 72) return 'Senha deve ter no máximo 72 caracteres.';
  return null;
}

String? validateMaxLength(String value, int max, String fieldName) {
  if (value.trim().length > max) {
    return '$fieldName deve ter no máximo $max caracteres.';
  }
  return null;
}

/// Defense-in-depth for free-text inputs: blocks characters/patterns with no
/// legitimate use in names, addresses, etc. (HTML/script tags, SQL
/// meta-characters, event handler injection). Not the primary defense — the
/// backend must always use parameterized queries — but stops obviously
/// malicious input at the door, mirroring the same check in the web panel.
final RegExp _unsafeTextPattern = RegExp(
  r'<|>|javascript:|on\w+\s*=|--|/\*|\*/|;\s*(drop|delete|insert|update|select|exec)\b|\bunion\s+select\b|\bdrop\s+table\b|\bxp_\w+',
  caseSensitive: false,
);

String? validateSafeText(String value, String fieldName) {
  if (_unsafeTextPattern.hasMatch(value)) {
    return '$fieldName contém caracteres ou padrões não permitidos.';
  }
  return null;
}
