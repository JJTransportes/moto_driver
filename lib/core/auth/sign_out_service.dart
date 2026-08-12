import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/terms_storage.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';

class SignOutService {
  final AuthStorage _authStorage;
  final AuthLocalRepository _authLocal;
  final ProfileLocalRepository _profileLocal;
  final TravelLocalRepository _travelLocal;
  final TermsStorage _termsStorage;

  SignOutService(
    this._authStorage,
    this._authLocal,
    this._profileLocal,
    this._travelLocal,
    this._termsStorage,
  );

  /// Limpa a sessão e volta para o login.
  ///
  /// As limpezas são sequenciais (escritas concorrentes no secure storage
  /// corrompem a chave AES no web) e individualmente tolerantes a falha: este é
  /// o caminho de recuperação de sessão inválida, então a navegação para
  /// `/login` tem que acontecer mesmo que alguma limpeza falhe.
  Future<void> signOut() async {
    // RF02: Desvincular External ID antes de limpar dados
    await NotificationService.logout();

    await Future.wait([
      _authStorage.clear(),
      _authLocal.clearAuth(),
      _profileLocal.clearProfile(),
      _travelLocal.clearTravels(),
      _termsStorage.clear(),
    ]);
    Modular.to.navigate('/login');
  }

  Future<void> _runSafely(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      // Uma limpeza que falha não pode impedir o motorista de voltar ao login.
      debugPrint('SignOutService: falha ao limpar $label — $e');
    }
  }
}
