import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_driver/modules/driver_home/presentation/pages/order_alert_page.dart';
import 'package:moto_driver/modules/driver_home/presentation/pages/order_refresh_page.dart';

// ── Mocks (mocktail) ──────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

class MockAuthStorage extends Mock implements AuthStorage {}

class MockIAuthRepository extends Mock implements IAuthRepository {}

class MockSignOutService extends Mock implements SignOutService {}

class MockSignalRService extends Mock implements SignalRService {}

class MockTravelLocalRepository extends Mock implements TravelLocalRepository {}

class MockLocationService extends Mock implements LocationService {}

// ── Fake do Google Maps (somente teste — sem seams de produção) ──────
// O GoogleMap (platform view) não pode ser renderizado em widget tests;
// este fake substitui a plataforma retornando um placeholder.

class FakeGoogleMapsPlatform extends GoogleMapsFlutterPlatform {
  @override
  Future<void> init(int mapId) async {}

  @override
  void dispose({required int mapId}) {}

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    return const SizedBox.shrink();
  }
}

// ── Mock do Modular.to (navigatorDelegate — padrão oficial p/ testes) ──

class MockModularNavigator extends Mock implements IModularNavigator {}

// ── Stub de páginas de navegação ─────────────────────────────────────

class StubPage extends StatelessWidget {
  final String label;

  const StubPage({super.key, required this.label});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

// ── Módulo de teste ──────────────────────────────────────────────────

class PushTestModule extends Module {
  final MockDio dio;
  final MockAuthStorage authStorage;
  final MockIAuthRepository authRepository;
  final MockSignOutService signOutService;
  final MockSignalRService signalRService;
  final MockTravelLocalRepository travelLocalRepository;
  final MockLocationService locationService;

  PushTestModule({
    required this.dio,
    required this.authStorage,
    required this.authRepository,
    required this.signOutService,
    required this.signalRService,
    required this.travelLocalRepository,
    required this.locationService,
  });

  @override
  void binds(Injector i) {
    i.addInstance<Dio>(dio);
    i.addInstance<AuthStorage>(authStorage);
    i.addInstance<IAuthRepository>(authRepository);
    i.addInstance<SignOutService>(signOutService);
    i.addInstance<SignalRService>(signalRService);
    i.addInstance<TravelLocalRepository>(travelLocalRepository);
    i.addInstance<LocationService>(locationService);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const StubPage(label: 'Root'));
    r.child('/home', child: (_) => const StubPage(label: 'Home'));
    r.child('/login', child: (_) => const StubPage(label: 'Login'));
    r.child(
      '/order-refresh',
      child: (_) => OrderRefreshPage(
        orderId: Modular.args.data['orderId'] as String?,
      ),
    );
    r.child(
      '/order-alert',
      child: (_) => OrderAlertPage(
        orderId: Modular.args.data['orderId'] as String?,
      ),
    );
    r.child('/active-travel', child: (_) => const StubPage(label: 'ActiveTravel'));
  }
}

/// Payload compatível com o GET /api/travels/orders/{orderId} (status pending).
Map<String, dynamic> pendingOrderPayload({String orderId = 'order-1'}) => {
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

Response<dynamic> okResponse(Map<String, dynamic> data) => Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: data,
    );

/// Inicializa o Modular de teste: DI do módulo + navigator mockado como
/// `navigatorDelegate` (padrão oficial do flutter_modular para testes).
void initTestModule(PushTestModule module, MockModularNavigator navigator) {
  Modular.init(module);
  Modular.navigatorDelegate = navigator;
}

/// Finaliza o Modular de teste (tolerante — pode rodar 2x via addTearDown).
void destroyTestModule() {
  Modular.navigatorDelegate = null;
  try {
    Modular.destroy();
  } catch (_) {}
}
