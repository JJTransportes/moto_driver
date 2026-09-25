/// Endereço residencial do motorista, lido do objeto aninhado `address` do
/// backend (`GET /api/drivers/{userId}` → `DriverProfileResponse.Address`,
/// tipo `AddressDto`). Os campos soltos `city`/`state` de nível raiz do
/// mesmo endpoint são cópia legada e NÃO alimentam esta entidade — ver F05
/// do relatório de auditoria.
class ProfileAddressEntity {
  final String lineOne;
  final String? lineTwo;
  final String? district;
  final String city;
  final String state;
  final String? postalCode;
  final String countryCode;

  const ProfileAddressEntity({
    required this.lineOne,
    this.lineTwo,
    this.district,
    required this.city,
    required this.state,
    this.postalCode,
    required this.countryCode,
  });

  /// Formatação simples para exibição somente-leitura, ex.:
  /// "Rua Exemplo, 123 - Centro, Cidade - UF".
  String get formatted {
    final parts = <String>[lineOne];
    if (district != null && district!.isNotEmpty) parts.add(district!);
    final cityState = '$city - $state';
    return '${parts.join(' - ')}, $cityState';
  }
}

class ProfileEntity {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final ProfileAddressEntity? address;

  const ProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.address,
  });

  ProfileEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    ProfileAddressEntity? address,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
    );
  }
}
