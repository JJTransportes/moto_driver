class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Credenciais inválidas']);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Recurso não encontrado']);
  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final String message;
  const ValidationException([this.message = 'Dados inválidos']);
  @override
  String toString() => message;
}

class DuplicateException implements Exception {
  final String message;
  final String? field;
  const DuplicateException(this.message, {this.field});
  @override
  String toString() => message;
}

class ConflictException implements Exception {
  final String message;
  const ConflictException([this.message = 'Operação em conflito com o estado atual']);
  @override
  String toString() => message;
}

class RateLimitedException implements Exception {
  final String message;
  const RateLimitedException([this.message = 'Muitas tentativas. Tente novamente mais tarde.']);
  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Erro de conexão. Verifique sua internet.']);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Erro interno do servidor. Tente novamente.']);
  @override
  String toString() => message;
}

/// 409 no sign-in: já existe sessão ativa vinculada a outro tipo de dispositivo.
class DeviceConflictException implements Exception {
  final String message;
  const DeviceConflictException([
    this.message = 'Já existe uma sessão ativa em outro tipo de dispositivo. Faça logout lá primeiro.',
  ]);
  @override
  String toString() => message;
}

/// 403 no refresh: o refresh token está vinculado a outro tipo de dispositivo.
class DeviceMismatchException implements Exception {
  final String message;
  const DeviceMismatchException([
    this.message = 'Sessão vinculada a outro tipo de dispositivo. Faça logout no dispositivo original.',
  ]);
  @override
  String toString() => message;
}
