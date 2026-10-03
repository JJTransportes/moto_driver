// Spec push-notification-sounds (req 2.1, 2.5): no app do motorista o canal dos avisos de
// corrida é criado antes de o OneSignal inicializar, sem nunca atrapalhar a inicialização.
import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/common_module.dart';
import 'package:moto_driver/core/notifications/inotification_service.dart';
import 'package:moto_driver/core/notifications/notification_channel_service.dart';
import 'package:moto_driver/core/notifications/ride_alerts_channel_notification_service.dart';

class MockInnerNotificationService extends Mock implements INotificationService {}

class MockNotificationChannelService extends Mock implements INotificationChannelService {}

void main() {
  late MockInnerNotificationService inner;
  late MockNotificationChannelService channels;
  late List<String> order;
  late RideAlertsChannelNotificationService service;

  setUp(() {
    inner = MockInnerNotificationService();
    channels = MockNotificationChannelService();
    order = [];

    when(() => channels.ensureRideAlertsChannel()).thenAnswer((_) async => order.add('channel'));
    when(() => inner.initialize(any())).thenAnswer((_) async => order.add('initialize'));
    when(() => inner.requestNotificationPermission()).thenAnswer((_) async => true);
    when(() => inner.login(any(), any())).thenAnswer((_) async {});
    when(() => inner.handleForegroundNotification()).thenAnswer((_) async {});
    when(() => inner.dismissNewOrder(any())).thenAnswer((_) async {});

    service = RideAlertsChannelNotificationService(inner, channels);
  });

  group('initialize', () {
    test('cria o canal ANTES de inicializar o OneSignal', () async {
      await service.initialize('app-123');

      expect(order, ['channel', 'initialize']);
    });

    test('inicializa o serviço interno com o mesmo identificador', () async {
      await service.initialize('app-123');

      verify(() => inner.initialize('app-123')).called(1);
    });

    test('falha ao criar o canal não impede a inicialização do OneSignal', () async {
      when(() => channels.ensureRideAlertsChannel()).thenThrow(StateError('canal quebrou'));

      await expectLater(service.initialize('app-123'), completes);

      verify(() => inner.initialize('app-123')).called(1);
    });

    test('canal que demora não trava a inicialização para sempre', () async {
      when(() => channels.ensureRideAlertsChannel()).thenAnswer((_) => Completer<void>().future);
      final slow = RideAlertsChannelNotificationService(
        inner,
        channels,
        channelTimeout: const Duration(milliseconds: 30),
      );

      await slow.initialize('app-123').timeout(const Duration(seconds: 2));

      verify(() => inner.initialize('app-123')).called(1);
    });

    test('a falha do serviço interno continua sendo propagada como antes', () async {
      when(() => inner.initialize(any())).thenThrow(Exception('inicialização falhou'));

      await expectLater(service.initialize('app-123'), throwsException);
    });
  });

  group('delegação (comportamento existente preservado)', () {
    test('requestNotificationPermission devolve o resultado do serviço interno', () async {
      expect(await service.requestNotificationPermission(), isTrue);

      when(() => inner.requestNotificationPermission()).thenAnswer((_) async => false);
      expect(await service.requestNotificationPermission(), isFalse);
    });

    test('login repassa a assinatura e o token', () async {
      await service.login('user-1', 'token-1');

      verify(() => inner.login('user-1', 'token-1')).called(1);
    });

    test('handleForegroundNotification é delegado', () async {
      await service.handleForegroundNotification();

      verify(() => inner.handleForegroundNotification()).called(1);
    });

    test('dismissNewOrder repassa o pedido', () async {
      await service.dismissNewOrder('order-1');

      verify(() => inner.dismissNewOrder('order-1')).called(1);
    });

    test('só a inicialização cria o canal', () async {
      await service.requestNotificationPermission();
      await service.login('u', 't');
      await service.handleForegroundNotification();
      await service.dismissNewOrder('o');

      verifyNever(() => channels.ensureRideAlertsChannel());
    });
  });

  group('fiação na injeção de dependência', () {
    setUp(() => Modular.init(_RootModule()));

    tearDown(() {
      try {
        Modular.destroy();
      } catch (_) {}
    });

    test('o serviço de notificações do app é o decorador com o canal', () {
      expect(Modular.get<INotificationService>(), isA<RideAlertsChannelNotificationService>());
    });

    test('é um singleton (inicializa uma única vez por execução)', () {
      expect(
        identical(Modular.get<INotificationService>(), Modular.get<INotificationService>()),
        isTrue,
      );
    });

    test('o serviço do canal é resolvido', () {
      expect(Modular.get<INotificationChannelService>(), isA<NotificationChannelService>());
    });
  });
}

class _RootModule extends Module {
  @override
  List<Module> get imports => [CommonModule()];
}
