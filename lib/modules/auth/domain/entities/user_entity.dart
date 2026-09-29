import 'package:flutter/foundation.dart' show listEquals;

class UserEntity {
  final String id;
  final String token;
  final String? refreshToken;
  final List<String> roles;

  const UserEntity({
    required this.id,
    required this.token,
    this.refreshToken,
    required this.roles,
  });

  bool get isDriver => roles.contains('Driver');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          token == other.token &&
          refreshToken == other.refreshToken &&
          listEquals(roles, other.roles);

  @override
  int get hashCode => Object.hash(id, token, refreshToken, Object.hashAll(roles));
}
