import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

/// Impede operações enquanto o aparelho não consegue alcançar o servidor.
/// O conteúdo permanece montado para preservar Navigator, viagem e formulários.
class MandatoryConnectivityGate extends StatefulWidget {
  const MandatoryConnectivityGate({
    super.key,
    required this.child,
    this.connectionCheck,
    this.hasActiveTravel,
    this.checkInterval = const Duration(seconds: 5),
  });

  final Widget child;
  final Future<bool> Function()? connectionCheck;
  final bool Function()? hasActiveTravel;
  final Duration checkInterval;

  @override
  State<MandatoryConnectivityGate> createState() =>
      _MandatoryConnectivityGateState();
}

class _MandatoryConnectivityGateState extends State<MandatoryConnectivityGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _online = true;
  bool _initialCheck = true;
  bool _retrying = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check(showProgress: true);
    _timer = Timer.periodic(widget.checkInterval, (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<bool> _defaultCheck() async {
    try {
      final response = await Modular.get<Dio>()
          .get<String>(
            '/health',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(seconds: 5));
      final status = response.statusCode ?? 0;
      return status >= 200 && status < 400;
    } catch (_) {
      return false;
    }
  }

  Future<void> _check({bool showProgress = false}) async {
    if (_checking) return;
    _checking = true;
    if (showProgress && mounted) setState(() => _retrying = true);

    var online = false;
    try {
      online = await (widget.connectionCheck?.call() ?? _defaultCheck());
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    setState(() {
      _online = online;
      _initialCheck = false;
      _retrying = false;
    });
    _checking = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTravel = widget.hasActiveTravel?.call() ?? _isTravelRoute();
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_initialCheck || !_online)
          Material(
            color: Colors.black54,
            child: Center(
              child: PopScope(
                canPop: false,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _initialCheck
                            ? Icons.sync_rounded
                            : Icons.wifi_off_rounded,
                        size: 64,
                        color: Color(0xFF246BFD),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _initialCheck
                            ? 'Verificando conexão'
                            : activeTravel
                            ? 'Conexão interrompida'
                            : 'Conexão indisponível',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _initialCheck
                            ? 'Aguarde enquanto verificamos o acesso ao serviço.'
                            : activeTravel
                            ? 'Estamos tentando reconectar. Não feche o aplicativo. Sua viagem continua ativa.'
                            : 'Não foi possível conectar ao serviço. Verifique o Wi-Fi ou os dados móveis e tente novamente.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_initialCheck || _retrying)
                        const CircularProgressIndicator()
                      else
                        FilledButton.icon(
                          onPressed: () => _check(showProgress: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tentar reconectar'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isTravelRoute() {
    try {
      return Modular.to.path.startsWith('/active-travel');
    } catch (_) {
      return false;
    }
  }
}
