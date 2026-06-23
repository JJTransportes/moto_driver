class UserEntity {
  final String id;
  final String token;
  final List<String> roles;

  const UserEntity({
    required this.id,
    required this.token,
    required this.roles,
  });

  bool get isDriver => roles.contains('Driver');
}
