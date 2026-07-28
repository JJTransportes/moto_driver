import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  static bool _initialized = false;

  /// Inicializa o SDK do OneSignal.
  ///
  /// Deve ser chamado uma única vez durante o bootstrap do app,
  /// após [dotenv.load] e [AppConfig.loadEnv].
  static Future<void> initialize({required String appId}) async {
    if (_initialized) {
      debugPrint('OneSignal: já inicializado.');
      return;
    }

    if (appId.isEmpty) {
      debugPrint('OneSignal: ONE_SIGNAL_ID vazio — inicialização ignorada.');
      return;
    }

    try {
      OneSignal.initialize(appId);
      _initialized = true;
      debugPrint('OneSignal: inicializado com sucesso (appId: ${appId.substring(0, 8)}...).');

      _registerListeners();
    } catch (e) {
      debugPrint('OneSignal: erro ao inicializar — $e');
    }
  }

  /// Vincula o [userId] como External ID no OneSignal.
  ///
  /// Chamar após login bem-sucedido.
  static Future<void> login(String userId) async {
    if (!_initialized) return;

    try {
      await OneSignal.login(userId);
      debugPrint('OneSignal: login externo vinculado — userId: $userId');
    } catch (e) {
      debugPrint('OneSignal: erro ao fazer login — $e');
    }
  }

  /// Desvincula o External ID atual.
  ///
  /// Chamar durante o logout.
  static Future<void> logout() async {
    if (!_initialized) return;

    try {
      await OneSignal.logout();
      debugPrint('OneSignal: logout efetuado.');
    } catch (e) {
      debugPrint('OneSignal: erro ao fazer logout — $e');
    }
  }

  /// Solicita permissão de notificação ao usuário.
  static Future<void> requestPermission() async {
    if (!_initialized) return;

    try {
      await OneSignal.Notifications.requestPermission(true);
      debugPrint('OneSignal: permissão solicitada.');
    } catch (e) {
      debugPrint('OneSignal: erro ao solicitar permissão — $e');
    }
  }

  /// Registra listeners de eventos do SDK.
  static void _registerListeners() {
    // Click em notificação
    OneSignal.Notifications.addClickListener(_onNotificationClick);

    // Notificação recebida com app em foreground
    OneSignal.Notifications.addForegroundWillDisplayListener(_onForegroundWillDisplay);
  }

  /// Handler de clique em notificação.
  ///
  /// Extrai [travelId] dos dados adicionais para deep link
  /// para a tela de corrida ativa.
  static void _onNotificationClick(OSNotificationClickEvent event) {
    debugPrint('OneSignal: notificação clicada — notificationId: ${event.notification.notificationId}');

    final additionalData = event.notification.additionalData;
    if (additionalData == null) return;

    final travelId = additionalData['travelId'] as String?;
    if (travelId != null && travelId.isNotEmpty) {
      debugPrint('OneSignal: deep link para /active-travel — travelId: $travelId');
      try {
        Modular.to.navigate('/active-travel', arguments: {'travelId': travelId});
      } catch (e) {
        debugPrint('OneSignal: erro ao navegar para /active-travel — $e');
      }
    }
  }

  /// Handler de notificação recebida com app em primeiro plano.
  ///
  /// Exibe a notificação como notificação normal do sistema.
  static void _onForegroundWillDisplay(OSNotificationWillDisplayEvent event) {
    debugPrint('OneSignal: notificação em foreground — notificationId: ${event.notification.notificationId}');
    event.notification.display();
  }
}
