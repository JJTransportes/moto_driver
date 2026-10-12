import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/screens/active_travel_page.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';
import '../modules/chat/chat_test_doubles.dart';

import '../helpers/active_travel_test_utils.dart';

void main() {
  late MockDio dio;
  late MockAuthStorage authStorage;
  late MockSignalRService signalRService;
  late MockTravelLocalRepository travelLocalRepository;
  late MockLocationService locationService;
  late MockModularNavigator navigator;
  late StreamController<Map<String, dynamic>> travelCancelledController;
  late StreamController<Map<String, dynamic>> driverNearbyController;
  late StreamController<Map<String, dynamic>> driverArrivedController;
  late StreamController<void> reconnectedController;

  setUp(() {
    dio = MockDio();
    authStorage = MockAuthStorage();
    signalRService = MockSignalRService();
    travelLocalRepository = MockTravelLocalRepository();
    locationService = MockLocationService();
    navigator = MockModularNavigator();
    travelCancelledController =
        StreamController<Map<String, dynamic>>.broadcast();
    driverNearbyController = StreamController<Map<String, dynamic>>.broadcast();
    driverArrivedController =
        StreamController<Map<String, dynamic>>.broadcast();
    reconnectedController = StreamController<void>.broadcast();

    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsPlatform();

    when(() => authStorage.getToken()).thenAnswer((_) async => 'token');
    when(
      () => signalRService.onTravelCancelled,
    ).thenAnswer((_) => travelCancelledController.stream);
    when(
      () => signalRService.onDriverNearby,
    ).thenAnswer((_) => driverNearbyController.stream);
    when(
      () => signalRService.onDriverArrived,
    ).thenAnswer((_) => driverArrivedController.stream);
    when(
      () => signalRService.onReconnected,
    ).thenAnswer((_) => reconnectedController.stream);
    when(() => signalRService.isConnected(any())).thenReturn(true);
    when(
      () => signalRService.connect(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => signalRService.updateLocation(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => signalRService.startTravel(any())).thenAnswer((_) async {});
    when(
      () => signalRService.finishTravel(
        any(),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async {});
    when(() => travelLocalRepository.clearTravels()).thenAnswer((_) async {});
    when(() => locationService.getCurrentPosition()).thenAnswer(
      (_) async => const LocationResult(status: LocationStatus.denied),
    );
    when(
      () => navigator.navigate(any(), arguments: any(named: 'arguments')),
    ).thenReturn(null);
  });

  tearDown(() async {
    await travelCancelledController.close();
    await driverNearbyController.close();
    await driverArrivedController.close();
    await reconnectedController.close();
  });

  ActiveTravelTestModule buildModule({ChatSession? chatSession}) =>
      ActiveTravelTestModule(
        dio: dio,
        authStorage: authStorage,
        signalRService: signalRService,
        travelLocalRepository: travelLocalRepository,
        locationService: locationService,
        chatSession: chatSession,
      );

  Future<void> pumpPage(
    WidgetTester tester, {
    String travelId = 'travel-1',
    ChatSession? chatSession,
  }) async {
    initTestModule(buildModule(chatSession: chatSession), navigator);
    addTearDown(destroyTestModule);
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTravelPage(travelId: travelId),
      ),
    );
    // Não usa pumpAndSettle: o badge "Em andamento" (live: true) e o brilho
    // do MotoSwipeToConfirm animam em loop infinito, nunca convergindo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'Accepted → mostra "A caminho do passageiro" e "Iniciar Viagem"',
    (tester) async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => okResponse(travelPayload(status: 'Accepted')));
      when(
        () => dio.get('/api/passengers/passenger-1'),
      ).thenAnswer((_) async => okResponse(passengerProfilePayload()));

      await pumpPage(tester);

      expect(find.text('A caminho do passageiro'), findsOneWidget);
      expect(find.text('Aceita · aguardando'), findsOneWidget);
      expect(find.text('Iniciar viagem'), findsOneWidget);
      expect(find.text('Maria Passageira'), findsOneWidget);
    },
  );

  testWidgets(
    'InProgress → mostra "Viagem em andamento" e "Finalizar Viagem"',
    (tester) async {
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/'))
          return okResponse(passengerProfilePayload());
        return okResponse(travelPayload(status: 'InProgress'));
      });

      await pumpPage(tester);

      expect(find.text('Viagem em andamento'), findsOneWidget);
      expect(find.text('Deslize para finalizar'), findsOneWidget);
    },
  );

  testWidgets(
    'arrastar painel para baixo preserva endereços, esconde ações e amplia mapa',
    (tester) async {
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/')) {
          return okResponse(passengerProfilePayload());
        }
        return okResponse(travelPayload(status: 'InProgress'));
      });

      await pumpPage(tester);
      final mapBefore = tester.getSize(find.byType(GoogleMap)).height;
      final departure = find.textContaining('Av. Paulista, 1000');
      final destination = find.textContaining('Av. Faria Lima, 2000');

      expect(find.text('Deslize para finalizar'), findsOneWidget);
      expect(departure, findsOneWidget);
      expect(destination, findsOneWidget);

      await tester.fling(
        find.byKey(const ValueKey('travel-info-panel')),
        const Offset(0, 250),
        1200,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Deslize para finalizar'), findsNothing);
      expect(find.text('Cancelar viagem'), findsNothing);
      expect(departure, findsOneWidget);
      expect(destination, findsOneWidget);
      expect(
        tester.getSize(find.byType(GoogleMap)).height,
        greaterThan(mapBefore),
      );
    },
  );

  testWidgets('botão alterna o acompanhamento da câmera de navegação', (
    tester,
  ) async {
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/')) {
        return okResponse(passengerProfilePayload());
      }
      return okResponse(travelPayload(status: 'InProgress'));
    });

    await pumpPage(tester);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
  });

  testWidgets(
    'erro ao carregar → mostra mensagem + "Tentar novamente" recarrega',
    (tester) async {
      when(() => dio.get(any())).thenThrow(
        DioException(requestOptions: RequestOptions(path: '')),
      );

      await pumpPage(tester);

      expect(find.text('Erro ao carregar viagem'), findsOneWidget);

      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/'))
          return okResponse(passengerProfilePayload());
        return okResponse(travelPayload(status: 'Accepted'));
      });
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('A caminho do passageiro'), findsOneWidget);
    },
  );

  testWidgets(
    'tap "Iniciar Viagem" → chama signalR.startTravel e recarrega como InProgress',
    (tester) async {
      var status = 'Accepted';
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/'))
          return okResponse(passengerProfilePayload());
        return okResponse(travelPayload(status: status));
      });
      when(() => signalRService.startTravel(any())).thenAnswer((_) async {
        status = 'InProgress';
      });

      await pumpPage(tester);
      expect(find.text('Iniciar viagem'), findsOneWidget);

      await tester.tap(find.text('Iniciar viagem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => signalRService.startTravel('travel-1')).called(1);
      expect(find.text('Deslize para finalizar'), findsOneWidget);
    },
  );

  testWidgets(
    'tap "Finalizar Viagem" → confirma → chama signalR.finishTravel e recarrega como Completed',
    (tester) async {
      var status = 'InProgress';
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/'))
          return okResponse(passengerProfilePayload());
        return okResponse(travelPayload(status: status));
      });
      when(
        () => signalRService.finishTravel(
          any(),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenAnswer((_) async {
        status = 'Completed';
      });

      await pumpPage(tester);
      expect(find.text('Deslize para finalizar'), findsOneWidget);

      // MotoSwipeToConfirm não tem botão tocável — arrasta o "puxador" (ícone
      // chevron) até o fim da trilha pra disparar onConfirmed, como o gesto
      // real do usuário.
      await tester.drag(
        find.byIcon(Icons.chevron_right_rounded),
        const Offset(700, 0),
      );
      await tester.pump();
      expect(
        find.text('Tem certeza que deseja finalizar esta viagem?'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Sim, finalizar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      verify(
        () => signalRService.finishTravel(
          'travel-1',
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).called(1);
      expect(find.text('Viagem concluída!'), findsOneWidget);
      expect(find.byType(MotoSuccessCheck), findsOneWidget);
      expect(find.byType(MotoButton), findsOneWidget);
    },
  );

  testWidgets(
    'tap "Cancelar" → confirma → POST cancel e recarrega como Cancelled',
    (tester) async {
      var status = 'Accepted';
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/'))
          return okResponse(passengerProfilePayload());
        return okResponse(travelPayload(status: status));
      });
      when(
        () => dio.post(any(), data: any(named: 'data')),
      ).thenAnswer((_) async {
        status = 'Cancelled';
        return okResponse(const {});
      });

      await pumpPage(tester);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Motivo do cancelamento'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Problema no veículo');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(TextButton, 'Confirmar cancelamento'),
      );
      await tester.pumpAndSettle();

      verify(
        () => dio.post(
          any(),
          data: {'reason': 'Problema no veículo'},
        ),
      ).called(1);
      // Aparece 2x: no título do AppBar (_statusLabel()) e no corpo do estado terminal.
      expect(find.text('Viagem cancelada'), findsWidgets);
      expect(find.text('Voltar para a tela inicial'), findsOneWidget);
    },
  );

  testWidgets(
    'TravelCancelled via SignalR mostra quem cancelou no estado terminal',
    (tester) async {
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/'))
          return okResponse(passengerProfilePayload());
        return okResponse(travelPayload(status: 'Accepted'));
      });

      await pumpPage(tester, travelId: 'travel-1');

      travelCancelledController.add({
        'travelId': 'travel-1',
        'cancelledByRole': 'Passenger',
        'reason': 'Mudança de planos',
      });
      await tester.pump();
      await tester.pump();

      expect(
        find.text('A viagem foi cancelada pelo passageiro.'),
        findsWidgets,
      );
      expect(find.text('Motivo: Mudança de planos'), findsOneWidget);
      expect(find.text('Voltar para a tela inicial'), findsOneWidget);
      verifyNever(() => travelLocalRepository.clearTravels());
    },
  );

  testWidgets('TravelCancelled com travelId diferente → ignora', (
    tester,
  ) async {
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/'))
        return okResponse(passengerProfilePayload());
      return okResponse(travelPayload(status: 'Accepted'));
    });

    await pumpPage(tester, travelId: 'travel-1');

    travelCancelledController.add({'travelId': 'outro'});
    await tester.pump();
    await tester.pump();

    expect(find.text('Viagem cancelada pelo passageiro.'), findsNothing);
    verifyNever(() => travelLocalRepository.clearTravels());
  });

  testWidgets(
    'Completed direto do carregamento → estado terminal com "Voltar para a tela inicial"',
    (tester) async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => okResponse(travelPayload(status: 'Completed')));

      await pumpPage(tester);

      expect(find.text('Viagem concluída!'), findsOneWidget);

      await tester.tap(find.text('Voltar para a tela inicial'));
      await tester.pumpAndSettle();

      verify(() => travelLocalRepository.clearTravels()).called(1);
      verify(
        () => navigator.navigate('/home', arguments: any(named: 'arguments')),
      ).called(1);
    },
  );

  // ── Spec pickup-arrival-alerts (req 5.x) ─────────────────────────────

  group('indicação de proximidade do embarque', () {
    const nearbyText = 'Passageiro avisado: você está próximo';
    const arrivedText = 'Você chegou ao ponto de embarque';

    void stubTravel({String status = 'Accepted', String? pickupProximity}) {
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/')) {
          return okResponse(passengerProfilePayload());
        }
        return okResponse(
          travelPayload(status: status, pickupProximity: pickupProximity),
        );
      });
    }

    Map<String, dynamic> alert(String kind, {String travelId = 'travel-1'}) => {
      'travelId': travelId,
      'kind': kind,
      'occurredAt': '2026-10-02T15:00:00Z',
    };

    testWidgets('Accepted sem alerta não mostra indicação', (tester) async {
      stubTravel();

      await pumpPage(tester);

      expect(find.text(nearbyText), findsNothing);
      expect(find.text(arrivedText), findsNothing);
    });

    testWidgets('DriverNearby mostra que o passageiro foi avisado', (
      tester,
    ) async {
      stubTravel();
      await pumpPage(tester);

      driverNearbyController.add(alert('Nearby'));
      await tester.pump();
      await tester.pump();

      expect(find.text(nearbyText), findsOneWidget);
    });

    testWidgets('DriverArrived substitui a indicação de próximo', (
      tester,
    ) async {
      stubTravel();
      await pumpPage(tester);

      driverNearbyController.add(alert('Nearby'));
      await tester.pump();
      await tester.pump();
      driverArrivedController.add(alert('Arrived'));
      await tester.pump();
      await tester.pump();

      expect(find.text(arrivedText), findsOneWidget);
      expect(find.text(nearbyText), findsNothing);
    });

    testWidgets('Nearby atrasado não regride a indicação de chegada', (
      tester,
    ) async {
      stubTravel();
      await pumpPage(tester);

      driverArrivedController.add(alert('Arrived'));
      await tester.pump();
      await tester.pump();
      driverNearbyController.add(alert('Nearby'));
      await tester.pump();
      await tester.pump();

      expect(find.text(arrivedText), findsOneWidget);
      expect(find.text(nearbyText), findsNothing);
    });

    testWidgets('alerta de outra viagem é ignorado', (tester) async {
      stubTravel();
      await pumpPage(tester);

      driverArrivedController.add(alert('Arrived', travelId: 'outra'));
      await tester.pump();
      await tester.pump();

      expect(find.text(arrivedText), findsNothing);
    });

    testWidgets(
      'reabrir a tela em Accepted já com Arrived reidrata pela consulta da viagem',
      (
        tester,
      ) async {
        stubTravel(pickupProximity: 'Arrived');

        await pumpPage(tester);

        expect(find.text(arrivedText), findsOneWidget);
      },
    );

    testWidgets(
      'viagem InProgress não mostra indicação mesmo com marca residual',
      (
        tester,
      ) async {
        stubTravel(status: 'InProgress', pickupProximity: 'Arrived');

        await pumpPage(tester);

        expect(find.text(arrivedText), findsNothing);
        expect(find.text(nearbyText), findsNothing);
      },
    );

    testWidgets('iniciar a viagem limpa a indicação', (tester) async {
      var status = 'Accepted';
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/')) {
          return okResponse(passengerProfilePayload());
        }
        return okResponse(travelPayload(status: status));
      });
      when(() => signalRService.startTravel(any())).thenAnswer((_) async {
        status = 'InProgress';
      });
      await pumpPage(tester);
      driverArrivedController.add(alert('Arrived'));
      await tester.pump();
      await tester.pump();
      expect(find.text(arrivedText), findsOneWidget);

      await tester.tap(find.text('Iniciar viagem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(arrivedText), findsNothing);
    });

    testWidgets('ao reconectar o hub, reidrata a indicação perdida', (
      tester,
    ) async {
      var proximity = 'None';
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/')) {
          return okResponse(passengerProfilePayload());
        }
        return okResponse(travelPayload(pickupProximity: proximity));
      });
      await pumpPage(tester);
      expect(find.text(arrivedText), findsNothing);

      proximity = 'Arrived'; // alerta emitido enquanto o hub estava fora
      reconnectedController.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(arrivedText), findsOneWidget);
    });
  });

  // ── Spec pickup-chat-call (req 5.x, 6.1, 6.7) ────────────────────────

  group('chat e ligação no card', () {
    void stubTravel(String status, {String pickupProximity = 'None'}) {
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/')) {
          return okResponse(passengerProfilePayload());
        }
        return okResponse(
          travelPayload(status: status, pickupProximity: pickupProximity),
        );
      });
    }

    testWidgets('Accepted distante mostra apenas a ação de chat', (
      tester,
    ) async {
      stubTravel('Accepted');

      await pumpPage(tester);

      expect(find.byKey(const Key('call_passenger_button')), findsNothing);
      expect(find.byKey(const Key('chat_action_button')), findsOneWidget);
    });

    testWidgets('Accepted próximo mostra ligação e chat', (tester) async {
      stubTravel('Accepted', pickupProximity: 'Nearby');

      await pumpPage(tester);

      expect(find.byKey(const Key('call_passenger_button')), findsOneWidget);
      expect(find.byKey(const Key('chat_action_button')), findsOneWidget);
    });

    testWidgets('InProgress não mostra ligação nem chat', (tester) async {
      stubTravel('InProgress');

      await pumpPage(tester);

      expect(find.byKey(const Key('call_passenger_button')), findsNothing);
      expect(find.byKey(const Key('chat_action_button')), findsNothing);
    });

    testWidgets('iniciar a viagem remove a ligação e o chat', (tester) async {
      var status = 'Accepted';
      when(() => dio.get(any())).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.contains('/api/passengers/')) {
          return okResponse(passengerProfilePayload());
        }
        return okResponse(
          travelPayload(status: status, pickupProximity: 'Nearby'),
        );
      });
      when(() => signalRService.startTravel(any())).thenAnswer((_) async {
        status = 'InProgress';
      });
      await pumpPage(tester);
      expect(find.byKey(const Key('call_passenger_button')), findsOneWidget);

      await tester.tap(find.text('Iniciar viagem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('call_passenger_button')), findsNothing);
      expect(find.byKey(const Key('chat_action_button')), findsNothing);
    });

    testWidgets('a sessão de chat é iniciada em Accepted', (tester) async {
      stubTravel('Accepted');
      final session = buildQuietChatSession();
      addTearDown(session.stop);

      await pumpPage(tester, chatSession: session);

      expect(session.travelId, 'travel-1');
    });

    testWidgets('a sessão de chat não é iniciada fora de Accepted', (
      tester,
    ) async {
      stubTravel('InProgress');
      final session = buildQuietChatSession();
      addTearDown(session.stop);

      await pumpPage(tester, chatSession: session);

      expect(session.travelId, isNull);
    });

    testWidgets('o botão do card não repete a contagem do cabeçalho', (
      tester,
    ) async {
      stubTravel('Accepted');
      final session = buildQuietChatSession();
      addTearDown(session.stop);
      await pumpPage(tester, chatSession: session);

      session.unread.value = 3;
      await tester.pump();

      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Chat (3)'), findsNothing);
    });

    testWidgets('selo do chat aparece no cabeçalho e some após leitura', (
      tester,
    ) async {
      stubTravel('Accepted');
      final session = buildQuietChatSession();
      addTearDown(session.stop);
      await pumpPage(tester, chatSession: session);

      session.unread.value = 3;
      await tester.pump();

      expect(find.byKey(const Key('header-chat-button')), findsOneWidget);
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      final headerBadge = find.byKey(const Key('header-chat-unread-badge'));
      expect(
        find.descendant(of: headerBadge, matching: find.text('3')),
        findsOneWidget,
      );

      session.setChatOpen(true);
      await tester.pump();

      expect(find.byKey(const Key('header-chat-button')), findsNothing);
      expect(
        find.descendant(of: headerBadge, matching: find.text('3')),
        findsNothing,
      );
    });
  });
}
