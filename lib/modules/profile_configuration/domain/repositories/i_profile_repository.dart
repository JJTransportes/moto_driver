import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:result_dart/result_dart.dart';

abstract class IProfileRepository {
  Future<Result<ProfileEntity>> getProfile(String userId);
  Future<Result<ProfileEntity>> updateProfile(ProfileEntity profile);
  Future<Result<String>> uploadImage(String userId, String filePath);
}
