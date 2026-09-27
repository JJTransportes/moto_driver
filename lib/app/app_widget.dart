import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/design_system/design_system.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> with WidgetsBindingObserver {
  // F17: `Future.delayed` solto aqui não era cancelável nem checava
  // `mounted` — se o widget desmontasse dentro da janela de 2s (ou uma
  // mudança de lifecycle seguinte disparasse outro delay antes do primeiro
  // terminar), o callback rodava do mesmo jeito, arriscando usar um
  // `Modular.get` de escopo já descartado.
  Timer? _deviceStatusTimer;

  @override
  void initState() {
    super.initState();

    Modular.to.addListener(_logRoutes);

    WidgetsBinding.instance.addObserver(this);

    _updateDeviceStatus(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bool isActive = switch (state) {
      AppLifecycleState.resumed => true,
      _ => false,
    };

    _deviceStatusTimer?.cancel();
    _deviceStatusTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      await _updateDeviceStatus(isActive);
    });
  }

  @override
  void dispose() {
    _deviceStatusTimer?.cancel();
    Modular.to.removeListener(_logRoutes);

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  _logRoutes() => log('NAVIGATING TO ${Modular.to.path}');

  Future<void> _updateDeviceStatus(bool isActive) async {
    try {
      log('Updating device status.');

      final dio = Modular.get<Dio>();
      final authStorage = Modular.get<AuthStorage>();

      final userId = await authStorage.getUserId();

      await dio.post('/api/device-status/$userId/$isActive');
    } on DioException catch (e) {
      log('Device status updating failure. ${e.message ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App Motorista',
      theme: MotoTheme.claro(),
      debugShowCheckedModeBanner: false,
      routerConfig: Modular.routerConfig,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
