import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/theme/app_theme.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> with WidgetsBindingObserver {
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

    Future.delayed(const Duration(seconds: 2), () async {
      await _updateDeviceStatus(isActive);
    });
  }

  @override
  void dispose() {
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
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      routerConfig: Modular.routerConfig,
    );
  }
}
