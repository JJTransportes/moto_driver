import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:result_dart/result_dart.dart';

abstract class ILoginUsecase {
  Future<Result<UserEntity>> call(String email, String password);
}
