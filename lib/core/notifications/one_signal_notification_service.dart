import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/local_db/repositories/notifications_local_repository.dart';
import 'package:moto_driver/core/notifications/inotification_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalNotificationService implements INotificationService {
  OneSignalNotificationService(
    this._dio,
    this._notificationsLocalRepository,
  );

  final Dio _dio;
  final NotificationsLocalRepository _notificationsLocalRepository;
  bool _initialized = false;
  bool _openingNotification = false;

  @override
  Future<void> initialize(String appId) async {
    // O projeto não tem a pasta web/ configurada com o SDK JS do OneSignal —
    // o canal de plugin não existe no Flutter Web. Sem esse guard, toda
    // chamada abaixo lança MissingPluginException nessa plataforma.
    if (kIsWeb) return;

    try {
      if (_initialized) {
        return;
      }

      await OneSignal.initialize(appId);

      // F11: antes, o chamador (BootstrapBloc) fazia um `Future.delayed(8s)`
      // incondicional após iniciar o OneSignal, só pra "dar tempo" do
      // playerId chegar — somando ~10s fixos a todo cold start, sempre,
      // mesmo quando o observer já disparou em bem menos tempo. Agora
      // `initialize()` só retorna quando o primeiro playerId chega (ou após
      // um teto de 8s como fallback de segurança, não como comportamento
      // padrão).
      final firstPlayerId = Completer<void>();

      OneSignal.User.addObserver(
        (state) async {
          final playerId = state.current.onesignalId;
          if (playerId == null) throw Exception('Player id not found.');

          await _notificationsLocalRepository.savePlayerId(playerId);
          if (!firstPlayerId.isCompleted) firstPlayerId.complete();
        },
      );

      await handleForegroundNotification();

      await firstPlayerId.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );

      _initialized = true;
    } catch (e) {
      throw Exception('Notification service initialization failed.');
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    return await OneSignal.Notifications.requestPermission(false);
  }

  /// Registra o device para push após o login.
  ///
  /// É best-effort de propósito: uma falha aqui (plugin ausente na
  /// plataforma, rede fora, backend de push indisponível) NUNCA pode
  /// impedir o motorista de logar. O AuthRepository chama isto na mesma
  /// tentativa do login — uma exceção não capturada aqui derruba a
  /// autenticação inteira mesmo com credenciais corretas.
  @override
  Future<void> login(String subscription, token) async {
    if (kIsWeb) return;

    try {
      await OneSignal.login(subscription);
      final playerId = await _notificationsLocalRepository.getPlayerId();
      final platform = Platform.isIOS ? 'ios' : 'android';

      final response = await _dio.post(
        '/api/notifications/register-device',
        data: {
          'playerId': playerId,
          'platform': platform,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      log(
        '[PUSH] Device registered: $platform / $playerId (status=${response.statusCode})',
        name: 'push',
      );
    } catch (e) {
      log('[PUSH] login/register-device failed: $e', name: 'push', level: 900);
    }
  }

  @override
  Future<void> handleForegroundNotification() async {
    OneSignal.Notifications.addClickListener((event) async {
      log(jsonEncode(event.notification.body));
      await handleNotificationClick(event.notification.additionalData);
    });

    // F13: com o app em primeiro plano, um pedido novo já chega via SignalR
    // e abre o `IncomingOrderSheet` (ver home_screen.dart). Sem isto, o
    // OneSignal também exibe o banner nativo da mesma notificação por cima
    // do sheet — duplicando o alerta do mesmo pedido.
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data['type'] == 'NewOrder') {
        event.preventDefault();
      }
    });
  }

  @visibleForTesting
  Future<void> handleNotificationClick(Map<String, dynamic>? data) async {
    if (data == null || data['type'] != 'NewOrder') return;

    final orderId = data['order_id'] as String? ?? data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return;

    if (await NotificationService.isOrderDismissed(orderId)) {
      log('[PUSH] Ignoring dismissed order: orderId=$orderId', name: 'push');
      unawaited(dismissNewOrder(orderId));
      return;
    }

    log('[PUSH] Notification clicked: orderId=$orderId', name: 'push');

    if (NotificationService.orderAlertOpen) {
      NotificationService.setPendingOrder(orderId);
      return;
    }

    // Uma notificação de oferta pode continuar na bandeja depois que ela já
    // foi aceita. Ao tocá-la durante uma viagem, abrir /order-refresh em
    // paralelo com a restauração da viagem criava duas navegações no mesmo
    // frame e corrompia a árvore do Navigator. Nesse caso, a viagem ativa é a
    // fonte canônica e o toque apenas deve levá-la para a frente.
    final activeTravelId = await _loadCanonicalActiveTravelId();
    if (activeTravelId != null) {
      try {
        NotificationService.clearPendingOrder();
        unawaited(dismissNewOrder(orderId));
        if (Modular.to.path != '/active-travel' && !_openingNotification) {
          _openingNotification = true;
          Modular.to.navigate(
            '/active-travel',
            arguments: {'travelId': activeTravelId},
          );
        }
      } catch (error, stackTrace) {
        NotificationService.setPendingOrder(orderId);
        log(
          '[PUSH] Active travel navigation is not ready.',
          name: 'push',
          error: error,
          stackTrace: stackTrace,
          level: 900,
        );
      } finally {
        _openingNotification = false;
      }
      return;
    }

    NotificationService.setPendingOrder(orderId);

    // Durante login/termos/bootstrap o Navigator ainda está sendo montado.
    // Conserva o pedido para a Home consumi-lo depois, sem disputar navegação.
    try {
      final path = Modular.to.path;
      if (path == '/' ||
          path == '/login' ||
          path == '/terms' ||
          path == '/bootstrap') {
        return;
      }
      if (await Modular.get<AuthStorage>().getRefreshToken() == null) return;
      if (_openingNotification || path == '/order-refresh') return;
    } catch (error, stackTrace) {
      log(
        '[PUSH] Navigation is not ready; order kept pending.',
        name: 'push',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
      return;
    }

    _openingNotification = true;
    try {
      await Modular.to.pushNamed(
        '/order-refresh',
        arguments: {'orderId': orderId},
      );
    } catch (error, stackTrace) {
      log(
        '[PUSH] Could not open order; order kept pending.',
        name: 'push',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
    } finally {
      _openingNotification = false;
    }
  }

  /// O cache local pode conter uma viagem já encerrada. Só impede a abertura
  /// de uma oferta quando o backend confirmar uma viagem realmente ativa.
  Future<String?> _loadCanonicalActiveTravelId() async {
    try {
      final response = await _dio.get('/api/travels/active');
      if (response.statusCode != 200 || response.data is! Map) return null;
      final data = Map<String, dynamic>.from(response.data as Map);
      final travelId = data['travelId'];
      return travelId is String && travelId.isNotEmpty ? travelId : null;
    } catch (e) {
      log(
        '[PUSH] Could not confirm active travel; opening the order instead.',
        name: 'push',
        level: 900,
      );
      return null;
    }
  }

  @override
  Future<void> dismissNewOrder(String orderId) async {
    if (kIsWeb || orderId.isEmpty) return;
    try {
      await OneSignal.Notifications.removeGroupedNotifications(
        'order_$orderId',
      );
    } catch (e) {
      // Best-effort: versões antigas do push podem não ter o grupo.
      log('[PUSH] Failed to remove order notification: $e', name: 'push');
    }
  }
}
