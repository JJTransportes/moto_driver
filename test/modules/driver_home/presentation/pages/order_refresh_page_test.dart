import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/modules/auth/data/models/refresh_token_response_model.dart';
import 'package:moto_driver/modules/driver_home/presentation/pages/order_refresh_page.dart';
import 'package:result_dart/result_dart.dart';

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

    when(() => locationService.getCurrentPosition())
        .thenAnswer((_) async => const LocationResult(status: LocationStatus.granted));
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

  Future<void> pumpRefreshPage(WidgetTester tester) async {
    initTestModule(buildModule(), navigator);
    // Métodos de navegação retornam Futures — stubs genéricos.
    when(() => navigator.pushReplacementNamed(any(),
            arguments: any(named: 'arguments')))
        .thenAnswer((_) async => null);
    await tester.pumpWidget(
      const MaterialApp(home: OrderRefreshPage(orderId: 'order-1')),
    );
    // Spinner infinito — não usar pumpAndSettle; pumps limitados bastam
    // para os futures (mocks) completarem.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('exibe loading durante o refresh', (tester) async {
    when(() => authStorage.getRefreshToken()).thenAnswer((_) async => null);
    when(() => signOutService.signOut()).thenAnswer((_) async {});

    initTestModule(buildModule(), navigator);
    await tester.pumpWidget(
      const MaterialApp(home: OrderRefreshPage(orderId: 'order-1')),
    );
    await tester.pump(); // primeiro frame — refresh ainda em andamento

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
    destroyTestModule();
  });

  testWidgets('refresh ok → pushReplacementNamed(/order-alert) com orderId',
      (tester) async {
    when(() => authStorage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-token');
    when(() => authRepository.refreshToken('refresh-token', any())).thenAnswer(
      (_) async => Success(
        RefreshTokenResponseModel(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          userId: 'u1',
          roles: const ['Driver'],
        ),
      ),
    );
    when(() => authStorage.saveToken(any(), any())).thenAnswer((_) async {});
    when(() => authStorage.saveRefreshToken(any())).thenAnswer((_) async {});

    await pumpRefreshPage(tester);

    verify(() => authRepository.refreshToken('refresh-token', any())).called(1);
    verify(() => authStorage.saveToken('new-access', 'u1')).called(1);
    verify(() => authStorage.saveRefreshToken('new-refresh')).called(1);
    verify(
      () => navigator.pushReplacementNamed('/order-alert',
          arguments: {'orderId': 'order-1'}),
    ).called(1);

    destroyTestModule();
  });

  testWidgets('falha no refresh → signOut', (tester) async {
    when(() => authStorage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-token');
    when(() => authRepository.refreshToken('refresh-token', any()))
        .thenAnswer((_) async => Failure(Exception('refresh failed')));
    when(() => signOutService.signOut()).thenAnswer((_) async {});

    await pumpRefreshPage(tester);

    verify(() => signOutService.signOut()).called(1);
    verifyNever(
      () => navigator.pushReplacementNamed(any(), arguments: any(named: 'arguments')),
    );

    destroyTestModule();
  });

  testWidgets('sem refresh token → signOut', (tester) async {
    when(() => authStorage.getRefreshToken()).thenAnswer((_) async => null);
    when(() => signOutService.signOut()).thenAnswer((_) async {});

    await pumpRefreshPage(tester);

    verify(() => signOutService.signOut()).called(1);

    destroyTestModule();
  });
}
