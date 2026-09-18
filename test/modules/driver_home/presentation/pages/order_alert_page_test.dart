import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/modules/driver_home/presentation/pages/order_alert_page.dart';

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
  late StreamController<Map<String, dynamic>> cancelController;

  setUp(() {
    dio = MockDio();
    authStorage = MockAuthStorage();
    authRepository = MockIAuthRepository();
    signOutService = MockSignOutService();
    signalRService = MockSignalRService();
    travelLocalRepository = MockTravelLocalRepository();
    locationService = MockLocationService();
    navigator = MockModularNavigator();
    cancelController = StreamController<Map<String, dynamic>>.broadcast();

    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsPlatform();
    NotificationService.clearPendingOrder();
    NotificationService.setOrderAlertOpen(false);

    when(() => locationService.getCurrentPosition())
        .thenAnswer((_) async => const LocationResult(status: LocationStatus.granted));
    when(() => signalRService.onOrderCancelled)
        .thenAnswer((_) => cancelController.stream);
    when(() => signalRService.isConnected(any())).thenReturn(true);
    when(() => signalRService.connect(any(), any(), any())).thenAnswer((_) async {});
    when(() => signalRService.disconnect(any())).thenAnswer((_) async {});
    when(() => signalRService.denyOrder(any())).thenAnswer((_) async {});
    when(() => authStorage.getToken()).thenAnswer((_) async => 'token');
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

  void stubOrderFetched({String orderId = 'order-1', String status = 'pending'}) {
    when(() => dio.get(any())).thenAnswer(
      (_) async => okResponse(
        pendingOrderPayload(orderId: orderId)..['status'] = status,
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester, {String? orderId = 'order-1'}) async {
    initTestModule(buildModule(), navigator);
    // Rede de segurança: se o teste falhar no meio, o Modular é destruído
    // (evita ModuleStartedException no teste seguinte).
    addTearDown(destroyTestModule);
    await tester.pumpWidget(
      MaterialApp(home: OrderAlertPage(orderId: orderId)),
    );
    await tester.pumpAndSettle();
  }

  /// Desmonta a árvore (dispose da página → cancela timer/assinaturas).
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await cancelController.close();
    destroyTestModule();
  }

  testWidgets('200 → exibe o card do pedido (dados do IncomingOrderSheet)',
      (tester) async {
    stubOrderFetched();
    await pumpPage(tester);

    expect(find.text('Nova Viagem'), findsOneWidget);
    expect(find.text('Av. Paulista, 1000'), findsOneWidget);
    expect(find.text('Av. Faria Lima, 2000'), findsOneWidget);

    final captured = verify(() => dio.get(captureAny())).captured;
    expect(captured.single, contains('/api/travels/orders/order-1'));

    await disposeTree(tester);
  });

  testWidgets('flag orderAlertOpen setada na abertura e limpa no dispose',
      (tester) async {
    stubOrderFetched();
    await pumpPage(tester);

    expect(NotificationService.orderAlertOpen, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(NotificationService.orderAlertOpen, isFalse);
    await cancelController.close();
    destroyTestModule();
  });

  testWidgets('403 → indisponível + Voltar para a Home (limpa pendente)',
      (tester) async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 403,
        ),
      ),
    );
    when(() => navigator.path).thenReturn('/order-alert');
    when(() => navigator.pushReplacementNamed(any(),
            arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);

    NotificationService.setPendingOrder('order-1');
    await pumpPage(tester);

    expect(
      find.text('Este pedido não está mais disponível para você.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Voltar para a Home'));
    await tester.pump();

    verify(() => navigator.pushReplacementNamed('/home',
        arguments: any(named: 'arguments'))).called(1);
    expect(NotificationService.peekPendingOrder(), isNull);

    await disposeTree(tester);
  });

  testWidgets('404 → Pedido não encontrado', (tester) async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
        ),
      ),
    );
    await pumpPage(tester);

    expect(find.text('Pedido não encontrado.'), findsOneWidget);
    expect(find.text('Voltar para a Home'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('status accepted → Pedido não está mais disponível', (tester) async {
    stubOrderFetched(status: 'accepted');
    await pumpPage(tester);

    expect(find.text('Pedido não está mais disponível.'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('401 → Sessão expirada (sem retry — token já renovado no fluxo)',
      (tester) async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
        ),
      ),
    );
    await pumpPage(tester);

    expect(find.text('Sessão expirada.'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('erro de rede → retry 1x → Tentar novamente recomeça do zero',
      (tester) async {
    when(() => dio.get(any())).thenThrow(
      DioException(requestOptions: RequestOptions(path: '')),
    );

    await pumpPage(tester);

    // 1ª tentativa falhou → aguardou 1s → 2ª tentativa falhou → erro.
    verify(() => dio.get(any())).called(2);
    expect(find.text('Não foi possível carregar o pedido.'), findsOneWidget);

    // "Tentar novamente" recomeça do zero (attempt reset) → agora 200.
    stubOrderFetched();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Nova Viagem'), findsOneWidget);
    verify(() => dio.get(any())).called(1); // nova chamada após o tap

    await disposeTree(tester);
  });

  testWidgets('aceitar → pushReplacementNamed(/active-travel) + pendente limpo',
      (tester) async {
    stubOrderFetched();
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse({
        'travelId': 'travel-1',
        'routes': <dynamic>[],
      }),
    );
    when(() => travelLocalRepository.saveActiveTravel(any()))
        .thenAnswer((_) async {});
    when(() => navigator.pushReplacementNamed(any(),
            arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);
    NotificationService.setPendingOrder('order-1');

    await pumpPage(tester);
    expect(find.text('Nova Viagem'), findsOneWidget);

    await tester.tap(find.byTooltip('Aceitar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final captured = verify(
      () => navigator.pushReplacementNamed('/active-travel',
          arguments: captureAny(named: 'arguments')),
    ).captured;
    final args = captured.single as Map<String, dynamic>;
    expect(args['travelId'], 'travel-1');
    expect(NotificationService.peekPendingOrder(), isNull);

    await disposeTree(tester);
  });

  testWidgets('recusar → _exitToHome: popUntil + /home + pendente limpo',
      (tester) async {
    stubOrderFetched();
    when(() => navigator.path).thenReturn('/order-alert');
    when(() => navigator.pushReplacementNamed(any(),
            arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);
    NotificationService.setPendingOrder('order-1');

    await pumpPage(tester);
    expect(find.text('Nova Viagem'), findsOneWidget);

    await tester.tap(find.byTooltip('Recusar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => navigator.popUntil(any())).called(1);
    verify(() => navigator.pushReplacementNamed('/home',
        arguments: any(named: 'arguments'))).called(1);
    expect(NotificationService.peekPendingOrder(), isNull);

    await disposeTree(tester);
  });

  testWidgets('RF11: novo pedido durante a página → reexibido após a saída',
      (tester) async {
    stubOrderFetched();
    when(() => navigator.path).thenReturn('/order-alert');
    when(() => navigator.pushReplacementNamed(any(),
            arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);
    when(() => navigator.pushNamed(any(), arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);
    NotificationService.setPendingOrder('order-1');

    await pumpPage(tester);
    expect(find.text('Nova Viagem'), findsOneWidget);

    // Segundo clique (outro pedido) enquanto a página está aberta.
    NotificationService.setPendingOrder('order-2');

    await tester.tap(find.byTooltip('Recusar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Sair para a home e reabrir o fluxo com o novo pendente.
    verify(() => navigator.pushReplacementNamed('/home',
        arguments: any(named: 'arguments'))).called(1);
    verify(() => navigator.pushNamed('/order-refresh',
        arguments: {'orderId': 'order-2'})).called(1);

    await disposeTree(tester);
  });

  testWidgets('sem orderId nos args → fallback para o pendente do holder',
      (tester) async {
    stubOrderFetched(orderId: 'order-9');
    NotificationService.setPendingOrder('order-9');

    await pumpPage(tester, orderId: null);

    expect(find.text('Nova Viagem'), findsOneWidget);
    final captured = verify(() => dio.get(captureAny())).captured;
    expect(captured.single, contains('/api/travels/orders/order-9'));

    await disposeTree(tester);
  });

  testWidgets('sem orderId e sem pendente → estado de erro', (tester) async {
    await pumpPage(tester, orderId: null);

    expect(find.text('Pedido não encontrado.'), findsOneWidget);
    expect(find.text('Voltar para a Home'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('OrderCancelled (mesmo orderId) → Pedido cancelado pelo passageiro',
      (tester) async {
    stubOrderFetched();
    await pumpPage(tester);
    expect(find.text('Nova Viagem'), findsOneWidget);

    cancelController.add({'orderId': 'order-1'});
    await tester.pump(); // microtask entrega o evento → setState agenda frame
    await tester.pump(); // frame renderiza o estado indisponível

    expect(find.text('Pedido cancelado pelo passageiro.'), findsOneWidget);
    expect(find.text('Voltar para a Home'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('OrderCancelled (orderId diferente) → ignora', (tester) async {
    stubOrderFetched();
    await pumpPage(tester);

    cancelController.add({'orderId': 'outro-pedido'});
    await tester.pump();

    expect(find.text('Nova Viagem'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('hub: não conectado → connect; dispose → disconnect',
      (tester) async {
    stubOrderFetched();
    when(() => signalRService.isConnected('travel-orders')).thenReturn(false);

    await pumpPage(tester);

    verify(() => signalRService.connect('travel-orders', any(), 'token'))
        .called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    verify(() => signalRService.disconnect('travel-orders')).called(1);
    await cancelController.close();
    destroyTestModule();
  });

  testWidgets('hub: já conectado → não reconecta', (tester) async {
    stubOrderFetched();
    when(() => signalRService.isConnected('travel-orders')).thenReturn(true);

    await pumpPage(tester);

    verifyNever(
      () => signalRService.connect(any(), any(), any()),
    );

    await disposeTree(tester);
  });

  testWidgets('PopScope canPop:false → gesto de voltar não fecha a página',
      (tester) async {
    stubOrderFetched();
    await pumpPage(tester);
    expect(find.text('Nova Viagem'), findsOneWidget);

    final dynamic widgetsApp = tester.state(find.byType(WidgetsApp));
    await widgetsApp.didPopRoute();
    await tester.pump();

    // A página permanece (decisão explícita via Aceitar/Recusar).
    expect(find.text('Nova Viagem'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('Posição GPS concedida → body do accept inclui lat/lng',
      (tester) async {
    stubOrderFetched();
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
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse({
        'travelId': 'travel-1',
        'routes': <dynamic>[],
      }),
    );
    when(() => travelLocalRepository.saveActiveTravel(any()))
        .thenAnswer((_) async {});
    when(() => navigator.pushReplacementNamed(any(),
            arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);

    await pumpPage(tester);
    await tester.tap(find.byTooltip('Aceitar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final captured = verify(
      () => dio.post(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    final body = captured[1] as Map<String, dynamic>?;
    expect(body?['currentLatitude'], -23.55);
    expect(body?['currentLongitude'], -46.63);

    await disposeTree(tester);
  });
}
