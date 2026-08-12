import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Serviço central de push notifications via OneSignal.
///
/// Métodos estáticos para acesso global — necessário para os listeners do
/// OneSignal que disparam antes do Modular estar pronto (cold start).
class NotificationService {
  static bool _initialized = false;
  static String? _pendingOrderId;
  static bool _loginFailed = false;
  static bool _sheetVisible = false;

  // ── Player ID Stream (RF03) ──
  // BehaviorSubject pattern: armazena último valor + emite para novos listeners.

  static String? _lastPlayerId;
  static final StreamController<String> _playerIdController =
      StreamController<String>.broadcast();

  /// Stream que emite o playerId do OneSignal assim que disponível.
  /// Para consumo único, prefira [getPlayerId] que resolve imediatamente
  /// se o playerId já estiver disponível.
  static Stream<String> get onPlayerIdChanged => _playerIdController.stream;

  /// Obtém o playerId: retorna imediatamente se disponível,
  /// ou aguarda o stream com timeout de 10s.
  static Future<String> getPlayerId({Duration timeout = const Duration(seconds: 10)}) async {
    if (_lastPlayerId != null) {
      return _lastPlayerId!;
    }
    return onPlayerIdChanged.first.timeout(timeout);
  }

  // ── Inicialização (RF01) ──

  /// Inicializa o SDK do OneSignal. Deve ser chamado em [main] antes de runApp.
  static Future<void> init({required String appId}) async {
    if (_initialized) return;

    try {
      OneSignal.initialize(appId);

      // Observar mudanças no playerId (RF03)
      OneSignal.User.pushSubscription.addObserver((state) {
        final id = state.current.id;
        if (id != null) {
          _lastPlayerId = id;
          _playerIdController.add(id);
        }
      });

      _registerListeners();
      _initialized = true;
      log('[PUSH] OneSignal initialized', name: 'push');
    } catch (e) {
      log('[PUSH] OneSignal.initialize failed: $e', name: 'push', level: 1000);
    }
  }

  // ── Cold Start Capture (RF07) ──
  // O addClickListener dispara após OneSignal.initialize() tanto para cold
  // start (notificação que abriu o app) quanto para warm start (app já aberto).
  // Para cold start, o click pode ocorrer antes do Modular estar pronto —
  // usamos setPendingOrder + processPending no addPostFrameCallback.
  // NOTA: OneSignal Flutter v5.x NÃO tem getInitialNotification().
  // O addClickListener já cobre ambos os casos adequadamente.

  // ── External ID (RF02) ──

  /// Vincula o usuário autenticado ao OneSignal via External ID.
  /// Retry 3x com backoff (1s, 2s, 4s). Se falhar persistentemente,
  /// marca flag [_loginFailed] para recuperação tardia.
  static Future<void> login(String userId) async {
    _loginFailed = false;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await OneSignal.login(userId);
        log('[PUSH] OneSignal.login success: userId=$userId', name: 'push');
        return;
      } catch (e) {
        log(
          '[PUSH] OneSignal.login attempt $attempt failed: $e',
          name: 'push',
          level: 900,
        );
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1))); // 1s, 2s, 4s
        }
      }
    }
    _loginFailed = true;
    log('[PUSH] OneSignal.login failed after 3 attempts', name: 'push', level: 1000);
  }

  /// Tenta recuperar OneSignal.login se o primeiro fluxo falhou.
  /// Chamado no HomeScreen quando idle (sem viagem ativa).
  static Future<void> tryLateLogin(String userId) async {
    if (_loginFailed) {
      log('[PUSH] Attempting late OneSignal.login for userId=$userId', name: 'push');
      await login(userId);
    }
  }

  /// Desvincula o External ID do OneSignal. Chamado no logout.
  static Future<void> logout() async {
    try {
      await OneSignal.logout();
      log('[PUSH] OneSignal.logout success', name: 'push');
    } catch (e) {
      log('[PUSH] OneSignal.logout failed: $e', name: 'push', level: 1000);
    }
    _loginFailed = false;
  }

  // ── Register Device (RF03) ──

  /// Registra o device token no backend (auditoria).
  /// Não bloqueante — targeting é via external_user_ids.
  static Future<void> registerDevice({
    required Dio dio,
    required String playerId,
    required String platform,
  }) async {
    try {
      final response = await dio.post('/api/notifications/register-device', data: {
        'playerId': playerId,
        'platform': platform,
      });
      log('[PUSH] Device registered: $platform / $playerId (status=${response.statusCode})',
          name: 'push');
    } on DioException catch (e) {
      log('[PUSH] register-device failed (status=${e.response?.statusCode}, body=${e.response?.data}): $e',
          name: 'push', level: 900);
    } catch (e) {
      log('[PUSH] register-device unexpected error: $e', name: 'push', level: 900);
    }
  }

  // ── Permissão (RF06) ──

  /// Solicita permissão de notificação ao usuário.
  /// Retorna true se concedida.
  static Future<bool> requestPermission() async {
    try {
      final result = await OneSignal.Notifications.requestPermission(true);
      log('[PUSH] Permission request result: $result', name: 'push');
      return result;
    } catch (e) {
      log('[PUSH] requestPermission failed: $e', name: 'push', level: 900);
      return false;
    }
  }

  /// Verifica o status atual da permissão de notificação.
  static Future<bool> get permissionGranted async {
    try {
      return OneSignal.Notifications.permission;
    } catch (_) {
      return false;
    }
  }

  // ── Deep Link Holder (RF07 + RF08) ──

  /// Armazena um orderId pendente para processamento futuro.
  /// Sobrevive ao fluxo de login (campo estático).
  static void setPendingOrder(String orderId) {
    _pendingOrderId = orderId;
    log('[PUSH] Pending order set: $orderId', name: 'push');
  }

  /// Consome e retorna o orderId pendente, limpando o holder.
  static String? consumePendingOrder() {
    final id = _pendingOrderId;
    _pendingOrderId = null;
    return id;
  }

  /// Processa o deep link pendente, navegando para /home com pushOrderId.
  static void processPending() {
    final orderId = consumePendingOrder();
    if (orderId != null) {
      log('[PUSH] Processing pending deep link: $orderId', name: 'push');
      try {
        Modular.to.navigate('/home', arguments: {'pushOrderId': orderId});
      } catch (e) {
        log('[PUSH] processPending navigation failed: $e', name: 'push', level: 900);
      }
    }
  }

  // ── Sheet Visibility (RF05) ──

  /// Marca se o IncomingOrderSheet está visível.
  /// Usado para suprimir notificação foreground duplicada.
  static void setSheetVisible(bool visible) {
    _sheetVisible = visible;
  }

  // ── Listeners (RF04 + RF05) ──

  static void _registerListeners() {
    // Click handler (RF04) — warm start.
    // Cold start é tratado por captureInitialNotification() no main().
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null || data['type'] != 'NewOrder') return;

      final orderId = data['orderId'] as String?;
      if (orderId == null) return;

      log('[PUSH] Notification clicked (warm start): orderId=$orderId', name: 'push');

      // RF07: Cold start — Modular pode não estar pronto ainda
      // Armazenar para processPending no addPostFrameCallback
      setPendingOrder(orderId);

      // Warm start: tentar navegar imediatamente
      try {
        Modular.to.navigate('/home', arguments: {'pushOrderId': orderId});
      } catch (_) {
        // Modular ainda não pronto — será processado via processPending()
      }
    });

    // Foreground handler (RF05)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      if (data?['type'] == 'NewOrder' && _sheetVisible) {
        // Suprimir: pedido já está visível via SignalR
        log('[PUSH] Foreground notification suppressed: IncomingOrderSheet visible',
            name: 'push');
        return;
      }
      event.notification.display();
    });
  }
}
