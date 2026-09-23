/// Regras de senha vindas de `GET /api/auth/password-policy` (público, sem
/// auth). Usado tanto no reset de senha (tela 2) quanto no cadastro de
/// motorista para avaliar o checklist de política de senha em tempo real.
class PasswordPolicy {
  final int minLength;
  final int maxLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireDigit;
  final bool requireSpecialChar;

  const PasswordPolicy({
    required this.minLength,
    required this.maxLength,
    required this.requireUppercase,
    required this.requireLowercase,
    required this.requireDigit,
    required this.requireSpecialChar,
  });

  /// Usada quando `GET /api/auth/password-policy` falha (rede/5xx) — mesma
  /// regra estática documentada no requirements (RF4): mínimo 8, máximo 72,
  /// com maiúscula, minúscula, número e caractere especial.
  const PasswordPolicy.fallback()
      : minLength = 8,
        maxLength = 72,
        requireUppercase = true,
        requireLowercase = true,
        requireDigit = true,
        requireSpecialChar = true;
}
