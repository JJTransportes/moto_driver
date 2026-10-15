import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_driver/core/location/background_location_service.dart';

/// Bloqueia o uso do app (Android e iOS) enquanto os requisitos para
/// rastreamento contínuo do motorista não estiverem habilitados: localização
/// em "Sempre" (e, no Android, as notificações do serviço em primeiro plano).
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
  bool _disclosureAccepted = false;
  bool _disclosureDeclined = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Primeiro apenas consulta o estado. A permissão do Android só pode ser
    // solicitada depois que o motorista visualizar e aceitar o aviso.
    _check();
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

  /// O bloqueio vale no Android e no iOS. `isAndroid` existe só para os testes
  /// forçarem a plataforma.
  bool get _enforced =>
      widget.isAndroid ?? (Platform.isAndroid || Platform.isIOS);

  bool get _isIOS => !(widget.isAndroid ?? false) && Platform.isIOS;

  Future<void> _check({bool request = false}) async {
    if (!_enforced) {
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
      } else if (_isIOS) {
        // No iOS não há serviço em primeiro plano com notificação própria.
        status = BackgroundLocationPermissionStatus.granted;
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

  Future<void> _acceptDisclosure() async {
    setState(() {
      _disclosureAccepted = true;
      _disclosureDeclined = false;
    });
    await _check(request: true);
  }

  @override
  Widget build(BuildContext context) {
    final blocked =
        _enforced &&
        (_checking || _status != BackgroundLocationPermissionStatus.granted);

    final gpsDisabled =
        _status == BackgroundLocationPermissionStatus.serviceDisabled;
    final showDisclosure =
        blocked &&
        !gpsDisabled &&
        !_checking &&
        !_disclosureAccepted &&
        !_disclosureDeclined;
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
                    child: SingleChildScrollView(
                      child: _checking
                          ? const CircularProgressIndicator()
                          : showDisclosure
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 72,
                                  color: Color(0xFF246BFD),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Uso da localização',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'O Motô coleta sua localização para permitir atendimentos e o monitoramento da frota no painel, inclusive quando o aplicativo está fechado ou não está em uso.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'A localização é utilizada durante sua operação como motorista e pode ser alterada nas configurações do aparelho.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 28),
                                FilledButton(
                                  onPressed: _acceptDisclosure,
                                  child: const Text('Continuar'),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => setState(
                                    () => _disclosureDeclined = true,
                                  ),
                                  child: const Text('Agora não'),
                                ),
                              ],
                            )
                          : _disclosureDeclined
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_off_rounded,
                                  size: 72,
                                  color: Color(0xFF246BFD),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Localização necessária',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Sem essa autorização não é possível trabalhar com o Motô nem manter o veículo visível no monitoramento da frota.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 28),
                                FilledButton(
                                  onPressed: () => setState(
                                    () => _disclosureDeclined = false,
                                  ),
                                  child: const Text('Rever autorização'),
                                ),
                              ],
                            )
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
                                      : _isIOS
                                      ? 'Para ficar disponível e realizar atendimentos, abra as configurações, toque em Localização e escolha "Sempre".'
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
          ),
      ],
    );
  }
}
