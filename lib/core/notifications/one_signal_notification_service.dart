import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_modular/flutter_modular.dart';
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

  @override
  Future<void> handleForegroundNotification() async {
    OneSignal.Notifications.addClickListener((event) async {
      log(jsonEncode(event.notification.body));
      await handleNotificationClick(event.notification.additionalData);
    });
  }

  @visibleForTesting
  Future<void> handleNotificationClick(Map<String, dynamic>? data) async {
    if (data == null || data['type'] != 'NewOrder') return;

    final orderId = data['order_id'] as String? ?? data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return;

    log('[PUSH] Notification clicked: orderId=$orderId', name: 'push');

    if (NotificationService.orderAlertOpen) {
      NotificationService.setPendingOrder(orderId);
      return;
    }

    NotificationService.setPendingOrder(orderId);

    Modular.to.pushNamed('/order-refresh', arguments: {'orderId': orderId});
  }
}
