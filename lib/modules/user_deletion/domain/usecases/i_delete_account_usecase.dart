import 'package:result_dart/result_dart.dart';

abstract class IDeleteAccountUseCase {
  /// Deletes the authenticated user's account after verifying [password].
  ///
  /// Returns [Success(unit)] on success or [Failure] with the exception.
  Future<Result<void>> call(String password);
}
