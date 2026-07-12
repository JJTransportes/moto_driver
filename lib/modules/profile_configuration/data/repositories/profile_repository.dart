import 'package:moto_driver/modules/profile_configuration/data/datasources/i_profile_datasource.dart';
import 'package:moto_driver/modules/profile_configuration/data/models/profile_model.dart';
import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_driver/modules/profile_configuration/domain/repositories/i_profile_repository.dart';
import 'package:result_dart/result_dart.dart';

class ProfileRepository implements IProfileRepository {
  final IProfileDatasource _datasource;

  ProfileRepository(this._datasource);

  @override
  Future<Result<ProfileEntity>> getProfile(String userId) async {
    try {
      final model = await _datasource.fetchProfile(userId);
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<ProfileEntity>> updateProfile(ProfileEntity profile) async {
    try {
      final model = await _datasource.updateProfile(
        profile.id,
        _toModel(profile),
      );
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<String>> uploadImage(String userId, String filePath) async {
    try {
      final url = await _datasource.uploadImage(userId, filePath);
      return Success(url);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  ProfileModel _toModel(ProfileEntity entity) {
    return ProfileModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      phone: entity.phone,
      photoUrl: entity.photoUrl,
    );
  }
}
