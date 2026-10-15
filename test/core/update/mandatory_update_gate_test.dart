import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/update/mandatory_update_gate.dart';

void main() {
  testWidgets('does not check for updates when disabled', (tester) async {
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MandatoryUpdateGate(
          enabled: false,
          updateCheck: () async {
            checks++;
            return true;
          },
          child: const Text('Aplicativo'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Aplicativo'), findsOneWidget);
    expect(checks, 0);
  });

  testWidgets('blocks access while an update is required', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MandatoryUpdateGate(
          enabled: true,
          updateCheck: () async => true,
          child: const Text('Aplicativo'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atualização obrigatória'), findsOneWidget);
    expect(find.text('Aplicativo'), findsNothing);
  });

  testWidgets('releases access when no update exists', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MandatoryUpdateGate(
          enabled: true,
          updateCheck: () async => false,
          child: const Text('Aplicativo'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aplicativo'), findsOneWidget);
  });
}
