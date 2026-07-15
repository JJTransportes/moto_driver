class RefreshTokenResponseModel {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final DateTime? refreshExpiresAt;
  final String userId;
  final List<String> roles;

  const RefreshTokenResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.refreshExpiresAt,
    required this.userId,
    required this.roles,
  });

  factory RefreshTokenResponseModel.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponseModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      refreshExpiresAt: json['refreshExpiresAt'] != null
          ? DateTime.parse(json['refreshExpiresAt'] as String)
          : null,
      userId: json['userId'] as String,
      roles: List<String>.from(json['roles'] as List),
    );
  }
}
