import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/local_db/repositories/notifications_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
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

  @override
  Future<void> initialize(String appId) async {
    try {
      if (_initialized) {
        return;
      }

      await OneSignal.initialize(appId);

      OneSignal.User.addObserver(
        (state) async {
          final playerId = state.current.onesignalId;
          if (playerId == null) throw Exception('Player id not found.');

          await _notificationsLocalRepository.savePlayerId(playerId);
        },
      );

      await handleForegroundNotification();

      _initialized = true;
    } catch (e) {
      throw Exception('Notification service initialization failed.');
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    return await OneSignal.Notifications.requestPermission(false);
  }

  @override
  Future<void> login(String subscription, token) async {
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
      log('[PUSH] Device registered: $platform / $playerId (status=${response.statusCode})', name: 'push');
    } on DioException catch (e) {
      log('[PUSH] register-device failed: $e', name: 'push', level: 900);
    }
  }

  /// Trata o toque do motorista numa notificação push de novo pedido.
  ///
  /// Fluxo (RF05/DA04):
  /// - `type == 'NewOrder'` → extrai `order_id` (snake_case do backend) com
  ///   fallback para `orderId`;
  /// - registra o pedido pendente (rede de segurança p/ cliques antes do
  ///   runApp) e navega via push para `/order-refresh` (que renova o token e
  ///   abre `/order-alert` com o `orderId` como parâmetro de rota);
  /// - guardas: página de pedido já aberta (só atualiza o pendente —
  ///   reexibição pós-saída), fluxo de sessão em andamento (guarda de termos
  ///   abre o fluxo no fim), sem sessão (aguarda login) e viagem ativa
  ///   (ignora o clique por completo).
  @override
  Future<void> handleForegroundNotification() async {
    OneSignal.Notifications.addClickListener((event) async {
      log(jsonEncode(event.notification.body));
      await handleNotificationClick(event.notification.additionalData);
    });
  }

  /// Lógica de decisão do toque na notificação — separada do registro do
  /// listener do SDK para permitir teste unitário da tomada de decisão.
  @visibleForTesting
  Future<void> handleNotificationClick(Map<String, dynamic>? data) async {
    if (data == null || data['type'] != 'NewOrder') return;

    // Payload do backend: data = { type: 'NewOrder', order_id } (snake_case).
    final orderId = data['order_id'] as String? ?? data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return;

    log('[PUSH] Notification clicked: orderId=$orderId', name: 'push');

    // Página de pedido já aberta — apenas atualiza o pendente
    // (reexibição pós-saída, RF11).
    if (NotificationService.orderAlertOpen) {
      NotificationService.setPendingOrder(orderId);
      return;
    }

    // Rede de segurança: pendente registrado ANTES de qualquer navegação
    // (cliques antes do runApp lançam no try/catch e sobrevivem no holder).
    NotificationService.setPendingOrder(orderId);

    try {
      final path = Modular.to.path;

      // Fluxo de sessão em andamento — a guarda de termos abre o fluxo no
      // fim (evita corrida de duplo refresh de token com o splash).
      if (path == '/' || path == '/terms' || path == '/order-refresh') return;

      // Sem sessão — o pendente aguarda o próximo login (guarda de termos).
      final authStorage = Modular.get<AuthStorage>();
      final refreshToken = await authStorage.getRefreshToken();
      if (refreshToken == null) return;

      // Viagem ativa: pedido não pode interromper a viagem — ignora.
      final travelRepo = Modular.get<TravelLocalRepository>();
      final activeTravel = await travelRepo.getActiveTravel();
      if (activeTravel != null) {
        NotificationService.clearPendingOrder();
        log('[PUSH] Click ignored — driver has active travel', name: 'push');
        return;
      }

      await Modular.to.pushNamed('/order-refresh', arguments: {'orderId': orderId});
    } catch (e) {
      log('[PUSH] Navigate skipped (cold start / Modular not ready): $e', name: 'push');
    }
  }
}
