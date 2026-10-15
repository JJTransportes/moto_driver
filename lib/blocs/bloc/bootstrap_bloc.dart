import 'dart:async';
import 'dart:io' show Platform;

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/config/device_type.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/core/errors/user_error_message.dart';
import 'package:moto_driver/core/local_db/local_database_service.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/notifications/inotification_service.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';

part 'bootstrap_events.dart';
part 'bootstrap_states.dart';

class BootstrapBloc extends Bloc<BootstrapEvents, BootstrapStates> {
  BootstrapBloc(
    this._notificationService,
    this._authStorage,
    this._authRepository,
    this._signOutService, {
    Duration notificationPermissionTimeout = const Duration(seconds: 10),
    Future<void> Function()? requestLocationPermission,
    bool? isIOS,
  }) : _notificationPermissionTimeout = notificationPermissionTimeout,
       _requestLocationPermission =
           requestLocationPermission ??
           LocationService.requestPermissionIfNeeded,
       _isIOS = isIOS ?? (!kIsWeb && Platform.isIOS),
       super(BootstrapInitial()) {
    on<ConfigureApplicationEvent>(_configureApplicationEventHandler);
    on<CheckAuthEvent>(_checkAuthEventHandler);
  }

  final INotificationService _notificationService;
  final AuthStorage _authStorage;
  final IAuthRepository _authRepository;
  final SignOutService _signOutService;
  final Duration _notificationPermissionTimeout;
  final Future<void> Function() _requestLocationPermission;
  final bool _isIOS;

  FutureOr<void> _configureApplicationEventHandler(
    ConfigureApplicationEvent _,
    Emitter<BootstrapStates> emit,
  ) async {
    emit(LoadingConfigurationsState());

    await _initLocalPersistence(emit);
    await _requestLocationPermissionOnIOS();
    await _initializeNotificationService(emit);
    await _requestNotificationsPermission(emit);

    emit(ConfigurationSuccessState());
  }

  FutureOr<void> _checkAuthEventHandler(
    CheckAuthEvent _,
    Emitter<BootstrapStates> emit,
  ) async {
    emit(AuthCheckLoadingState());

    final refreshToken = await _authStorage.getRefreshToken();

    if (refreshToken != null) {
      bool userAuthenticated = false;

      final result = await _authRepository.refreshToken(
        refreshToken,
        deviceType,
      );

      final success = result.getOrNull();
      if (success != null) {
        userAuthenticated = true;
        await Future.wait([
          _authStorage.saveToken(success.accessToken, success.userId),
          _authStorage.saveRefreshToken(success.refreshToken),
        ]);
      } else {
        final error = result.exceptionOrNull();
        if (_isInvalidSession(error)) {
          await _signOutService.signOut();
        } else {
          // Sem rede/servidor indisponível ao reabrir o app não invalida a
          // sessão nem pode apagar uma viagem ativa salva localmente.
          userAuthenticated = true;
        }
      }

      emit(
        userAuthenticated
            ? TermsNavigationState() //
            : LoginNavigationState(),
      );
    } else {
      emit(LoginNavigationState());
    }
  }

  bool _isInvalidSession(Object? error) =>
      error is UnauthorizedException ||
      error is ValidationException ||
      error is DeviceMismatchException;

  Future<void> _initLocalPersistence(Emitter<BootstrapStates> emit) async {
    try {
      emit(LocalPersistenceConfigurationState());
      await LocalDatabaseService.init();
    } on Exception catch (e) {
      emit(LocalPersistenceFailureState(message: userErrorMessage(e)));
    }
  }

  Future<void> _initializeNotificationService(
    Emitter<BootstrapStates> emit,
  ) async {
    emit(NotificationServiceConfigurationState());
    try {
      final appId = AppConfig.getOneSignalAppId();
      // F11: a espera pelo playerId do OneSignal (com teto de 8s como
      // fallback, não incondicional) já acontece dentro de initialize().
      await _notificationService.initialize(appId);
    } on Exception catch (e) {
      emit(
        NotificationServiceFailureState(
          message: userErrorMessage(
            e,
            fallback: 'Não foi possível preparar as notificações.',
          ),
        ),
      );
    }
  }

  /// No iOS ninguém mais pede a permissão de localização: o aviso do Android
  /// (`MandatoryLocationGate`) e o serviço em segundo plano são só do Android, e
  /// o envio da posição na Home apenas consulta a permissão (sai em silêncio se
  /// negada). Sem este pedido o motorista nunca aparece no mapa do dashboard.
  Future<void> _requestLocationPermissionOnIOS() async {
    if (!_isIOS) return;
    try {
      await _requestLocationPermission().timeout(
        _notificationPermissionTimeout,
        onTimeout: () {},
      );
    } on Exception {
      // Best-effort: não pode travar a abertura do app.
    }
  }

  Future<void> _requestNotificationsPermission(
    Emitter<BootstrapStates> emit,
  ) async {
    emit(NotificationsPermissionRequestState());
    try {
      // No iOS o retorno do pedido pode se perder quando o diálogo aparece
      // durante a abertura do app; sem teto, a tela de bootstrap ficaria
      // parada para sempre mesmo com a permissão respondida.
      await _notificationService.requestNotificationPermission().timeout(
        _notificationPermissionTimeout,
        onTimeout: () => false,
      );
    } on Exception {
      // Permissão de notificação é best-effort: não pode travar a abertura.
    }
  }
}
