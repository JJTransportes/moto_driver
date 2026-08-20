import 'dart:developer' show log;

import 'package:dio/dio.dart';
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
  final Dio _dio;
  final AuthLocalRepository _authLocal;
  final ProfileLocalRepository _profileLocal;
  final TravelLocalRepository _travelLocal;
  final TermsStorage _termsStorage;
  final AvailabilityDatasource _availability;

  SignOutService(
    this._authStorage,
    this._dio,
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

    // Device binding: libera a sessão no backend (device=NULL nos tokens
    // ativos) para que outro tipo de dispositivo possa logar. O AuthInterceptor
    // anexa o Bearer token automaticamente — por isso roda ANTES do clear.
    try {
      if (await _authStorage.getToken() != null) {
        await _dio.post('/api/auth/sign-out');
      }
    } catch (e) {
      log('[AUTH] sign-out API failed (best-effort): $e', name: 'auth');
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
