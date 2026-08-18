import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';

void main() {
  setUp(() {
    NotificationService.clearPendingOrder();
    NotificationService.setOrderAlertOpen(false);
  });

  group('pedido pendente', () {
    test('setPendingOrder + peekPendingOrder retorna o id', () {
      NotificationService.setPendingOrder('order-1');

      expect(NotificationService.peekPendingOrder(), 'order-1');
    });

    test('peek sem pendente retorna null', () {
      expect(NotificationService.peekPendingOrder(), isNull);
    });

    test('clearPendingOrder limpa o pendente', () {
      NotificationService.setPendingOrder('order-1');
      NotificationService.clearPendingOrder();

      expect(NotificationService.peekPendingOrder(), isNull);
    });

    test('setPendingOrder sobrescreve o pendente anterior', () {
      NotificationService.setPendingOrder('order-1');
      NotificationService.setPendingOrder('order-2');

      expect(NotificationService.peekPendingOrder(), 'order-2');
    });
  });

  group('flag orderAlertOpen', () {
    test('inicialmente false', () {
      expect(NotificationService.orderAlertOpen, isFalse);
    });

    test('setOrderAlertOpen reflete o estado', () {
      NotificationService.setOrderAlertOpen(true);
      expect(NotificationService.orderAlertOpen, isTrue);

      NotificationService.setOrderAlertOpen(false);
      expect(NotificationService.orderAlertOpen, isFalse);
    });
  });
}
