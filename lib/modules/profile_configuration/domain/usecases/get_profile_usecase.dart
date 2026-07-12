import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_driver/modules/profile_configuration/domain/repositories/i_profile_repository.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_get_profile_usecase.dart';
import 'package:result_dart/result_dart.dart';

class GetProfileUseCase implements IGetProfileUseCase {
  final IProfileRepository _repository;

  GetProfileUseCase(this._repository);

  @override
  Future<Result<ProfileEntity>> call(String userId) {
    return _repository.getProfile(userId);
  }
}
