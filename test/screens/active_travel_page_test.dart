import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/screens/active_travel_page.dart';

import '../helpers/active_travel_test_utils.dart';

void main() {
  late MockDio dio;
  late MockAuthStorage authStorage;
  late MockSignalRService signalRService;
  late MockTravelLocalRepository travelLocalRepository;
  late MockLocationService locationService;
  late MockModularNavigator navigator;
  late StreamController<Map<String, dynamic>> travelCancelledController;

  setUp(() {
    dio = MockDio();
    authStorage = MockAuthStorage();
    signalRService = MockSignalRService();
    travelLocalRepository = MockTravelLocalRepository();
    locationService = MockLocationService();
    navigator = MockModularNavigator();
    travelCancelledController = StreamController<Map<String, dynamic>>.broadcast();

    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsPlatform();

    when(() => authStorage.getToken()).thenAnswer((_) async => 'token');
    when(() => signalRService.onTravelCancelled).thenAnswer((_) => travelCancelledController.stream);
    when(() => signalRService.isConnected(any())).thenReturn(true);
    when(() => signalRService.connect(any(), any(), any())).thenAnswer((_) async {});
    when(() => signalRService.updateLocation(any(), any(), any())).thenAnswer((_) async {});
    when(() => signalRService.startTravel(any())).thenAnswer((_) async {});
    when(() => signalRService.finishTravel(any(), latitude: any(named: 'latitude'), longitude: any(named: 'longitude')))
        .thenAnswer((_) async {});
    when(() => travelLocalRepository.clearTravels()).thenAnswer((_) async {});
    when(() => locationService.getCurrentPosition())
        .thenAnswer((_) async => const LocationResult(status: LocationStatus.denied));
    when(() => navigator.navigate(any(), arguments: any(named: 'arguments'))).thenReturn(null);
  });

  tearDown(() async {
    await travelCancelledController.close();
  });

  ActiveTravelTestModule buildModule() => ActiveTravelTestModule(
        dio: dio,
        authStorage: authStorage,
        signalRService: signalRService,
        travelLocalRepository: travelLocalRepository,
        locationService: locationService,
      );

  Future<void> pumpPage(WidgetTester tester, {String travelId = 'travel-1'}) async {
    initTestModule(buildModule(), navigator);
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

  testWidgets('Accepted → mostra "A caminho do passageiro" e "Iniciar Viagem"', (tester) async {
    when(() => dio.get(any())).thenAnswer((_) async => okResponse(travelPayload(status: 'Accepted')));
    when(() => dio.get('/api/passengers/passenger-1')).thenAnswer((_) async => okResponse(passengerProfilePayload()));

    await pumpPage(tester);

    expect(find.text('A caminho do passageiro'), findsOneWidget);
    expect(find.text('Aceita · aguardando'), findsOneWidget);
    expect(find.text('Iniciar viagem'), findsOneWidget);
    expect(find.text('Maria Passageira'), findsOneWidget);
  });

  testWidgets('InProgress → mostra "Viagem em andamento" e "Finalizar Viagem"', (tester) async {
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/')) return okResponse(passengerProfilePayload());
      return okResponse(travelPayload(status: 'InProgress'));
    });

    await pumpPage(tester);

    expect(find.text('Viagem em andamento'), findsOneWidget);
    expect(find.text('Deslize para finalizar'), findsOneWidget);
  });

  testWidgets('erro ao carregar → mostra mensagem + "Tentar novamente" recarrega', (tester) async {
    when(() => dio.get(any())).thenThrow(
      DioException(requestOptions: RequestOptions(path: '')),
    );

    await pumpPage(tester);

    expect(find.text('Erro ao carregar viagem'), findsOneWidget);

    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/')) return okResponse(passengerProfilePayload());
      return okResponse(travelPayload(status: 'Accepted'));
    });
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('A caminho do passageiro'), findsOneWidget);
  });

  testWidgets('tap "Iniciar Viagem" → chama signalR.startTravel e recarrega como InProgress', (tester) async {
    var status = 'Accepted';
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/')) return okResponse(passengerProfilePayload());
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
  });

  testWidgets('tap "Finalizar Viagem" → confirma → chama signalR.finishTravel e recarrega como Completed', (tester) async {
    var status = 'InProgress';
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/')) return okResponse(passengerProfilePayload());
      return okResponse(travelPayload(status: status));
    });
    when(() => signalRService.finishTravel(any(), latitude: any(named: 'latitude'), longitude: any(named: 'longitude')))
        .thenAnswer((_) async {
      status = 'Completed';
    });

    await pumpPage(tester);
    expect(find.text('Deslize para finalizar'), findsOneWidget);

    // MotoSwipeToConfirm não tem botão tocável — arrasta o "puxador" (ícone
    // chevron) até o fim da trilha pra disparar onConfirmed, como o gesto
    // real do usuário.
    await tester.drag(find.byIcon(Icons.chevron_right_rounded), const Offset(700, 0));
    await tester.pump();
    expect(find.text('Tem certeza que deseja finalizar esta viagem?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sim, finalizar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    verify(() => signalRService.finishTravel('travel-1', latitude: any(named: 'latitude'), longitude: any(named: 'longitude')))
        .called(1);
    expect(find.text('Viagem concluída!'), findsOneWidget);
  });

  testWidgets('tap "Cancelar" → confirma → POST cancel e recarrega como Cancelled', (tester) async {
    var status = 'Accepted';
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/')) return okResponse(passengerProfilePayload());
      return okResponse(travelPayload(status: status));
    });
    when(() => dio.post(any())).thenAnswer((_) async {
      status = 'Cancelled';
      return okResponse(const {});
    });

    await pumpPage(tester);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Tem certeza que deseja cancelar esta viagem?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sim, cancelar'));
    await tester.pumpAndSettle();

    verify(() => dio.post(any())).called(1);
    // Aparece 2x: no título do AppBar (_statusLabel()) e no corpo do estado terminal.
    expect(find.text('Viagem cancelada'), findsWidgets);
    expect(find.text('Voltar para Home'), findsOneWidget);
  });

  testWidgets('TravelCancelled via SignalR (mesmo travelId) → snackbar + volta pra Home', (tester) async {
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/')) return okResponse(passengerProfilePayload());
      return okResponse(travelPayload(status: 'Accepted'));
    });

    await pumpPage(tester, travelId: 'travel-1');

    travelCancelledController.add({'travelId': 'travel-1'});
    await tester.pump();
    await tester.pump();

    expect(find.text('Viagem cancelada pelo passageiro.'), findsOneWidget);
    verify(() => travelLocalRepository.clearTravels()).called(1);
    verify(() => navigator.navigate('/home', arguments: any(named: 'arguments'))).called(1);
  });

  testWidgets('TravelCancelled com travelId diferente → ignora', (tester) async {
    when(() => dio.get(any())).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.contains('/api/passengers/')) return okResponse(passengerProfilePayload());
      return okResponse(travelPayload(status: 'Accepted'));
    });

    await pumpPage(tester, travelId: 'travel-1');

    travelCancelledController.add({'travelId': 'outro'});
    await tester.pump();
    await tester.pump();

    expect(find.text('Viagem cancelada pelo passageiro.'), findsNothing);
    verifyNever(() => travelLocalRepository.clearTravels());
  });

  testWidgets('Completed direto do carregamento → estado terminal com "Voltar para Home"', (tester) async {
    when(() => dio.get(any())).thenAnswer((_) async => okResponse(travelPayload(status: 'Completed')));

    await pumpPage(tester);

    expect(find.text('Viagem concluída!'), findsOneWidget);

    await tester.tap(find.text('Voltar para Home'));
    await tester.pumpAndSettle();

    verify(() => travelLocalRepository.clearTravels()).called(1);
    verify(() => navigator.navigate('/home', arguments: any(named: 'arguments'))).called(1);
  });
}
