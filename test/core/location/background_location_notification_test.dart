import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/location/background_location_service.dart';

void main() {
  group('backgroundTravelNotificationText', () {
    test('mostra deslocamento ao embarque em Accepted', () {
      expect(
        backgroundTravelNotificationText('Accepted'),
        'A caminho do local de embarque',
      );
    });

    test('mostra viagem em andamento em InProgress', () {
      expect(
        backgroundTravelNotificationText('InProgress', updatedAt: '10:42:03'),
        'Viagem em andamento • atualizado às 10:42:03',
      );
    });

    test('usa mensagem segura quando não há viagem ativa', () {
      expect(
        backgroundTravelNotificationText(null),
        'Compartilhando sua localização com segurança',
      );
    });
  });
}
