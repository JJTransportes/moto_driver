import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';

/// Espelha `AddressDto` do backend (`Moto.Api.Dtos.Passengers.AddressDto`),
/// lido do objeto aninhado `address` de `GET /api/drivers/{userId}` — NÃO dos
/// campos soltos `city`/`state` de nível raiz (legado, ignorados aqui). Ver F05.
class ProfileAddressModel {
  final String lineOne;
  final String? lineTwo;
  final String? district;
  final String city;
  final String state;
  final String? postalCode;
  final String countryCode;

  const ProfileAddressModel({
    required this.lineOne,
    this.lineTwo,
    this.district,
    required this.city,
    required this.state,
    this.postalCode,
    required this.countryCode,
  });

  factory ProfileAddressModel.fromJson(Map<String, dynamic> json) {
    return ProfileAddressModel(
      lineOne: json['lineOne'] as String? ?? '',
      lineTwo: json['lineTwo'] as String?,
      district: json['district'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      postalCode: json['postalCode'] as String?,
      countryCode: json['countryCode'] as String? ?? '',
    );
  }

  ProfileAddressEntity toEntity() {
    return ProfileAddressEntity(
      lineOne: lineOne,
      lineTwo: lineTwo,
      district: district,
      city: city,
      state: state,
      postalCode: postalCode,
      countryCode: countryCode,
    );
  }
}

class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final ProfileAddressModel? address;

  /// Write-only: senha atual, exigida pelo backend para confirmar a
  /// alteração de perfil. Nunca vem em uma resposta, então não é lido
  /// em [fromJson] nem exposto na [ProfileEntity].
  final String? password;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.address,
    this.password,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final addressJson = json['address'];
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      address: addressJson is Map<String, dynamic>
          ? ProfileAddressModel.fromJson(addressJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      if (password != null) 'password': password,
    };
  }

  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      name: name,
      email: email,
      phone: phone,
      photoUrl: photoUrl,
      address: address?.toEntity(),
    );
  }
}
