import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/auth/terms_storage.dart';
import 'package:moto_driver/core/http/dio_client.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/notifications_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/maps/directions_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/core/notifications/inotification_service.dart';
import 'package:moto_driver/core/notifications/one_signal_notification_service.dart';
import 'package:moto_driver/modules/auth/data/datasources/auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/repositories/auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_driver/modules/driver_availability/data/datasources/availability_datasource.dart';
import 'package:moto_driver/modules/usage_terms/data/datasources/usage_terms_datasource.dart';

class CommonModule extends Module {
  @override
  void binds(i) {
    i.addSingleton<Dio>(DioClient.create);
    i.addSingleton<AuthStorage>(AuthStorage.new);
    i.addSingleton<AuthLocalRepository>(AuthLocalRepository.new);
    i.addSingleton<ProfileLocalRepository>(ProfileLocalRepository.new);
    i.addSingleton<TravelLocalRepository>(TravelLocalRepository.new);
    i.addSingleton<SignOutService>(SignOutService.new);
    i.addSingleton<SignalRService>(SignalRService.new);
    i.addSingleton<LocationService>(LocationService.new);
    i.addSingleton<DirectionsService>(DirectionsService.new);
    i.addSingleton<NotificationsLocalRepository>(NotificationsLocalRepository.new);
    i.addSingleton<INotificationService>(OneSignalNotificationService.new);
    i.add<IAuthDatasource>(AuthDatasource.new);
    i.add<IAuthRepository>(AuthRepository.new);
    i.addSingleton<TermsStorage>(TermsStorage.new);
    i.addSingleton<UsageTermsDatasource>(UsageTermsDatasource.new);
    i.addSingleton<AvailabilityDatasource>(AvailabilityDatasource.new);
  }
}
