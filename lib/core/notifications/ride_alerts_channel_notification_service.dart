import 'dart:async';
import 'dart:developer' as developer;

import 'package:moto_driver/core/notifications/inotification_service.dart';
import 'package:moto_driver/core/notifications/notification_channel_service.dart';

/// Decorador do serviço de notificações do motorista: garante o canal dos avisos de corrida
/// (com o som do Moto) ANTES de o OneSignal inicializar (spec push-notification-sounds, req 2.1).
///
/// O canal precisa existir antes da primeira notificação que o usa. Como a inicialização do
/// OneSignal acontece uma vez no início do app (BootstrapBloc), este é o ponto natural, e o
/// BootstrapBloc não precisa mudar. Criar o canal nunca atrapalha a inicialização: falha ou demora
/// só são registradas, e o app segue recebendo pelo canal padrão. Todo o resto é delegado.
class RideAlertsChannelNotificationService implements INotificationService {
  final INotificationService _inner;
  final INotificationChannelService _channels;
  final Duration _channelTimeout;

  RideAlertsChannelNotificationService(
    this._inner,
    this._channels, {
    Duration channelTimeout = const Duration(seconds: 3),
  }) : _channelTimeout = channelTimeout;

  @override
  Future<void> initialize(String appId) async {
    try {
      await _channels.ensureRideAlertsChannel().timeout(_channelTimeout);
    } catch (e) {
      developer.log(
        '[PUSH] Notification channel failed (${e.runtimeType}).',
        name: 'push',
        level: 900,
      );
    }

    await _inner.initialize(appId);
  }

  @override
  Future<bool> requestNotificationPermission() => _inner.requestNotificationPermission();

  @override
  Future<void> login(String subscription, token) => _inner.login(subscription, token);

  @override
  Future<void> handleForegroundNotification() => _inner.handleForegroundNotification();

  @override
  Future<void> dismissNewOrder(String orderId) => _inner.dismissNewOrder(orderId);
}
