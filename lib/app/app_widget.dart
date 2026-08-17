import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/local_database_service.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/notifications/inotification_service.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  @override
  void initState() {
    super.initState();

    final notificationsService = Modular.get<INotificationService>();

    Future.microtask(() async {
      await LocalDatabaseService.init();

      await LocationService.requestPermissionIfNeeded();
      final appId = AppConfig.getOneSignalAppId();
      await notificationsService.initialize(appId);
      await notificationsService.requestNotificationPermission();
    });
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
