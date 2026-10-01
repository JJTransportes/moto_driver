import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/modules/driver_availability/data/datasources/availability_datasource.dart';
import 'package:moto_driver/screens/home_screen.dart';

export 'push_test_utils.dart'
    show
        MockDio,
        MockAuthStorage,
        MockSignOutService,
        MockSignalRService,
        MockTravelLocalRepository,
        MockLocationService,
        MockModularNavigator,
        FakeGoogleMapsPlatform,
        StubPage;

import 'push_test_utils.dart' as push
    show
        MockDio,
        MockAuthStorage,
        MockSignOutService,
        MockSignalRService,
        MockTravelLocalRepository,
        MockLocationService,
        MockModularNavigator,
        StubPage;

// F10: módulo de teste dedicado a HomeScreen — reaproveita os mocks de
// push_test_utils.dart e adiciona só o que HomeScreen usa a mais
// (AvailabilityDatasource; as rotas de settings/histórico/nova-viagem).
class HomeTestModule extends Module {
  final push.MockDio dio;
  final push.MockAuthStorage authStorage;
  final push.MockSignOutService signOutService;
  final push.MockSignalRService signalRService;
  final push.MockTravelLocalRepository travelLocalRepository;
  final push.MockLocationService locationService;

  HomeTestModule({
    required this.dio,
    required this.authStorage,
    required this.signOutService,
    required this.signalRService,
    required this.travelLocalRepository,
    required this.locationService,
  });

  @override
  void binds(Injector i) {
    i.addInstance<Dio>(dio);
    i.addInstance<AuthStorage>(authStorage);
    i.addInstance<SignOutService>(signOutService);
    i.addInstance<SignalRService>(signalRService);
    i.addInstance<TravelLocalRepository>(travelLocalRepository);
    i.addInstance<LocationService>(locationService);
    // AvailabilityDatasource não tem interface própria — instanciada de
    // verdade sobre o Dio mockado, em vez de mockar mais uma classe.
    i.addInstance<AvailabilityDatasource>(AvailabilityDatasource(dio));
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const HomeScreen());
    r.child('/active-travel', child: (_) => const push.StubPage(label: 'ActiveTravel'));
    r.child('/travel-history', child: (_) => const push.StubPage(label: 'TravelHistory'));
    r.child('/profile-configuration', child: (_) => const push.StubPage(label: 'ProfileConfiguration'));
    r.child('/login', child: (_) => const push.StubPage(label: 'Login'));
  }
}

/// Inicializa o Modular de teste (mesma convenção de push_test_utils.dart,
/// mas genérica o bastante pra aceitar qualquer [Module] de teste).
void initTestModule(Module module, push.MockModularNavigator navigator) {
  Modular.init(module);
  Modular.navigatorDelegate = navigator;
}

void destroyTestModule() {
  Modular.navigatorDelegate = null;
  try {
    Modular.destroy();
  } catch (_) {}
}

/// Resposta padrão de disponibilidade (ativa) — evita o modal de
/// "Confirmar atendimento" abrir sozinho durante os testes que não são
/// sobre ele.
Map<String, dynamic> activeAvailabilityPayload() => {
      'status': 'active',
      'activatedAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
    };

Response<dynamic> noContentResponse() => Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 204,
    );

Response<dynamic> okResponse(Map<String, dynamic>? data) => Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: data,
    );

/// Payload de viagem ativa compatível com GET /api/travels/active.
Map<String, dynamic> activeTravelPayload({
  String travelId = 'travel-1',
  String status = 'Accepted',
  String? passengerName = 'Maria Passageira',
}) =>
    {
      'travelId': travelId,
      'status': status,
      'passengerName': passengerName,
    };

/// Payload compatível com o evento SignalR `NewOrder`.
Map<String, dynamic> newOrderPayload({String orderId = 'order-1'}) => {
      'orderId': orderId,
      'travelId': 'travel-1',
      'customerId': 'customer-1',
      'driverId': 'driver-1',
      'status': 'pending',
      'distanceToPassengerInMeters': 1500,
      'distanceToDestinationInMeters': 5000,
      'averageTravelTimeInHours': 1,
      'averageTravelTimeInMinutes': 30,
      'passengerLatitude': -23.55,
      'passengerLongitude': -46.63,
      'destinationLatitude': -23.60,
      'destinationLongitude': -46.65,
      'routes': const <dynamic>[],
      'createdAt': '2026-08-17T10:00:00Z',
      'startedAt': null,
      'finishedAt': null,
      'cancelledAt': null,
      'cancellationReason': null,
      'departureAddress': 'Av. Paulista, 1000',
      'destinationAddress': 'Av. Faria Lima, 2000',
      'encodedPolyline': null,
      'routeJson': null,
    };
