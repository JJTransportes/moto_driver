import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';

abstract class ProfileConfigurationState {}

class ProfileInitial extends ProfileConfigurationState {}

class ProfileLoading extends ProfileConfigurationState {}

class ProfileLoaded extends ProfileConfigurationState {
  final ProfileEntity profile;
  ProfileLoaded({required this.profile});
}

class ProfileUpdateLoading extends ProfileConfigurationState {
  final ProfileEntity profile;
  ProfileUpdateLoading({required this.profile});
}

class ProfileUpdateSuccess extends ProfileConfigurationState {
  final ProfileEntity profile;

  /// True quando o e-mail salvo difere do e-mail carregado antes da edição —
  /// o backend invalida a sessão nesse caso, então o app precisa forçar logout.
  final bool emailChanged;

  ProfileUpdateSuccess({required this.profile, this.emailChanged = false});
}

class ProfileUpdateFailure extends ProfileConfigurationState {
  final ProfileEntity profile;
  final Exception error;
  ProfileUpdateFailure({required this.profile, required this.error});
}

class ProfileImageUploadLoading extends ProfileConfigurationState {
  final ProfileEntity profile;
  final double progress;
  ProfileImageUploadLoading({required this.profile, required this.progress});
}

class ProfileImageUploadSuccess extends ProfileConfigurationState {
  final ProfileEntity profile;
  final String photoUrl;
  ProfileImageUploadSuccess({required this.profile, required this.photoUrl});
}

class ProfileImageUploadFailure extends ProfileConfigurationState {
  final ProfileEntity profile;
  final Exception error;
  ProfileImageUploadFailure({required this.profile, required this.error});
}
