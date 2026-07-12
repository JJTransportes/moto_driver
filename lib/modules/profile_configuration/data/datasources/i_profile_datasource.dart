import 'package:moto_driver/modules/profile_configuration/data/models/profile_model.dart';

abstract class IProfileDatasource {
  /// Fetches the profile for the given [userId].
  ///
  /// Returns [ProfileModel] on success.
  /// Throws a typed exception (e.g. [NotFoundException], [NetworkException]) on failure.
  Future<ProfileModel> fetchProfile(String userId);

  /// Updates name, email, and phone for the given [userId].
  ///
  /// Returns the updated [ProfileModel] on success.
  /// Throws a typed exception on failure.
  Future<ProfileModel> updateProfile(String userId, ProfileModel model);

  /// Uploads a profile image from [filePath] for the given [userId].
  ///
  /// Returns the public photo URL on success.
  /// Throws a typed exception on failure.
  Future<String> uploadImage(String userId, String filePath);
}
