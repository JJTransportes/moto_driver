abstract class IBrandCacheService {
  /// Returns the file path to the cached brand image, or null if unavailable.
  /// Downloads on first call or when server version differs.
  Future<String?> getBrandImagePath();
}
