import 'package:result_dart/result_dart.dart';

abstract class IConfirmPasswordResetUsecase {
  Future<Result<Unit>> call({
    required String email,
    required String code,
    required String newPassword,
  });
}
