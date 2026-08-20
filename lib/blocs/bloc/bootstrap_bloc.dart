import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/config/device_type.dart';
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
    this._signOutService,
  ) : super(BootstrapInitial()) {
    on<ConfigureApplicationEvent>(_configureApplicationEventHandler);
    on<CheckAuthEvent>(_checkAuthEventHandler);
  }

  final INotificationService _notificationService;
  final AuthStorage _authStorage;
  final IAuthRepository _authRepository;
  final SignOutService _signOutService;

  FutureOr<void> _configureApplicationEventHandler(
    ConfigureApplicationEvent _,
    Emitter<BootstrapStates> emit,
  ) async {
    emit(LoadingConfigurationsState());

    await _initLocalPersistence(emit);
    await _requestLocationPermission(emit);
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

      final result = await _authRepository.refreshToken(refreshToken, deviceType);

      result.fold(
        (success) async {
          userAuthenticated = true;

          await Future.wait([
            _authStorage.saveToken(success.accessToken, success.userId),
            _authStorage.saveRefreshToken(success.refreshToken),
          ]);
        },
        (_) async {
          await _signOutService.signOut();
        },
      );

      emit(
        userAuthenticated
            ? TermsNavigationState() //
            : LoginNavigationState(),
      );
    } else {
      emit(LoginNavigationState());
    }
  }

  Future<void> _initLocalPersistence(Emitter<BootstrapStates> emit) async {
    try {
      emit(LocalPersistenceConfigurationState());
      await LocalDatabaseService.init();
    } on Exception catch (e) {
      emit(LocalPersistenceFailureState(message: e.toString()));
    }
  }

  Future<void> _requestLocationPermission(Emitter<BootstrapStates> emit) async {
    emit(LocalPersistenceConfigurationState());
    await LocationService.requestPermissionIfNeeded();
  }

  Future<void> _initializeNotificationService(Emitter<BootstrapStates> emit) async {
    emit(NotificationServiceConfigurationState());
    try {
      final appId = AppConfig.getOneSignalAppId();
      await _notificationService.initialize(appId);

      await Future.delayed(const Duration(seconds: 8));
    } on Exception catch (e) {
      emit(NotificationServiceFailureState(message: e.toString()));
    }
  }

  Future<void> _requestNotificationsPermission(Emitter<BootstrapStates> emit) async {
    emit(NotificationsPermissionRequestState());
    await _notificationService.requestNotificationPermission();
  }
}
