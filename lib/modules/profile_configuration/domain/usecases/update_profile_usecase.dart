import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_driver/modules/profile_configuration/domain/repositories/i_profile_repository.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_update_profile_usecase.dart';
import 'package:result_dart/result_dart.dart';

class UpdateProfileUseCase implements IUpdateProfileUseCase {
  final IProfileRepository _repository;

  UpdateProfileUseCase(this._repository);

  @override
  Future<Result<ProfileEntity>> call(ProfileEntity profile) {
    return _repository.updateProfile(profile);
  }
}
