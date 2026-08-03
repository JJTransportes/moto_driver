import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/terms_storage.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';

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

  Future<void> signOut() async {
    await Future.wait([
      _authStorage.clear(),
      _authLocal.clearAuth(),
      _profileLocal.clearProfile(),
      _travelLocal.clearTravels(),
      _termsStorage.clear(),
    ]);
    Modular.to.navigate('/login');
  }
}
