import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:result_dart/result_dart.dart';

abstract class IAuthRepository {
  Future<Result<UserEntity>> signIn(String email, String password);
}
