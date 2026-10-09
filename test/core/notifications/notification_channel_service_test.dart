// Canal de notificação dos avisos de corrida (spec push-notification-sounds, req 2.1 a 2.5,
// 7.2): criado no Android com o som do Moto, tolerante a falha e sem efeito no iOS.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/notifications/notification_channel_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moto/notification_channel');
  late List<MethodCall> calls;
  late List<String> logs;

  setUp(() {
    calls = [];
    logs = [];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mockChannel(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            return handler(call);
          },
        );
  }

  NotificationChannelService build({bool android = true}) =>
      NotificationChannelService(
        isAndroid: () => android,
        canPlaySound: () => android,
        log: logs.add,
      );

  group('constantes do canal', () {
    test('o id é versionado (trocar o som exige um id novo)', () {
      expect(RideAlertsChannel.id, 'moto_ride_alerts_v2');
      expect(RideAlertsChannel.id, matches(RegExp(r'^[a-z0-9_]+_v\d+$')));
    });

    test('o nome visível ao usuário é em português', () {
      expect(RideAlertsChannel.name, 'Avisos de corrida');
      expect(RideAlertsChannel.description, isNotEmpty);
    });

    test('o som é o do Moto: res/raw, minúsculo, sem extensão', () {
      expect(RideAlertsChannel.soundResource, 'moto_notification');
      expect(RideAlertsChannel.soundResource, matches(RegExp(r'^[a-z0-9_]+$')));
    });

    test(
      'o id do canal é diferente do nome (o backend envia o id, nunca o nome)',
      () {
        expect(RideAlertsChannel.id, isNot(RideAlertsChannel.name));
      },
    );
  });

  group('Android', () {
    test('reproduz localmente o mesmo som quando o card chega', () async {
      mockChannel((_) async => true);

      await build().playRideAlertSound();

      expect(calls.single.method, 'playRideAlertSound');
      expect(calls.single.arguments, {'sound': 'moto_notification'});
    });

    test('interrompe o som quando a oferta é decidida', () async {
      mockChannel((_) async => true);

      await build().stopRideAlertSound();

      expect(calls.single.method, 'stopRideAlertSound');
    });

    test('registra o canal com id, nome, descrição e som', () async {
      mockChannel((_) async => true);

      await build().ensureRideAlertsChannel();

      final call = calls.single;
      expect(call.method, 'ensureChannel');
      expect(call.arguments, {
        'id': 'moto_ride_alerts_v2',
        'name': 'Avisos de corrida',
        'description': RideAlertsChannel.description,
        'sound': 'moto_notification',
      });
    });

    test('chamadas repetidas são seguras (o nativo é idempotente)', () async {
      mockChannel((_) async => true);
      final service = build();

      await service.ensureRideAlertsChannel();
      await service.ensureRideAlertsChannel();
      await service.ensureRideAlertsChannel();

      expect(calls, hasLength(3));
      expect(calls.map((c) => c.arguments['id']).toSet(), {
        'moto_ride_alerts_v2',
      });
    });

    test('falha do canal nativo não lança e é registrada em log', () async {
      mockChannel(
        (_) => throw PlatformException(
          code: 'channel_failed',
          message: 'segredo do erro',
        ),
      );

      await expectLater(build().ensureRideAlertsChannel(), completes);

      expect(logs, isNotEmpty);
      expect(logs.any((l) => l.contains('[PUSH]')), isTrue);
    });

    test(
      'o log da falha traz só o tipo do erro, não o texto da exceção',
      () async {
        mockChannel(
          (_) => throw PlatformException(
            code: 'channel_failed',
            message: 'segredo do erro',
          ),
        );

        await build().ensureRideAlertsChannel();

        expect(logs.any((l) => l.contains('segredo do erro')), isFalse);
        expect(logs.any((l) => l.contains('PlatformException')), isTrue);
      },
    );

    test('canal nativo inexistente (MissingPluginException) não lança', () async {
      // Sem handler registrado, o canal de método lança MissingPluginException.
      await expectLater(build().ensureRideAlertsChannel(), completes);

      expect(logs.any((l) => l.contains('MissingPluginException')), isTrue);
    });

    test('depois de uma falha, uma nova chamada tenta de novo', () async {
      var attempts = 0;
      mockChannel((_) async {
        attempts++;
        if (attempts == 1) throw PlatformException(code: 'channel_failed');
        return true;
      });
      final service = build();

      await service.ensureRideAlertsChannel();
      await service.ensureRideAlertsChannel();

      expect(attempts, 2);
    });
  });

  group('fora do Android', () {
    test('no iOS não chama o canal nativo e não registra nada', () async {
      mockChannel((_) async => true);

      await build(android: false).ensureRideAlertsChannel();

      expect(calls, isEmpty);
      expect(logs, isEmpty);
    });
  });
}
