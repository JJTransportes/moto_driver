import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/modules/driver_home/presentation/widgets/incoming_order_sheet.dart';

import '../../../../helpers/push_test_utils.dart';

void main() {
  late MockDio dio;
  late MockAuthStorage authStorage;
  late MockIAuthRepository authRepository;
  late MockSignOutService signOutService;
  late MockSignalRService signalRService;
  late MockTravelLocalRepository travelLocalRepository;
  late MockLocationService locationService;
  late MockModularNavigator navigator;

  setUp(() {
    dio = MockDio();
    authStorage = MockAuthStorage();
    authRepository = MockIAuthRepository();
    signOutService = MockSignOutService();
    signalRService = MockSignalRService();
    travelLocalRepository = MockTravelLocalRepository();
    locationService = MockLocationService();
    navigator = MockModularNavigator();

    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsPlatform();
    NotificationService.clearPendingOrder();
    NotificationService.setOrderAlertOpen(false);

    when(() => locationService.getCurrentPosition()).thenAnswer(
      (_) async => LocationResult(
        position: Position(
          latitude: -23.55,
          longitude: -46.63,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0,
          altitudeAccuracy: 5.0,
          heading: 0,
          headingAccuracy: 5.0,
          speed: 0,
          speedAccuracy: 5.0,
        ),
        status: LocationStatus.granted,
      ),
    );
  });

  PushTestModule buildModule() => PushTestModule(
        dio: dio,
        authStorage: authStorage,
        authRepository: authRepository,
        signOutService: signOutService,
        signalRService: signalRService,
        travelLocalRepository: travelLocalRepository,
        locationService: locationService,
      );

  void stubAcceptOrder() {
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse({
        'travelId': 'travel-1',
        'routes': <dynamic>[],
      }),
    );
    when(() => travelLocalRepository.saveActiveTravel(any()))
        .thenAnswer((_) async {});
    when(() => signalRService.denyOrder(any())).thenAnswer((_) async {});
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    destroyTestModule();
  }

  testWidgets('modo embutido: aceitar → onDecision(accepted, result) sem navegar',
      (tester) async {
    stubAcceptOrder();
    initTestModule(buildModule(), navigator);

    OrderDecision? decision;
    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncomingOrderSheet(
            order: pendingOrderPayload(),
            onDecision: (d, r) {
              decision = d;
              result = r;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nova Viagem'), findsOneWidget);

    await tester.tap(find.byTooltip('Aceitar'));
    // Estado 'accepting' mostra spinner infinito — pumps limitados bastam
    // para os futures (location/dio/persist) completarem.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(decision, OrderDecision.accepted);
    expect(result?['travelId'], 'travel-1');
    // Nenhuma navegação própria no modo embutido.
    verifyNever(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    );
    verifyNever(
      () => navigator.pushReplacementNamed(any(),
          arguments: any(named: 'arguments')),
    );
    // O card permanece montado (sem pop).
    expect(find.text('Nova Viagem'), findsOneWidget);
    // Aceite persistido localmente.
    verify(() => travelLocalRepository.saveActiveTravel(any())).called(1);

    await teardown(tester);
  });

  testWidgets('modo embutido: recusar → onDecision(denied) + deny disparado sem pop',
      (tester) async {
    stubAcceptOrder();
    initTestModule(buildModule(), navigator);

    OrderDecision? decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncomingOrderSheet(
            order: pendingOrderPayload(),
            onDecision: (d, _) => decision = d,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Recusar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(decision, OrderDecision.denied);
    verify(() => signalRService.denyOrder('order-1')).called(1);
    // Sem pop no modo embutido.
    expect(find.text('Nova Viagem'), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('modal (SignalR): aceitar → pop + pushNamed(/active-travel)',
      (tester) async {
    // Viewport maior: o modal usa 0.8 da altura da tela; o conteúdo do card
    // (~500px com a fonte de teste) não cabe em 600px de altura.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stubAcceptOrder();
    when(() => dio.get(any()))
        .thenAnswer((_) async => okResponse(pendingOrderPayload()));
    when(() => signalRService.onOrderCancelled)
        .thenAnswer((_) => const Stream.empty());
    when(() => signalRService.isConnected(any())).thenReturn(false);
    when(() => signalRService.connect(any(), any(), any())).thenAnswer((_) async {});
    when(() => navigator.pushNamed(any(), arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);
    initTestModule(buildModule(), navigator);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => IncomingOrderSheet.show(
                  ctx,
                  pendingOrderPayload(),
                  onDenied: () {},
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nova Viagem'), findsOneWidget);

    await tester.tap(find.byTooltip('Aceitar'));
    // Accepting → spinner infinito; pop do modal + pushNamed via mocks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300)); // animação do pop
    await tester.pump(const Duration(milliseconds: 300));

    // Aceite via REST + navegação para a próxima tela do fluxo de viagem.
    final captured = verify(
      () => dio.post(captureAny(), data: any(named: 'data')),
    ).captured;
    expect(captured.single, contains('/api/travels/orders/order-1/accept'));
    verify(
      () => navigator.pushNamed('/active-travel',
          arguments: any(named: 'arguments')),
    ).called(1);
    // Sheet modal fechou (pop).
    expect(find.text('Nova Viagem'), findsNothing);

    await teardown(tester);
  });
}
