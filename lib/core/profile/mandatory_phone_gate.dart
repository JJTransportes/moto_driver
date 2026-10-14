import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';

/// Bloqueia contas autenticadas sem telefone até que o dado seja cadastrado.
class MandatoryPhoneGate extends StatefulWidget {
  const MandatoryPhoneGate({super.key, required this.child});

  final Widget child;

  @override
  State<MandatoryPhoneGate> createState() => _MandatoryPhoneGateState();
}

class _MandatoryPhoneGateState extends State<MandatoryPhoneGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _editingPhone = false;
  bool _phoneMissing = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Modular.to.addListener(_onRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleCheck(Duration.zero),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCheck(const Duration(milliseconds: 300));
    }
  }

  void _onRouteChanged() {
    _scheduleCheck(const Duration(milliseconds: 600));
  }

  void _scheduleCheck(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _checkPhone);
  }

  Future<void> _checkPhone() async {
    if (!mounted || _checking || _editingPhone) return;
    if (Modular.to.path.startsWith('/profile-configuration')) return;

    _checking = true;
    try {
      final auth = Modular.get<AuthStorage>();
      final token = await auth.getToken();
      final userId = await auth.getUserId();
      if (!mounted) return;
      if (token == null || userId == null) {
        if (_phoneMissing) setState(() => _phoneMissing = false);
        _scheduleCheck(const Duration(seconds: 1));
        return;
      }

      final response = await Modular.get<Dio>().get('/api/drivers/me');
      final data = response.data;
      final phone = data is Map ? data['phone']?.toString().trim() : null;
      if (!mounted) return;
      setState(() => _phoneMissing = phone == null || phone.isEmpty);
    } on DioException {
      // A trava de conectividade é responsável por falhas de rede. Não
      // mostramos um falso aviso de telefone sem confirmação do backend.
      _scheduleCheck(const Duration(seconds: 2));
    } finally {
      _checking = false;
    }
  }

  Future<void> _openPhoneEditor() async {
    final userId = await Modular.get<AuthStorage>().getUserId();
    if (!mounted || userId == null) return;
    setState(() => _editingPhone = true);
    try {
      await Modular.to.pushNamed(
        '/profile-configuration',
        arguments: {'userId': userId, 'requirePhone': true},
      );
    } finally {
      if (mounted) {
        setState(() => _editingPhone = false);
        _scheduleCheck(Duration.zero);
      }
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    Modular.to.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_phoneMissing && !_editingPhone)
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
                    const Icon(
                      Icons.phone_outlined,
                      size: 64,
                      color: Color(0xFF246BFD),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Telefone obrigatório',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cadastre um número de telefone válido para continuar utilizando o aplicativo e receber contatos relacionados às suas viagens.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _openPhoneEditor,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Cadastrar telefone'),
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
