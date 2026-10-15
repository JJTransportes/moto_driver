import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/blocs/bloc/bootstrap_bloc.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/notifications/inotification_service.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';

class _MockNotificationService extends Mock implements INotificationService {}

class _MockAuthStorage extends Mock implements AuthStorage {}

class _MockAuthRepository extends Mock implements IAuthRepository {}

class _MockSignOutService extends Mock implements SignOutService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'conclui a configuração mesmo se o pedido de notificação nunca responder',
    () async {
      final notifications = _MockNotificationService();
      when(() => notifications.initialize(any())).thenAnswer((_) async {});
      when(
        () => notifications.requestNotificationPermission(),
      ).thenAnswer((_) => Completer<bool>().future);

      final bloc = BootstrapBloc(
        notifications,
        _MockAuthStorage(),
        _MockAuthRepository(),
        _MockSignOutService(),
        notificationPermissionTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(bloc.close);

      final success = bloc.stream.firstWhere(
        (state) => state is ConfigurationSuccessState,
      );
      bloc.add(ConfigureApplicationEvent());

      expect(
        await success.timeout(const Duration(seconds: 2)),
        isA<ConfigurationSuccessState>(),
      );
    },
  );

  group('permissão de localização na abertura', () {
    late _MockNotificationService notifications;

    setUp(() {
      notifications = _MockNotificationService();
      when(() => notifications.initialize(any())).thenAnswer((_) async {});
      when(
        () => notifications.requestNotificationPermission(),
      ).thenAnswer((_) async => true);
    });

    BootstrapBloc buildBloc({
      required bool isIOS,
      required Future<void> Function() requestLocation,
    }) {
      final bloc = BootstrapBloc(
        notifications,
        _MockAuthStorage(),
        _MockAuthRepository(),
        _MockSignOutService(),
        notificationPermissionTimeout: const Duration(milliseconds: 50),
        requestLocationPermission: requestLocation,
        isIOS: isIOS,
      );
      addTearDown(bloc.close);
      return bloc;
    }

    Future<void> configure(BootstrapBloc bloc) async {
      final success = bloc.stream.firstWhere(
        (state) => state is ConfigurationSuccessState,
      );
      bloc.add(ConfigureApplicationEvent());
      await success.timeout(const Duration(seconds: 2));
    }

    test('iOS: pede a permissão de localização', () async {
      var calls = 0;
      await configure(
        buildBloc(isIOS: true, requestLocation: () async => calls++),
      );
      expect(calls, 1);
    });

    test('fora do iOS: não pede (o aviso do Android cuida disso)', () async {
      var calls = 0;
      await configure(
        buildBloc(isIOS: false, requestLocation: () async => calls++),
      );
      expect(calls, 0);
    });

    test('iOS: pedido que nunca responde não trava a abertura', () async {
      await configure(
        buildBloc(isIOS: true, requestLocation: () => Completer<void>().future),
      );
    });

    test('iOS: erro no pedido não trava a abertura', () async {
      await configure(
        buildBloc(
          isIOS: true,
          requestLocation: () async => throw Exception('falhou'),
        ),
      );
    });
  });
}
