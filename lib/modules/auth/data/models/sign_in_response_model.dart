import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';

class SignInResponseModel {
  final String accessToken;
  final String? refreshToken;
  final DateTime? refreshExpiresAt;
  final DateTime expiresAt;
  final String userId;
  final List<String> roles;

  const SignInResponseModel({
    required this.accessToken,
    this.refreshToken,
    this.refreshExpiresAt,
    required this.expiresAt,
    required this.userId,
    required this.roles,
  });

  factory SignInResponseModel.fromJson(Map<String, dynamic> json) {
    return SignInResponseModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      refreshExpiresAt: json['refreshExpiresAt'] != null
          ? DateTime.parse(json['refreshExpiresAt'] as String)
          : null,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      userId: json['userId'] as String,
      roles: List<String>.from(json['roles'] as List),
    );
  }

  UserEntity toEntity() {
    return UserEntity(
      id: userId,
      token: accessToken,
      refreshToken: refreshToken,
      roles: roles,
    );
  }
}
