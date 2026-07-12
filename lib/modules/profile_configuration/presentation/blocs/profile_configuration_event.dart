abstract class ProfileConfigurationEvent {}

class ProfileLoadEvent extends ProfileConfigurationEvent {
  final String userId;
  ProfileLoadEvent({required this.userId});
}

class ProfileUpdateEvent extends ProfileConfigurationEvent {
  final String name;
  final String email;
  final String phone;
  ProfileUpdateEvent({
    required this.name,
    required this.email,
    required this.phone,
  });
}

class ProfileImageUploadEvent extends ProfileConfigurationEvent {
  final String filePath;
  ProfileImageUploadEvent({required this.filePath});
}
