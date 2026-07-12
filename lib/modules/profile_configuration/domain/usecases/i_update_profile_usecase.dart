import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:result_dart/result_dart.dart';

abstract class IUpdateProfileUseCase {
  Future<Result<ProfileEntity>> call(ProfileEntity profile);
}
