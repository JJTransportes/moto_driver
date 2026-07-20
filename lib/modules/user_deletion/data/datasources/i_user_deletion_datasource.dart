abstract class IUserDeletionDatasource {
  /// Deletes the authenticated user's account.
  ///
  /// The user is identified by the JWT token in the Authorization header.
  /// [password] is required for credential re-verification.
  ///
  /// Throws [UnauthorizedException], [ValidationException],
  /// [NotFoundException], or [ServerException] on failure.
  Future<void> deleteAccount(String password);
}
