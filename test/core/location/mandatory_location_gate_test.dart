import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/core/location/background_location_service.dart';
import 'package:moto_driver/core/location/mandatory_location_gate.dart';

void main() {
  testWidgets('mantém o Navigator montado durante rechecagem no resume', (
    tester,
  ) async {
    final resumedCheck = Completer<BackgroundLocationPermissionStatus>();
    var checks = 0;
    var disposals = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MandatoryLocationGate(
          isAndroid: true,
          permissionCheck: (_) {
            checks++;
            if (checks == 1) {
              return Future.value(BackgroundLocationPermissionStatus.granted);
            }
            return resumedCheck.future;
          },
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => _DisposeProbe(() => disposals++),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byType(Navigator), findsWidgets);
    expect(disposals, 0);

    resumedCheck.complete(BackgroundLocationPermissionStatus.granted);
    await tester.pump();
    expect(disposals, 0);
  });
}

class _DisposeProbe extends StatefulWidget {
  const _DisposeProbe(this.onDispose);

  final VoidCallback onDispose;

  @override
  State<_DisposeProbe> createState() => _DisposeProbeState();
}

class _DisposeProbeState extends State<_DisposeProbe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
