import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/design_system/design_system.dart';

void main() {
  testWidgets('sincroniza o progresso e o número com o prazo restante', (
    tester,
  ) async {
    var timedOut = false;
    var now = DateTime.utc(2026, 10, 6, 14);
    final expiresAt = now.add(const Duration(seconds: 30));

    await tester.pumpWidget(
      MaterialApp(
        theme: MotoTheme.claro(),
        home: Scaffold(
          body: MotoCountdownRing(
            seconds: 40,
            expiresAt: expiresAt,
            now: () => now,
            onTimeout: () => timedOut = true,
          ),
        ),
      ),
    );

    expect(find.text('30'), findsOneWidget);

    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('20'), findsOneWidget);
    expect(timedOut, isFalse);

    // Reconstruir a tela não pode reencher o arco nem reiniciar a contagem.
    await tester.pumpWidget(
      MaterialApp(
        theme: MotoTheme.claro(),
        home: Scaffold(
          body: MotoCountdownRing(
            seconds: 40,
            expiresAt: expiresAt,
            now: () => now,
            onTimeout: () => timedOut = true,
          ),
        ),
      ),
    );
    expect(find.text('20'), findsOneWidget);

    now = now.add(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('0'), findsOneWidget);
    expect(timedOut, isTrue);
  });

  testWidgets('sem horário do servidor inicia o período completo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MotoTheme.claro(),
        home: const Scaffold(body: MotoCountdownRing(seconds: 40)),
      ),
    );

    expect(find.text('40'), findsOneWidget);
  });
}
