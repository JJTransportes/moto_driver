import 'dart:io';

import 'package:dio/dio.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i_brand_cache_service.dart';

class BrandCacheService implements IBrandCacheService {
  static const _etagKey = 'brand_image_etag';
  static const _fileName = 'moto_brand_image.png';

  final Dio _dio;

  BrandCacheService(this._dio);

  @override
  Future<String?> getBrandImagePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedEtag = prefs.getString(_etagKey);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$_fileName');

      final bool hasCachedFile = await file.exists();

      if (hasCachedFile && cachedEtag != null) {
        // Conditional request
        final response = await _dio.get<dynamic>(
          '${AppConfig.getBaseUrl()}/api/config/brand-image',
          options: Options(
            headers: {'If-None-Match': cachedEtag},
            responseType: ResponseType.bytes,
          ),
        );

        if (response.statusCode == 304) {
          // Not modified - use cached version
          return file.path;
        }

        if (response.statusCode == 200) {
          // Updated - save new version
          final bytes = response.data as List<int>;
          await file.writeAsBytes(bytes);

          final newEtag =
              response.headers.value('etag') ?? response.headers.value('ETag');
          if (newEtag != null) {
            await prefs.setString(_etagKey, newEtag);
          }

          return file.path;
        }

        if (response.statusCode == 404) {
          // Brand removed - clear cache
          await file.delete();
          await prefs.remove(_etagKey);
          return null;
        }
      }

      // No cache - unconditional download
      if (hasCachedFile) {
        // File exists but no ETag - delete stale cache
        await file.delete();
      }

      final response = await _dio.get<dynamic>(
        '${AppConfig.getBaseUrl()}/api/config/brand-image',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final bytes = response.data as List<int>;
        await file.writeAsBytes(bytes);

        final etag =
            response.headers.value('etag') ?? response.headers.value('ETag');
        if (etag != null) {
          await prefs.setString(_etagKey, etag);
        }

        return file.path;
      }

      // 404 or other error - no brand configured
      return null;
    } catch (_) {
      // Network error or other issue - return null gracefully
      return null;
    }
  }
}
