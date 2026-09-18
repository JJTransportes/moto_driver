/// Bloqueia o reenvio de um formulário depois de um erro retornado pelo
/// servidor (ex.: e-mail já cadastrado, código inválido) até que o usuário
/// edite o campo responsável pelo erro — evita spammar o botão de
/// submit com o mesmo dado que o backend já rejeitou.
class ServerErrorGuard {
  String? _field;
  String? _snapshot;

  bool get isBlocking => _field != null;
  String? get blockedField => _field;

  /// Marca [field] como bloqueado, guardando o valor atual do controller
  /// para detectar quando o usuário o alterar.
  void block(String field, String currentValue) {
    _field = field;
    _snapshot = currentValue;
  }

  /// Chamar a cada mudança de campo. Se [field] for o campo bloqueado e
  /// [currentValue] tiver mudado desde o [block], libera o bloqueio.
  void clearIfEdited(String field, String currentValue) {
    if (_field == field && currentValue != _snapshot) {
      _field = null;
      _snapshot = null;
    }
  }
}
