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
