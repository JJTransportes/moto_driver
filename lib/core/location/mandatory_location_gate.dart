import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_driver/core/location/background_location_service.dart';

/// Bloqueia o uso do app Android enquanto os requisitos para rastreamento
/// contínuo do motorista não estiverem habilitados.
class MandatoryLocationGate extends StatefulWidget {
  final Widget child;
  final Future<BackgroundLocationPermissionStatus> Function(bool request)?
  permissionCheck;
  final bool? isAndroid;

  const MandatoryLocationGate({
    super.key,
    required this.child,
    this.permissionCheck,
    this.isAndroid,
  });

  @override
  State<MandatoryLocationGate> createState() => _MandatoryLocationGateState();
}

class _MandatoryLocationGateState extends State<MandatoryLocationGate>
    with WidgetsBindingObserver {
  BackgroundLocationPermissionStatus? _status;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check(request: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool request = false}) async {
    if (!(widget.isAndroid ?? Platform.isAndroid)) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    if (mounted) setState(() => _checking = true);
    BackgroundLocationPermissionStatus status;
    if (widget.permissionCheck case final checker?) {
      status = await checker(request);
    } else if (!await Geolocator.isLocationServiceEnabled()) {
      status = BackgroundLocationPermissionStatus.serviceDisabled;
    } else {
      var location = await Geolocator.checkPermission();
      if (request && location == LocationPermission.denied) {
        location = await Geolocator.requestPermission();
      }
      if (location == LocationPermission.deniedForever) {
        status = BackgroundLocationPermissionStatus.locationDeniedForever;
      } else if (location == LocationPermission.denied) {
        status = BackgroundLocationPermissionStatus.locationDenied;
      } else if (location != LocationPermission.always) {
        status = BackgroundLocationPermissionStatus.backgroundLocationRequired;
      } else {
        var notification =
            await FlutterForegroundTask.checkNotificationPermission();
        if (request && notification != NotificationPermission.granted) {
          notification =
              await FlutterForegroundTask.requestNotificationPermission();
        }
        status = notification == NotificationPermission.granted
            ? BackgroundLocationPermissionStatus.granted
            : BackgroundLocationPermissionStatus.notificationsDenied;
      }
    }

    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  Future<void> _openRequiredSetting() async {
    if (_status == BackgroundLocationPermissionStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked =
        (widget.isAndroid ?? Platform.isAndroid) &&
        (_checking || _status != BackgroundLocationPermissionStatus.granted);

    final gpsDisabled =
        _status == BackgroundLocationPermissionStatus.serviceDisabled;
    // Mantém o Navigator montado durante a rechecagem no resume. Push e
    // restauração de viagem podem navegar nesse mesmo frame; retirar o child
    // daqui fazia o Flutter desativar o mesmo elemento duas vezes.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (blocked)
          Material(
            color: const Color(0xFFF6F8FC),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: _checking
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 72,
                                color: Color(0xFF246BFD),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                gpsDisabled
                                    ? 'Ative a localização'
                                    : 'Localização obrigatória',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                gpsDisabled
                                    ? 'O GPS precisa permanecer ligado para trabalhar com o Motô.'
                                    : 'Para ficar disponível e realizar atendimentos, permita a localização o tempo todo e as notificações.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 28),
                              FilledButton.icon(
                                onPressed: _openRequiredSetting,
                                icon: const Icon(Icons.settings),
                                label: const Text('Abrir configurações'),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => _check(request: true),
                                child: const Text('Verificar novamente'),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
