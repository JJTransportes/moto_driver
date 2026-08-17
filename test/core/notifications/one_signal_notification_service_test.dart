import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/local_db/models/local_data_models.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/notifications_local_repository.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/core/notifications/one_signal_notification_service.dart';

import '../../helpers/push_test_utils.dart';

class MockNotificationsLocalRepository extends Mock
    implements NotificationsLocalRepository {}

class MockAuthLocalRepository extends Mock implements AuthLocalRepository {}

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

    NotificationService.clearPendingOrder();
    NotificationService.setOrderAlertOpen(false);

    when(() => navigator.path).thenReturn('/home');
    when(() => navigator.pushNamed(any(), arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);
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

  OneSignalNotificationService buildService() => OneSignalNotificationService(
        dio,
        MockNotificationsLocalRepository(),
        MockAuthLocalRepository(),
      );

  Map<String, dynamic> pushData(String orderId) => {
        'type': 'NewOrder',
        'order_id': orderId,
      };

  testWidgets('tipo != NewOrder → ignorado (sem pendente, sem navegação)',
      (tester) async {
    initTestModule(buildModule(), navigator);
    final service = buildService();

    await service.handleNotificationClick({'type': 'OrderAccepted'});

    expect(NotificationService.peekPendingOrder(), isNull);
    verifyNever(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    );
    destroyTestModule();
  });

  testWidgets('sem orderId → ignorado', (tester) async {
    initTestModule(buildModule(), navigator);
    final service = buildService();

    await service.handleNotificationClick({'type': 'NewOrder'});

    expect(NotificationService.peekPendingOrder(), isNull);
    verifyNever(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    );
    destroyTestModule();
  });

  testWidgets('ok → pendente + pushNamed(/order-refresh) com orderId',
      (tester) async {
    when(() => authStorage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-token');
    when(() => travelLocalRepository.getActiveTravel())
        .thenAnswer((_) async => null);
    initTestModule(buildModule(), navigator);
    final service = buildService();

    await service.handleNotificationClick(pushData('order-1'));

    expect(NotificationService.peekPendingOrder(), 'order-1');
    verify(() => navigator.pushNamed('/order-refresh',
        arguments: {'orderId': 'order-1'})).called(1);
    destroyTestModule();
  });

  testWidgets('página de pedido aberta → só atualiza o pendente (RF11)',
      (tester) async {
    NotificationService.setOrderAlertOpen(true);
    initTestModule(buildModule(), navigator);
    final service = buildService();

    await service.handleNotificationClick(pushData('order-2'));

    expect(NotificationService.peekPendingOrder(), 'order-2');
    verifyNever(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    );
    destroyTestModule();
  });

  testWidgets('fluxo de sessão (path /terms) → não navega; pendente mantido',
      (tester) async {
    when(() => navigator.path).thenReturn('/terms');
    initTestModule(buildModule(), navigator);
    final service = buildService();

    await service.handleNotificationClick(pushData('order-1'));

    expect(NotificationService.peekPendingOrder(), 'order-1');
    verifyNever(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    );
    destroyTestModule();
  });

  testWidgets('sem sessão (refresh token nulo) → não navega; pendente mantido',
      (tester) async {
    when(() => authStorage.getRefreshToken()).thenAnswer((_) async => null);
    initTestModule(buildModule(), navigator);
    final service = buildService();

    await service.handleNotificationClick(pushData('order-1'));

    expect(NotificationService.peekPendingOrder(), 'order-1');
    verifyNever(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    );
    destroyTestModule();
  });

  testWidgets('viagem ativa → ignora por completo (limpa pendente)',
      (tester) async {
    when(() => authStorage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-token');
    when(() => travelLocalRepository.getActiveTravel()).thenAnswer(
      (_) async => TravelLocalData(
        travelId: 'travel-1',
        status: 'Accepted',
        createdAt: DateTime.now(),
      ),
    );
    initTestModule(buildModule(), navigator);
    final service = buildService();

    await service.handleNotificationClick(pushData('order-1'));

    expect(NotificationService.peekPendingOrder(), isNull);
    verifyNever(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    );
    destroyTestModule();
  });

  testWidgets('navegação lança (cold start) → engolida; pendente sobrevive',
      (tester) async {
    when(() => navigator.path).thenThrow(StateError('Modular not ready'));
    initTestModule(buildModule(), navigator);
    final service = buildService();

    await service.handleNotificationClick(pushData('order-1'));

    expect(NotificationService.peekPendingOrder(), 'order-1');
    verifyNever(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    );
    destroyTestModule();
  });
}
