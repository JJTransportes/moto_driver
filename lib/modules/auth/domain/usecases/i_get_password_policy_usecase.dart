import 'package:moto_driver/core/models/password_policy.dart';
import 'package:result_dart/result_dart.dart';

abstract class IGetPasswordPolicyUsecase {
  /// Busca a política de senha vigente. Sempre-sucesso: se o backend falhar
  /// (rede/5xx), devolve [PasswordPolicy.fallback] em vez de propagar o
  /// erro — a política é secundária ao fluxo de reset/cadastro (design D4).
  Future<Result<PasswordPolicy>> call();
}
