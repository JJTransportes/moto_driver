import 'package:dio/dio.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/profile_configuration/data/datasources/i_profile_datasource.dart';
import 'package:moto_driver/modules/profile_configuration/data/models/profile_model.dart';

class ProfileDatasource implements IProfileDatasource {
  final Dio _dio;

  ProfileDatasource(this._dio);

  @override
  Future<ProfileModel> fetchProfile(String userId) async {
    try {
      final response = await _dio.get('/api/drivers/$userId');
      final json = Map<String, dynamic>.from(response.data as Map);
      return ProfileModel.fromJson(_resolvePhotoUrl(json));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<ProfileModel> updateProfile(String userId, ProfileModel model) async {
    try {
      final response = await _dio.put(
        '/api/drivers/$userId/profile',
        data: model.toJson(),
      );
      final json = Map<String, dynamic>.from(response.data as Map);
      return ProfileModel.fromJson(_resolvePhotoUrl(json));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<String> uploadImage(String userId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        '/api/drivers/$userId/profile/image',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      final photoUrl = response.data['photoUrl'] as String;
      return _resolveUrl(photoUrl);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Resolves a relative photoUrl (e.g. /api/files/{id}) to a full URL.
  /// If it's already absolute, returns as-is.
  Map<String, dynamic> _resolvePhotoUrl(Map<String, dynamic> json) {
    final photoUrl = json['photoUrl'] as String?;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      json['photoUrl'] = _resolveUrl(photoUrl);
    }
    return json;
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConfig.getBaseUrl()}$url';
  }

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return const ValidationException(
          'Dados inválidos. Verifique as informações e tente novamente.',
        );
      case 401:
        return const UnauthorizedException('Sessão expirada. Faça login novamente.');
      case 404:
        return const NotFoundException('Perfil não encontrado.');
      case 413:
        return const ValidationException('Arquivo muito grande. Envie uma imagem menor.');
      case 415:
        return const ValidationException('Formato de arquivo não suportado. Use JPEG ou PNG.');
      case var code when code != null && code >= 500:
        return const ServerException(
          'Erro interno do servidor. Tente novamente mais tarde.',
        );
      default:
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionError) {
          return const NetworkException(
            'Erro de conexão. Verifique sua internet e tente novamente.',
          );
        }
        return NetworkException(e.message ?? 'Erro inesperado. Tente novamente.');
    }
  }
}
