// Ligação do motorista ao passageiro (spec pickup-chat-call, req 5.x): contato
// só em Accepted, discador sem iniciar a chamada, modal sem telefone com as
// ações "Abrir chat" e "Fechar", ícone sempre visível.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/chat/data/datasources/chat_datasource.dart';
import 'package:moto_driver/modules/chat/data/datasources/phone_dialer.dart';
import 'package:moto_driver/modules/chat/data/repositories/chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/domain/usecases/get_passenger_phone_usecase.dart';
import 'package:moto_driver/modules/chat/presentation/widgets/call_passenger_button.dart';
import 'package:result_dart/result_dart.dart';

import 'chat_data_layer_test.dart' show MockChatDatasource, MockChatRepository, MockDio;
import 'chat_test_doubles.dart';

void main() {
  group('camada de dados do contato', () {
    test('datasource faz GET de passenger-contact', () async {
      final dio = MockDio();
      when(() => dio.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {'phone': '+5512999887766'},
        ),
      );

      final json = await ChatDatasource(dio).getPassengerContact('travel-1');

      expect(json['phone'], '+5512999887766');
      verify(() => dio.get('/api/travels/travel-1/passenger-contact')).called(1);
    });

    test('datasource: 403 e 409 viram exceções tipadas', () async {
      final dio = MockDio();
      for (final entry in {403: isA<ForbiddenException>(), 409: isA<ConflictException>()}.entries) {
        when(() => dio.get(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(requestOptions: RequestOptions(path: ''), statusCode: entry.key),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          () => ChatDatasource(dio).getPassengerContact('t'),
          throwsA(entry.value),
        );
      }
    });

    test('repositório devolve o telefone aparado', () async {
      final datasource = MockChatDatasource();
      when(() => datasource.getPassengerContact(any()))
          .thenAnswer((_) async => {'phone': '  +5512999887766  '});

      final result = await ChatRepository(datasource).getPassengerContact('t');

      expect(result.getOrNull()!.phone, '+5512999887766');
    });

    test('repositório trata telefone nulo ou em branco como ausente', () async {
      final datasource = MockChatDatasource();
      when(() => datasource.getPassengerContact('nulo')).thenAnswer((_) async => {'phone': null});
      when(() => datasource.getPassengerContact('branco')).thenAnswer((_) async => {'phone': '   '});

      final repository = ChatRepository(datasource);

      expect((await repository.getPassengerContact('nulo')).getOrNull()!.phone, isNull);
      expect((await repository.getPassengerContact('branco')).getOrNull()!.phone, isNull);
    });

    test('repositório devolve Failure quando o datasource lança', () async {
      final datasource = MockChatDatasource();
      when(() => datasource.getPassengerContact(any())).thenThrow(const ConflictException());

      final result = await ChatRepository(datasource).getPassengerContact('t');

      expect(result.exceptionOrNull(), isA<ConflictException>());
    });

    test('caso de uso delega ao repositório', () async {
      final repository = MockChatRepository();
      when(() => repository.getPassengerContact('t'))
          .thenAnswer((_) async => const Success(PassengerContactEntity(phone: '123')));

      final result = await GetPassengerPhoneUsecase(repository)('t');

      expect(result.getOrNull()!.phone, '123');
    });
  });

  group('sanitizePhone', () {
    test('mantém o + inicial e só dígitos', () {
      expect(sanitizePhone('+55 (12) 99988-7766'), '+5512999887766');
      expect(sanitizePhone('(12) 99988-7766'), '12999887766');
      expect(sanitizePhone('  12999887766 '), '12999887766');
    });

    test('devolve nulo quando não há dígitos', () {
      expect(sanitizePhone(''), isNull);
      expect(sanitizePhone('   '), isNull);
      expect(sanitizePhone('abc'), isNull);
      expect(sanitizePhone('+'), isNull);
    });
  });

  group('CallPassengerButton', () {
    late MockGetPassengerPhoneUsecase getPhone;
    late MockPhoneDialer dialer;
    late int chatOpened;

    setUp(() {
      getPhone = MockGetPassengerPhoneUsecase();
      dialer = MockPhoneDialer();
      chatOpened = 0;
      when(() => dialer.dial(any())).thenAnswer((_) async => true);
    });

    Future<void> pumpButton(WidgetTester tester) => tester.pumpWidget(
          MaterialApp(
            theme: MotoTheme.claro(),
            home: Scaffold(
              body: CallPassengerButton(
                travelId: kTravelId,
                getPassengerPhone: getPhone,
                dialer: dialer,
                onOpenChat: () => chatOpened++,
              ),
            ),
          ),
        );

    Future<void> tap(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('call_passenger_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('o ícone de ligação está visível', (tester) async {
      await pumpButton(tester);

      expect(find.byKey(const Key('call_passenger_button')), findsOneWidget);
      expect(find.byIcon(Icons.call), findsOneWidget);
    });

    testWidgets('com telefone abre o discador com o número, sem modal', (tester) async {
      when(() => getPhone(kTravelId))
          .thenAnswer((_) async => const Success(PassengerContactEntity(phone: '+5512999887766')));
      await pumpButton(tester);

      await tap(tester);

      verify(() => dialer.dial('+5512999887766')).called(1);
      expect(find.byKey(const Key('missing_phone_dialog')), findsNothing);
    });

    testWidgets('busca o telefone a cada toque (não o guarda)', (tester) async {
      when(() => getPhone(kTravelId))
          .thenAnswer((_) async => const Success(PassengerContactEntity(phone: '+5512999887766')));
      await pumpButton(tester);

      await tap(tester);
      await tap(tester);

      verify(() => getPhone(kTravelId)).called(2);
    });

    testWidgets('sem telefone abre o modal em português e não abre o discador', (tester) async {
      when(() => getPhone(kTravelId))
          .thenAnswer((_) async => const Success(PassengerContactEntity()));
      await pumpButton(tester);

      await tap(tester);

      expect(find.byKey(const Key('missing_phone_dialog')), findsOneWidget);
      expect(find.text('Passageiro sem telefone'), findsOneWidget);
      expect(find.textContaining('pelo chat'), findsOneWidget);
      expect(find.text('Abrir chat'), findsOneWidget);
      expect(find.text('Fechar'), findsOneWidget);
      verifyNever(() => dialer.dial(any()));
    });

    testWidgets('telefone só com símbolos também é tratado como ausente', (tester) async {
      when(() => getPhone(kTravelId))
          .thenAnswer((_) async => const Success(PassengerContactEntity(phone: '---')));
      await pumpButton(tester);

      await tap(tester);

      expect(find.byKey(const Key('missing_phone_dialog')), findsOneWidget);
      verifyNever(() => dialer.dial(any()));
    });

    testWidgets('"Abrir chat" no modal fecha o modal e abre o chat', (tester) async {
      when(() => getPhone(kTravelId))
          .thenAnswer((_) async => const Success(PassengerContactEntity()));
      await pumpButton(tester);
      await tap(tester);

      await tester.tap(find.byKey(const Key('missing_phone_open_chat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(chatOpened, 1);
      expect(find.byKey(const Key('missing_phone_dialog')), findsNothing);
      verifyNever(() => dialer.dial(any()));
    });

    testWidgets('"Fechar" no modal só fecha, sem abrir chat nem discador', (tester) async {
      when(() => getPhone(kTravelId))
          .thenAnswer((_) async => const Success(PassengerContactEntity()));
      await pumpButton(tester);
      await tap(tester);

      await tester.tap(find.byKey(const Key('missing_phone_close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(chatOpened, 0);
      expect(find.byKey(const Key('missing_phone_dialog')), findsNothing);
      verifyNever(() => dialer.dial(any()));
    });

    testWidgets('o ícone continua visível depois do modal (viagem ainda em Accepted)', (tester) async {
      when(() => getPhone(kTravelId))
          .thenAnswer((_) async => const Success(PassengerContactEntity()));
      await pumpButton(tester);
      await tap(tester);
      await tester.tap(find.byKey(const Key('missing_phone_close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('call_passenger_button')), findsOneWidget);
    });

    testWidgets('viagem fora de Accepted (409) avisa que a ligação não está disponível', (tester) async {
      when(() => getPhone(kTravelId)).thenAnswer((_) async => const Failure(ConflictException()));
      await pumpButton(tester);

      await tap(tester);

      expect(find.text('A ligação não está mais disponível para esta viagem.'), findsOneWidget);
      expect(find.byKey(const Key('missing_phone_dialog')), findsNothing);
      verifyNever(() => dialer.dial(any()));
    });

    testWidgets('falha de rede avisa e permite tentar de novo', (tester) async {
      var attempts = 0;
      when(() => getPhone(kTravelId)).thenAnswer((_) async {
        attempts++;
        return attempts == 1
            ? const Failure(NetworkException())
            : const Success(PassengerContactEntity(phone: '+5512999887766'));
      });
      await pumpButton(tester);

      await tap(tester);
      expect(find.text('Não foi possível obter o telefone. Tente novamente.'), findsOneWidget);
      verifyNever(() => dialer.dial(any()));

      await tap(tester);
      verify(() => dialer.dial('+5512999887766')).called(1);
    });

    testWidgets('discador indisponível avisa o motorista', (tester) async {
      when(() => getPhone(kTravelId))
          .thenAnswer((_) async => const Success(PassengerContactEntity(phone: '+5512999887766')));
      when(() => dialer.dial(any())).thenAnswer((_) async => false);
      await pumpButton(tester);

      await tap(tester);

      expect(find.text('Não foi possível abrir o discador.'), findsOneWidget);
    });

    testWidgets('segundo toque durante a busca é ignorado (sem chamadas duplicadas)', (tester) async {
      final pending = Future<Result<PassengerContactEntity>>.delayed(
        const Duration(milliseconds: 200),
        () => const Success(PassengerContactEntity(phone: '+5512999887766')),
      );
      when(() => getPhone(kTravelId)).thenAnswer((_) => pending);
      await pumpButton(tester);

      await tester.tap(find.byKey(const Key('call_passenger_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('call_passenger_button')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => getPhone(kTravelId)).called(1);
      verify(() => dialer.dial('+5512999887766')).called(1);
    });
  });
}
