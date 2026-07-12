import 'package:moto_driver/modules/profile_configuration/domain/repositories/i_profile_repository.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_upload_profile_image_usecase.dart';
import 'package:result_dart/result_dart.dart';

class UploadProfileImageUseCase implements IUploadProfileImageUseCase {
  final IProfileRepository _repository;

  UploadProfileImageUseCase(this._repository);

  @override
  Future<Result<String>> call(String userId, String filePath) {
    return _repository.uploadImage(userId, filePath);
  }
}
