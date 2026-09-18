import 'package:result_dart/result_dart.dart';

abstract class IVerifyResetCodeUsecase {
  /// Verifica o [code] recebido por e-mail para [email] (tela 1 do reset).
  /// Sucesso devolve o `resetToken` de uso único para a tela 2.
  Future<Result<String>> call({required String email, required String code});
}
