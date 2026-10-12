import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

typedef UpdateCheck = Future<bool> Function();

class MandatoryUpdateGate extends StatefulWidget {
  const MandatoryUpdateGate({
    super.key,
    required this.child,
    this.updateCheck,
    this.enabled,
  });

  final Widget child;
  final UpdateCheck? updateCheck;
  final bool? enabled;

  @override
  State<MandatoryUpdateGate> createState() => _MandatoryUpdateGateState();
}

class _MandatoryUpdateGateState extends State<MandatoryUpdateGate> {
  static const _productionUpdateEnabled = bool.fromEnvironment(
    'FORCE_PLAY_UPDATE',
  );

  bool _checking = true;
  bool _updateRequired = false;

  bool get _enabled =>
      widget.enabled ??
      (kReleaseMode &&
          _productionUpdateEnabled &&
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (!_enabled) {
      _releaseApp();
      return;
    }

    if (mounted) setState(() => _checking = true);

    try {
      final updateRequired = await (widget.updateCheck ?? _googlePlayCheck)();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _updateRequired = updateRequired;
      });
    } catch (_) {
      // A failure to reach Google Play must not lock users out of the app.
      _releaseApp();
    }
  }

  Future<bool> _googlePlayCheck() async {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }

    if (!info.immediateUpdateAllowed) return true;

    final result = await InAppUpdate.performImmediateUpdate();
    return result != AppUpdateResult.success;
  }

  void _releaseApp() {
    if (!mounted) return;
    setState(() {
      _checking = false;
      _updateRequired = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checking && !_updateRequired) return widget.child;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _checking
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.system_update, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        'Atualização obrigatória',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Atualize o aplicativo para continuar usando o Motô.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _checkForUpdate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Atualizar agora'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
