import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';

class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
    };
  }

  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      name: name,
      email: email,
      phone: phone,
      photoUrl: photoUrl,
    );
  }
}
