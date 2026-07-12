class ProfileEntity {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;

  const ProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
  });

  ProfileEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
