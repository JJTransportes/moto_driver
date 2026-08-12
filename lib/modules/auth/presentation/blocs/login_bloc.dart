import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_login_usecase.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final ILoginUsecase _loginUsecase;
  final AuthStorage _authStorage;
  final AuthLocalRepository _authLocal;

  LoginBloc(this._loginUsecase, this._authStorage, this._authLocal) : super(const LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());

    final result = await _loginUsecase.call(event.email, event.password);

    if (result.isSuccess()) {
      final user = result.getOrNull()!;
      await _authStorage.saveToken(user.token, user.id);
      if (user.refreshToken != null) {
        await _authStorage.saveRefreshToken(user.refreshToken!);
      }
      await _authLocal.saveAuth(
        userId: user.id,
        accessToken: user.token,
        roles: user.roles,
      );
      emit(LoginSuccess(user));

      // ── Push Notification flow (RF02 + RF03 + RF06 + RF08) ──
      // Executado em background após emitir sucesso
      unawaited(_setupPushNotifications(user.id));
      unawaited(_processPendingDeepLink());
    } else {
      emit(LoginFailure(result.exceptionOrNull()!.toString()));
    }
  }

  /// RF02 + RF03 + RF06: Setup completo de push notifications.
  Future<void> _setupPushNotifications(String userId) async {
    try {
      // RF06: Solicitar permissão (fire-and-forget — não bloqueia o fluxo).
      // OneSignal.login + register-device executam independente da resposta.
      // O targeting via external_user_ids funciona mesmo sem permissão
      // explícita (APNs/FCM entregam ao device de qualquer forma).
      NotificationService.requestPermission();

      // RF02: OneSignal.login com retry 3x
      await NotificationService.login(userId);

      // RF03: Registrar device token — usar getPlayerId() que resolve
      // imediatamente se o playerId já estiver disponível (evita race condition
      // do .first timeout quando o stream já emitiu antes do listener).
      try {
        final playerId = await NotificationService.getPlayerId();
        final dio = Modular.get<Dio>();
        final platform = Platform.isIOS ? 'ios' : 'android';
        await NotificationService.registerDevice(
          dio: dio,
          playerId: playerId,
          platform: platform,
        );
      } catch (e) {
        log('[PUSH] Failed to get playerId for register-device: $e',
            name: 'push', level: 900);
      }
    } catch (e) {
      log('[PUSH] Push setup failed: $e', name: 'push', level: 900);
    }
  }

  /// RF08: Processar deep link pendente após login.
  Future<void> _processPendingDeepLink() async {
    // Pequeno delay para garantir que a navegação pós-login já ocorreu
    await Future.delayed(const Duration(milliseconds: 300));
    NotificationService.processPending();
  }
}
