import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/config/app_config.dart';

const _serviceId = 7305;
const _baseUrlKey = 'background_location_base_url';
const _driverIdKey = 'background_location_driver_id';
const _tokenKey = 'background_location_token';
const _travelStatusKey = 'background_location_travel_status';

/// Texto persistente exibido pelo serviço de localização no Android.
/// Mantido puro para que a regra possa ser validada sem depender do plugin.
String backgroundTravelNotificationText(
  String? status, {
  String? updatedAt,
}) {
  final suffix = updatedAt == null ? '' : ' • atualizado às $updatedAt';
  return switch (status) {
    'Accepted' => 'A caminho do local de embarque$suffix',
    'InProgress' => 'Viagem em andamento$suffix',
    _ => 'Compartilhando sua localização com segurança$suffix',
  };
}

@pragma('vm:entry-point')
void backgroundLocationStartCallback() {
  FlutterForegroundTask.setTaskHandler(BackgroundLocationTaskHandler());
}

/// Executa no isolate mantido pelo foreground service do Android.
///
/// O envio usa o endpoint HTTP de posições em vez do SignalR da interface.
/// Assim, a coleta não depende de uma tela, rota ou conexão do app principal.
class BackgroundLocationTaskHandler extends TaskHandler {
  bool _sending = false;
  Position? _lastPosition;
  DateTime? _lastSentAt;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _sendPosition(force: true);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_sendPosition());
  }

  Future<void> _sendPosition({bool force = false}) async {
    if (_sending) return;
    _sending = true;

    try {
      final baseUrl = await FlutterForegroundTask.getData<String>(
        key: _baseUrlKey,
      );
      final driverId = await FlutterForegroundTask.getData<String>(
        key: _driverIdKey,
      );
      final token = await FlutterForegroundTask.getData<String>(key: _tokenKey);
      if (baseUrl == null || driverId == null || token == null) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );

      final previous = _lastPosition;
      final lastSentAt = _lastSentAt;
      final heartbeatDue =
          lastSentAt == null ||
          DateTime.now().difference(lastSentAt) >= const Duration(seconds: 5);
      final movedEnough =
          previous == null ||
          Geolocator.distanceBetween(
                previous.latitude,
                previous.longitude,
                position.latitude,
                position.longitude,
              ) >=
              3;

      if (!force && !heartbeatDue && !movedEnough) return;

      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      await dio.post(
        '/api/positions/drivers/$driverId',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );

      _lastPosition = position;
      _lastSentAt = DateTime.now();
      final time = _lastSentAt!;
      final formattedTime =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
      final travelStatus = await FlutterForegroundTask.getData<String>(
        key: _travelStatusKey,
      );
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Motô em atendimento',
        notificationText: backgroundTravelNotificationText(
          travelStatus,
          updatedAt: formattedTime,
        ),
      );
      FlutterForegroundTask.sendDataToMain({
        'type': 'location_sent',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': _lastSentAt!.toIso8601String(),
      });
    } catch (error) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'location_error',
        'message': error.toString(),
      });
    } finally {
      _sending = false;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/home');
  }

  @override
  void onNotificationDismissed() {}
}

enum BackgroundLocationPermissionStatus {
  granted,
  locationDenied,
  locationDeniedForever,
  backgroundLocationRequired,
  notificationsDenied,
  serviceDisabled,
  unsupported,
}

class BackgroundLocationService {
  final AuthStorage _authStorage;

  BackgroundLocationService(this._authStorage);

  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'moto_driver_location',
        channelName: 'Localização durante o atendimento',
        channelDescription:
            'Mantém a localização do motorista atualizada enquanto ele está em atendimento.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
      ),
    );
  }

  Future<BackgroundLocationPermissionStatus> requestPermissions() async {
    if (!Platform.isAndroid) {
      return BackgroundLocationPermissionStatus.unsupported;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return BackgroundLocationPermissionStatus.serviceDisabled;
    }

    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }
    if (locationPermission == LocationPermission.denied) {
      return BackgroundLocationPermissionStatus.locationDenied;
    }
    if (locationPermission == LocationPermission.deniedForever) {
      return BackgroundLocationPermissionStatus.locationDeniedForever;
    }

    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      final requested =
          await FlutterForegroundTask.requestNotificationPermission();
      if (requested != NotificationPermission.granted) {
        return BackgroundLocationPermissionStatus.notificationsDenied;
      }
    }

    // Android 11+ não exibe "Permitir o tempo todo" no diálogo comum.
    // O app deve explicar a necessidade e direcionar às configurações antes
    // de iniciar uma sessão que precise sobreviver fora da interface.
    if (locationPermission != LocationPermission.always) {
      return BackgroundLocationPermissionStatus.backgroundLocationRequired;
    }
    return BackgroundLocationPermissionStatus.granted;
  }

  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    final token = await _authStorage.getToken();
    final driverId = await _authStorage.getUserId();
    if (token == null || driverId == null) return false;

    await Future.wait([
      FlutterForegroundTask.saveData(
        key: _baseUrlKey,
        value: AppConfig.getBaseUrl(),
      ),
      FlutterForegroundTask.saveData(key: _driverIdKey, value: driverId),
      FlutterForegroundTask.saveData(key: _tokenKey, value: token),
    ]);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Motô em atendimento',
        notificationText: 'Compartilhando sua localização com segurança',
      );
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Motô em atendimento',
      notificationText: 'Compartilhando sua localização com segurança',
      notificationInitialRoute: '/home',
      callback: backgroundLocationStartCallback,
    );
    if (kDebugMode) debugPrint('Background location start: $result');
    return result is ServiceRequestSuccess;
  }

  /// Atualiza imediatamente a notificação fixa e persiste o estado para o
  /// isolate de localização (inclusive após o app sair do primeiro plano).
  Future<void> setTravelStatus(String? status) async {
    if (!Platform.isAndroid) return;
    if (status == null || status == 'Completed' || status == 'Cancelled') {
      await FlutterForegroundTask.removeData(key: _travelStatusKey);
      status = null;
    } else {
      await FlutterForegroundTask.saveData(
        key: _travelStatusKey,
        value: status,
      );
    }

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Motô em atendimento',
        notificationText: backgroundTravelNotificationText(status),
      );
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    await Future.wait([
      FlutterForegroundTask.removeData(key: _driverIdKey),
      FlutterForegroundTask.removeData(key: _tokenKey),
      FlutterForegroundTask.removeData(key: _travelStatusKey),
    ]);
  }

  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}
