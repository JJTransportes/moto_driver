import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_get_profile_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_update_profile_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_upload_profile_image_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/blocs/profile_configuration_event.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/blocs/profile_configuration_state.dart';

class ProfileConfigurationBloc extends Bloc<ProfileConfigurationEvent, ProfileConfigurationState> {
  final IGetProfileUseCase _getProfile;
  final IUpdateProfileUseCase _updateProfile;
  final IUploadProfileImageUseCase _uploadImage;

  ProfileEntity? _lastLoadedProfile;

  ProfileConfigurationBloc({
    required IGetProfileUseCase getProfile,
    required IUpdateProfileUseCase updateProfile,
    required IUploadProfileImageUseCase uploadImage,
  })  : _getProfile = getProfile,
        _updateProfile = updateProfile,
        _uploadImage = uploadImage,
        super(ProfileInitial()) {
    on<ProfileLoadEvent>(_onLoad);
    on<ProfileUpdateEvent>(_onUpdate);
    on<ProfileImageUploadEvent>(_onUploadImage);
  }

  Future<void> _onLoad(ProfileLoadEvent event, Emitter<ProfileConfigurationState> emit) async {
    emit(ProfileLoading());
    final result = await _getProfile(event.userId);
    result.fold(
      (profile) {
        _lastLoadedProfile = profile;
        emit(ProfileLoaded(profile: profile));
      },
      (error) {
        emit(ProfileUpdateFailure(
          profile: _lastLoadedProfile ?? ProfileEntity(
            id: event.userId,
            name: '',
            email: '',
            phone: '',
          ),
          error: error,
        ));
      },
    );
  }

  Future<void> _onUpdate(ProfileUpdateEvent event, Emitter<ProfileConfigurationState> emit) async {
    final profile = _lastLoadedProfile;
    if (profile == null) return;

    emit(ProfileUpdateLoading(profile: profile));
    final updated = profile.copyWith(
      name: event.name,
      email: event.email,
      phone: event.phone,
    );
    final result = await _updateProfile(updated);
    result.fold(
      (profile) {
        _lastLoadedProfile = profile;
        emit(ProfileUpdateSuccess(profile: profile));
      },
      (error) => emit(ProfileUpdateFailure(profile: profile, error: error)),
    );
  }

  Future<void> _onUploadImage(ProfileImageUploadEvent event, Emitter<ProfileConfigurationState> emit) async {
    final profile = _lastLoadedProfile;
    if (profile == null) return;

    emit(ProfileImageUploadLoading(profile: profile, progress: 0.0));

    final authStorage = Modular.get<AuthStorage>();
    final authUserId = await authStorage.getUserId();
    final result = await _uploadImage(authUserId ?? profile.id, event.filePath);
    result.fold(
      (photoUrl) {
        final updatedProfile = profile.copyWith(photoUrl: photoUrl);
        _lastLoadedProfile = updatedProfile;
        emit(ProfileImageUploadSuccess(profile: updatedProfile, photoUrl: photoUrl));
        // Reload to get fresh data from backend
        add(ProfileLoadEvent(userId: profile.id));
      },
      (error) => emit(ProfileImageUploadFailure(profile: profile, error: error)),
    );
  }
}
