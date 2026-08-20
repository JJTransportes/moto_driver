import 'package:result_dart/result_dart.dart';

abstract class IRequestPasswordResetUsecase {
  Future<Result<Unit>> call(String email);
}
