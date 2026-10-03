import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Canal de notificação dos avisos de corrida (spec push-notification-sounds).
///
/// No Android, o som de uma notificação é do CANAL (não da mensagem), e o Android trava o som
/// de um canal depois da primeira notificação que o usa. Por isso o id é versionado: trocar o
/// som exige um id novo (`moto_ride_alerts_v2`...), publicar os apps e só então atualizar a
/// configuração do backend (`OneSignal__Sound__AndroidChannelId`). O id é o mesmo nos dois apps e
/// no backend — o backend envia o ID, nunca o nome visível.
class RideAlertsChannel {
  RideAlertsChannel._();

  static const String id = 'moto_ride_alerts_v1';

  /// Nome visível ao usuário nas configurações do sistema.
  static const String name = 'Avisos de corrida';
  static const String description = 'Avisos de viagem com o som do Moto';

  /// Arquivo em `res/raw`, minúsculo e sem extensão.
  static const String soundResource = 'moto_notification';
}

abstract class INotificationChannelService {
  /// Cria (ou confirma) o canal dos avisos de corrida no Android, com o som do Moto.
  /// No iOS e em plataformas sem canais não faz nada. Nunca lança: uma falha só é registrada e
  /// o app segue, recebendo as notificações pelo canal padrão.
  Future<void> ensureRideAlertsChannel();
}

class NotificationChannelService implements INotificationChannelService {
  static const MethodChannel _channel = MethodChannel('moto/notification_channel');

  final bool Function() _isAndroid;
  final void Function(String message) _log;

  NotificationChannelService({
    bool Function()? isAndroid,
    void Function(String message)? log,
  })  : _isAndroid = isAndroid ?? (() => !kIsWeb && Platform.isAndroid),
        _log = log ?? ((message) => developer.log(message, name: 'push', level: 900));

  @override
  Future<void> ensureRideAlertsChannel() async {
    if (!_isAndroid()) return;

    try {
      await _channel.invokeMethod<bool>('ensureChannel', {
        'id': RideAlertsChannel.id,
        'name': RideAlertsChannel.name,
        'description': RideAlertsChannel.description,
        'sound': RideAlertsChannel.soundResource,
      });
    } catch (e) {
      // Só o tipo do erro: o texto da exceção não precisa ir para o log.
      _log('[PUSH] Notification channel setup failed (${e.runtimeType}).');
    }
  }
}
