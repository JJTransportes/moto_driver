import 'package:result_dart/result_dart.dart';

abstract class IUserDeletionRepository {
  /// Deletes the authenticated user's account after verifying [password].
  ///
  /// Returns [Success(unit)] on success or [Failure] with the exception.
  Future<Result<void>> deleteAccount(String password);
}
