import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/network/mandatory_connectivity_gate.dart';

void main() {
  testWidgets('bloqueia offline, mantém conteúdo e libera após reconectar', (
    tester,
  ) async {
    var online = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MandatoryConnectivityGate(
          checkInterval: const Duration(hours: 1),
          connectionCheck: () async => online,
          child: const Scaffold(body: Text('Conteúdo do aplicativo')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Conexão indisponível'), findsOneWidget);
    expect(find.text('Conteúdo do aplicativo'), findsOneWidget);

    online = true;
    await tester.tap(find.text('Tentar reconectar'));
    await tester.pump();

    expect(find.text('Conexão indisponível'), findsNothing);
    expect(find.text('Conteúdo do aplicativo'), findsOneWidget);
  });

  testWidgets('durante viagem informa que o atendimento continua ativo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MandatoryConnectivityGate(
          checkInterval: const Duration(hours: 1),
          connectionCheck: () async => false,
          hasActiveTravel: () => true,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Conexão interrompida'), findsOneWidget);
    expect(find.textContaining('Sua viagem continua ativa'), findsOneWidget);
  });
}
