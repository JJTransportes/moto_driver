// Spec pickup-arrival-alerts (req 5.1, 5.2, 5.5): indicação, em português, de
// que o passageiro foi avisado da aproximação e de que o motorista chegou.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/widgets/pickup_proximity_banner.dart';

void main() {
  group('PickupProximity.parse', () {
    test('converte os valores do backend e cai em none para o resto', () {
      expect(PickupProximity.parse('Nearby'), PickupProximity.nearby);
      expect(PickupProximity.parse('Arrived'), PickupProximity.arrived);
      expect(PickupProximity.parse('None'), PickupProximity.none);
      expect(PickupProximity.parse(null), PickupProximity.none);
      expect(PickupProximity.parse('qualquer'), PickupProximity.none);
    });
  });

  group('PickupProximityBanner', () {
    Future<void> pump(WidgetTester tester, PickupProximity value) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PickupProximityBanner(proximity: value)),
          ),
        );

    testWidgets('none não mostra nada', (tester) async {
      await pump(tester, PickupProximity.none);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('nearby informa que o passageiro foi avisado', (tester) async {
      await pump(tester, PickupProximity.nearby);

      expect(find.text('Passageiro avisado: você está próximo'), findsOneWidget);
      expect(find.text('Você chegou ao ponto de embarque'), findsNothing);
    });

    testWidgets('arrived informa a chegada ao embarque', (tester) async {
      await pump(tester, PickupProximity.arrived);

      expect(find.text('Você chegou ao ponto de embarque'), findsOneWidget);
      expect(find.text('Passageiro avisado: você está próximo'), findsNothing);
    });
  });
}
