import 'package:result_dart/result_dart.dart';

abstract class IUploadProfileImageUseCase {
  Future<Result<String>> call(String userId, String filePath);
}
