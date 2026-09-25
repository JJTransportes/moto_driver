import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/screens/home_screen.dart';

import '../helpers/home_test_utils.dart';

void main() {
  late MockDio dio;
  late MockAuthStorage authStorage;
  late MockSignOutService signOutService;
  late MockSignalRService signalRService;
  late MockTravelLocalRepository travelLocalRepository;
  late MockLocationService locationService;
  late MockModularNavigator navigator;

  late StreamController<Map<String, dynamic>> newOrderController;
  late StreamController<Map<String, dynamic>> orderCancelledController;
  late StreamController<Map<String, dynamic>> travelCancelledController;
  late StreamController<Map<String, dynamic>> travelStartedController;
  late StreamController<Map<String, dynamic>> travelCompletedController;
  late StreamController<void> reconnectingController;
  late StreamController<void> reconnectedController;
  late StreamController<void> closedController;

  setUp(() {
    dio = MockDio();
    authStorage = MockAuthStorage();
    signOutService = MockSignOutService();
    signalRService = MockSignalRService();
    travelLocalRepository = MockTravelLocalRepository();
    locationService = MockLocationService();
    navigator = MockModularNavigator();

    newOrderController = StreamController<Map<String, dynamic>>.broadcast();
    orderCancelledController = StreamController<Map<String, dynamic>>.broadcast();
    travelCancelledController = StreamController<Map<String, dynamic>>.broadcast();
    travelStartedController = StreamController<Map<String, dynamic>>.broadcast();
    travelCompletedController = StreamController<Map<String, dynamic>>.broadcast();
    reconnectingController = StreamController<void>.broadcast();
    reconnectedController = StreamController<void>.broadcast();
    closedController = StreamController<void>.broadcast();

    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsPlatform();
    NotificationService.clearPendingOrder();
    NotificationService.setOrderAlertOpen(false);
    NotificationService.setSheetVisible(false);

    when(() => authStorage.getUserId()).thenAnswer((_) async => 'user-1');
    when(() => authStorage.getToken()).thenAnswer((_) async => 'token');

    when(() => signalRService.onNewOrder).thenAnswer((_) => newOrderController.stream);
    when(() => signalRService.onOrderCancelled).thenAnswer((_) => orderCancelledController.stream);
    when(() => signalRService.onTravelCancelled).thenAnswer((_) => travelCancelledController.stream);
    when(() => signalRService.onTravelStarted).thenAnswer((_) => travelStartedController.stream);
    when(() => signalRService.onTravelCompleted).thenAnswer((_) => travelCompletedController.stream);
    when(() => signalRService.onReconnecting).thenAnswer((_) => reconnectingController.stream);
    when(() => signalRService.onReconnected).thenAnswer((_) => reconnectedController.stream);
    when(() => signalRService.onClosed).thenAnswer((_) => closedController.stream);
    when(() => signalRService.isConnected(any())).thenReturn(true);
    when(() => signalRService.connect(any(), any(), any())).thenAnswer((_) async {});
    when(() => signalRService.disconnect(any())).thenAnswer((_) async {});
    when(() => signalRService.disconnectAll()).thenAnswer((_) async {});
    when(() => signalRService.reportLocation(any(), any())).thenAnswer((_) async {});

    when(() => travelLocalRepository.getActiveTravel()).thenAnswer((_) async => null);
    when(() => travelLocalRepository.clearTravels()).thenAnswer((_) async {});

    when(() => signOutService.signOut()).thenAnswer((_) async {});
    when(() => locationService.getCurrentPosition())
        .thenAnswer((_) async => const LocationResult(status: LocationStatus.denied));
  });

  tearDown(() async {
    await newOrderController.close();
    await orderCancelledController.close();
    await travelCancelledController.close();
    await travelStartedController.close();
    await travelCompletedController.close();
    await reconnectingController.close();
    await reconnectedController.close();
    await closedController.close();
  });

  HomeTestModule buildModule() => HomeTestModule(
        dio: dio,
        authStorage: authStorage,
        signOutService: signOutService,
        signalRService: signalRService,
        travelLocalRepository: travelLocalRepository,
        locationService: locationService,
      );

  /// Stub genérico do GET /api/drivers/{userId} (nome/foto do motorista) e
  /// GET /api/drivers/availability — ambos disparados no initState, mas
  /// irrelevantes para a maioria dos testes. Disponibilidade sempre 'active'
  /// pra não abrir o modal de confirmação sozinha.
  void stubBackgroundCalls({Response<dynamic>? activeTravelResponse}) {
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/travels/active')) {
        return activeTravelResponse ?? noContentResponse();
      }
      if (url.contains('/api/drivers/availability')) {
        return okResponse(activeAvailabilityPayload());
      }
      if (url.contains('/api/drivers/')) {
        return okResponse({'name': 'João Motorista', 'photoUrl': null});
      }
      return noContentResponse();
    });
  }

  Future<void> pumpHome(WidgetTester tester, {Response<dynamic>? activeTravelResponse}) async {
    stubBackgroundCalls(activeTravelResponse: activeTravelResponse);
    initTestModule(buildModule(), navigator);
    addTearDown(destroyTestModule);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    // Não usa pumpAndSettle: o badge "Em andamento" (MotoStatusBadge.trip com
    // live: true) anima em loop infinito (pulso do ponto) — pumpAndSettle
    // nunca converge e estoura timeout sempre que a viagem está InProgress.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('sem viagem ativa (204) → mostra "Aguardando novas viagens..."', (tester) async {
    await pumpHome(tester);

    expect(find.text('Aguardando novas viagens...'), findsOneWidget);
    expect(find.text('Viagem ativa'), findsNothing);
  });

  testWidgets('com viagem ativa Accepted → mostra card com nome do passageiro e badge "Aceita"', (tester) async {
    await pumpHome(
      tester,
      activeTravelResponse: okResponse(activeTravelPayload(status: 'Accepted')),
    );

    expect(find.text('Viagem ativa'), findsOneWidget);
    expect(find.text('Maria Passageira'), findsOneWidget);
    expect(find.text('Aceita · aguardando'), findsOneWidget);
  });

  testWidgets('com viagem ativa InProgress → badge "Em andamento"', (tester) async {
    await pumpHome(
      tester,
      activeTravelResponse: okResponse(activeTravelPayload(status: 'InProgress')),
    );

    expect(find.text('Em andamento'), findsWidgets);
  });

  testWidgets('tap "Abrir Viagem" → navega para /active-travel com o travelId', (tester) async {
    when(() => navigator.pushNamed(any(), arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);

    await pumpHome(
      tester,
      activeTravelResponse: okResponse(activeTravelPayload(travelId: 'travel-42')),
    );

    await tester.tap(find.text('Abrir viagem'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => navigator.pushNamed('/active-travel', arguments: captureAny(named: 'arguments')),
    ).captured;
    expect(captured.single, {'travelId': 'travel-42'});
  });

  testWidgets('TravelCancelled (mesmo travelId) → limpa o card e mostra snackbar', (tester) async {
    await pumpHome(
      tester,
      activeTravelResponse: okResponse(activeTravelPayload(travelId: 'travel-1')),
    );
    expect(find.text('Viagem ativa'), findsOneWidget);

    // O handler de TravelCancelled também re-consulta o estado canônico
    // (_checkActiveTravelHttp) — sem atualizar o stub, a próxima chamada
    // devolveria a mesma viagem "ativa" de antes e ressuscitaria o card.
    stubBackgroundCalls(activeTravelResponse: noContentResponse());
    travelCancelledController.add({'travelId': 'travel-1'});
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Viagem ativa'), findsNothing);
    expect(find.text('Aguardando novas viagens...'), findsOneWidget);
    expect(find.text('Viagem cancelada'), findsOneWidget);
    verify(() => travelLocalRepository.clearTravels()).called(1);
  });

  testWidgets('TravelCancelled (travelId diferente) → ignora', (tester) async {
    await pumpHome(
      tester,
      activeTravelResponse: okResponse(activeTravelPayload(travelId: 'travel-1')),
    );

    travelCancelledController.add({'travelId': 'outro'});
    await tester.pump();
    await tester.pump();

    expect(find.text('Viagem ativa'), findsOneWidget);
  });

  testWidgets('TravelStarted → status muda para "Em andamento"', (tester) async {
    await pumpHome(
      tester,
      activeTravelResponse: okResponse(activeTravelPayload(travelId: 'travel-1', status: 'Accepted')),
    );
    expect(find.text('Aceita · aguardando'), findsOneWidget);

    stubBackgroundCalls(
      activeTravelResponse: okResponse(activeTravelPayload(travelId: 'travel-1', status: 'InProgress')),
    );
    travelStartedController.add({'travelId': 'travel-1'});
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Em andamento'), findsWidgets);
  });

  testWidgets('TravelCompleted (mesmo travelId) → limpa o card e mostra snackbar', (tester) async {
    await pumpHome(
      tester,
      activeTravelResponse: okResponse(activeTravelPayload(travelId: 'travel-1', status: 'InProgress')),
    );
    expect(find.text('Viagem ativa'), findsOneWidget);

    stubBackgroundCalls(activeTravelResponse: noContentResponse());
    travelCompletedController.add({'travelId': 'travel-1'});
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Viagem ativa'), findsNothing);
    expect(find.text('Viagem concluída'), findsOneWidget);
    verify(() => travelLocalRepository.clearTravels()).called(1);
  });

  testWidgets('NewOrder sem viagem ativa → exibe o IncomingOrderSheet', (tester) async {
    // Viewport maior que o padrão do teste (800x600) — o sheet usa 80% da
    // altura da tela; no padrão, o conteúdo do IncomingOrderSheet estoura
    // (RenderFlex overflow), só por causa do tamanho de tela do teste.
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpHome(tester);

    newOrderController.add(newOrderPayload());
    await tester.pump();
    // Não usa pumpAndSettle: o sheet tem um Timer.periodic de countdown
    // (20s até auto-rejeitar) que ficaria reagendando frames — pumpAndSettle
    // avançaria o relógio até ele disparar de verdade.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nova viagem'), findsOneWidget);
  });

  testWidgets('NewOrder com viagem ativa já carregada → ignora (não mostra o sheet)', (tester) async {
    await pumpHome(
      tester,
      activeTravelResponse: okResponse(activeTravelPayload()),
    );

    newOrderController.add(newOrderPayload());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Nova viagem'), findsNothing);
  });

  testWidgets('onReconnecting → mostra banner; onReconnected → esconde banner', (tester) async {
    await pumpHome(tester);
    expect(find.text('Reconectando...'), findsNothing);

    reconnectingController.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('Reconectando...'), findsOneWidget);

    reconnectedController.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('Reconectando...'), findsNothing);
  });

  testWidgets('sign out: menu → Sair → confirmar → chama SignOutService.signOut()', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    // Diálogo de confirmação
    expect(find.text('Deseja realmente sair?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    await tester.pumpAndSettle();

    verify(() => signOutService.signOut()).called(1);
    verify(() => signalRService.disconnectAll()).called(1);
    verify(() => travelLocalRepository.clearTravels()).called(1);
  });

  testWidgets('sign out: cancelar no diálogo → não chama signOut', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => signOutService.signOut());
  });
}
