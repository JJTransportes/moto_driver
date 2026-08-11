import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/app/app_module.dart';
import 'package:moto_driver/app/app_widget.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/local_database_service.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await AppConfig.loadEnv();

  // RF01: Inicializar OneSignal antes de runApp
  final appId = AppConfig.getOneSignalAppId();
  if (appId.isNotEmpty) {
    await NotificationService.init(appId: appId);
  }

  await LocalDatabaseService.init();

  await LocationService.requestPermissionIfNeeded();

  runApp(
    ModularApp(
      module: AppModule(),
      child: const AppWidget(),
    ),
  );

  // RF07: Processar deep link pendente após primeiro frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.processPending();
  });
}
