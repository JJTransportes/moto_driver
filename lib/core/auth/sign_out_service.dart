import 'dart:developer' show log;

import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/terms_storage.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/modules/driver_availability/data/datasources/availability_datasource.dart';

class SignOutService {
  final AuthStorage _authStorage;
  final AuthLocalRepository _authLocal;
  final ProfileLocalRepository _profileLocal;
  final TravelLocalRepository _travelLocal;
  final TermsStorage _termsStorage;
  final AvailabilityDatasource _availability;

  SignOutService(
    this._authStorage,
    this._authLocal,
    this._profileLocal,
    this._travelLocal,
    this._termsStorage,
    this._availability,
  );

  Future<void> signOut() async {
    try {
      await _availability.deactivate();
    } catch (e) {
      log('[AVAILABILITY] deactivate failed on signOut: $e', name: 'availability');
    }

    // RF12: pendente/flags não podem vazar entre sessões (o device continua
    // registrado no OneSignal após o logout).
    NotificationService.clearPendingOrder();
    NotificationService.setOrderAlertOpen(false);

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
