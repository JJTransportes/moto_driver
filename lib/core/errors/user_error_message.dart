import 'package:dio/dio.dart';
import 'package:moto_driver/core/errors/exceptions.dart';

String userErrorMessage(
  Object? error, {
  String fallback = 'Não foi possível concluir agora. Tente novamente.',
}) {
  if (error is NetworkException) return error.message;
  if (error is UnauthorizedException) return error.message;
  if (error is NotFoundException) return error.message;
  if (error is ValidationException) return error.message;
  if (error is DuplicateException) return error.message;
  if (error is ConflictException) return error.message;
  if (error is RateLimitedException) return error.message;
  if (error is DeviceConflictException) return error.message;
  if (error is DeviceMismatchException) return error.message;
  if (error is RoleMismatchException) return error.message;
  if (error is UnapprovedAccountException) return error.message;
  if (error is ForbiddenException) return error.message;
  if (error is ServerException) return error.message;
  if (error is DioException) return fallback;

  final rawText = error?.toString().trim() ?? '';
  final text = rawText.replaceFirst(RegExp(r'^Exception:\s*'), '');
  final technical = RegExp(
    r'(dioexception|socketexception|stack trace|statuscode|connection timeout|receive timeout|server error)',
    caseSensitive: false,
  );
  return text.isEmpty || technical.hasMatch(text) ? fallback : text;
}
