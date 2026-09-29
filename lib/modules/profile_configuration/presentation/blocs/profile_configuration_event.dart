abstract class ProfileConfigurationEvent {}

class ProfileLoadEvent extends ProfileConfigurationEvent {
  final String userId;
  ProfileLoadEvent({required this.userId});
}

class ProfileUpdateEvent extends ProfileConfigurationEvent {
  final String name;
  final String email;
  final String phone;

  /// Senha atual, exigida pelo backend para confirmar a alteração. Enviada
  /// apenas quando o e-mail mudou (fluxo com modal de confirmação de senha).
  final String? password;

  ProfileUpdateEvent({
    required this.name,
    required this.email,
    required this.phone,
    this.password,
  });
}

class ProfileImageUploadEvent extends ProfileConfigurationEvent {
  final String filePath;
  ProfileImageUploadEvent({required this.filePath});
}
