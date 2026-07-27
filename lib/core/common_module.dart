import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/http/dio_client.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/maps/directions_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/modules/auth/data/datasources/auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_driver/modules/auth/data/repositories/auth_repository.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';

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
    i.add<IAuthDatasource>(AuthDatasource.new);
    i.add<IAuthRepository>(AuthRepository.new);
  }
}
