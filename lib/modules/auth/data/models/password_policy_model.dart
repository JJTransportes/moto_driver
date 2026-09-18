import 'package:moto_driver/core/models/password_policy.dart';

/// Mapeia o payload de `GET /api/auth/password-policy` para o value object
/// [PasswordPolicy] de `core`.
class PasswordPolicyModel {
  static PasswordPolicy fromJson(Map<String, dynamic> json) {
    return PasswordPolicy(
      minLength: json['minLength'] as int,
      maxLength: json['maxLength'] as int,
      requireUppercase: json['requireUppercase'] as bool,
      requireLowercase: json['requireLowercase'] as bool,
      requireDigit: json['requireDigit'] as bool,
      requireSpecialChar: json['requireSpecialChar'] as bool,
    );
  }
}
