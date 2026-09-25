import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/screens/active_travel_page.dart';

export 'push_test_utils.dart'
    show
        MockDio,
        MockAuthStorage,
        MockSignalRService,
        MockTravelLocalRepository,
        MockLocationService,
        MockModularNavigator,
        FakeGoogleMapsPlatform,
        StubPage,
        okResponse;

import 'push_test_utils.dart' as push
    show MockDio, MockAuthStorage, MockSignalRService, MockTravelLocalRepository, MockLocationService, StubPage;

// F10: módulo de teste dedicado a ActiveTravelPage.
class ActiveTravelTestModule extends Module {
  final push.MockDio dio;
  final push.MockAuthStorage authStorage;
  final push.MockSignalRService signalRService;
  final push.MockTravelLocalRepository travelLocalRepository;
  final push.MockLocationService locationService;

  ActiveTravelTestModule({
    required this.dio,
    required this.authStorage,
    required this.signalRService,
    required this.travelLocalRepository,
    required this.locationService,
  });

  @override
  void binds(Injector i) {
    i.addInstance<Dio>(dio);
    i.addInstance<AuthStorage>(authStorage);
    i.addInstance<SignalRService>(signalRService);
    i.addInstance<TravelLocalRepository>(travelLocalRepository);
    i.addInstance<LocationService>(locationService);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => ActiveTravelPage(travelId: Modular.args.data['travelId'] as String? ?? 'travel-1'),
    );
    r.child('/home', child: (_) => const push.StubPage(label: 'Home'));
  }
}

void initTestModule(Module module, dynamic navigator) {
  Modular.init(module);
  Modular.navigatorDelegate = navigator;
}

void destroyTestModule() {
  Modular.navigatorDelegate = null;
  try {
    Modular.destroy();
  } catch (_) {}
}

/// Payload compatível com GET /api/travels/{travelId}.
Map<String, dynamic> travelPayload({
  String status = 'Accepted',
  String? passengerId = 'passenger-1',
  String? passengerName = 'Maria Passageira',
  List<Map<String, dynamic>>? routes,
}) =>
    {
      'status': status,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'createdAt': '2026-01-01T10:00:00Z',
      'routes': routes ??
          [
            {
              'destinationLatitude': -23.55,
              'destinationLongitude': -46.63,
              'destinationAddress': 'Av. Paulista, 1000',
              'encodedPolyline': null,
              'distanceMeters': 1200,
              'timeMinutes': 8,
            },
            {
              'destinationLatitude': -23.60,
              'destinationLongitude': -46.65,
              'destinationAddress': 'Av. Faria Lima, 2000',
              'encodedPolyline': null,
              'distanceMeters': 5000,
              'timeMinutes': 20,
            },
          ],
    };

/// Payload compatível com GET /api/passengers/{id}.
Map<String, dynamic> passengerProfilePayload({
  String? photoUrl,
  int solicitationCount = 3,
  String? publicPartitionName = 'Prefeitura X',
  List<String>? departments,
}) =>
    {
      'photoUrl': photoUrl,
      'solicitationCount': solicitationCount,
      'publicPartitionName': publicPartitionName,
      'departments': (departments ?? const ['RH']).map((d) => {'name': d}).toList(),
    };
