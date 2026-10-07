import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/core/errors/user_error_message.dart';

void main() {
  test('não expõe detalhes técnicos do Dio', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/travels/secret-id'),
      type: DioExceptionType.connectionTimeout,
      message: 'connection timeout with internal server details',
    );

    final message = userErrorMessage(error);

    expect(message, 'Não foi possível concluir agora. Tente novamente.');
    expect(message, isNot(contains('DioException')));
  });

  test('preserva mensagem de negócio conhecida', () {
    expect(
      userErrorMessage(const ValidationException('Telefone obrigatório.')),
      'Telefone obrigatório.',
    );
  });
}
