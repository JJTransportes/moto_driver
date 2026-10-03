// ChatPage e ChatActionButton (spec pickup-chat-call, req 6.x): conversa, envio,
// reenvio, indicação de reconexão, encerramento e selo de não lidas no card.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_bloc.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_event.dart';
import 'package:moto_driver/modules/chat/presentation/pages/chat_page.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';
import 'package:moto_driver/modules/chat/presentation/widgets/chat_action_button.dart';
import 'package:result_dart/result_dart.dart';

import 'chat_test_doubles.dart';

class MockModularNavigator extends Mock implements IModularNavigator {}

class _EmptyModule extends Module {}

void main() {
  late MockSendChatMessageUsecase send;
  late MockLoadChatHistoryUsecase load;
  late MockMarkChatReadUsecase markRead;
  late FakeChatRealtime realtime;
  late ChatSession session;
  late MockModularNavigator navigator;

  setUpAll(() {
    registerFallbackValue(
      const SendChatMessageParams(travelId: 't', text: 'x', clientMessageId: 'c'),
    );
  });

  setUp(() {
    send = MockSendChatMessageUsecase();
    load = MockLoadChatHistoryUsecase();
    markRead = MockMarkChatReadUsecase();
    realtime = FakeChatRealtime();
    session = ChatSession(load, realtime);
    navigator = MockModularNavigator();

    when(() => load(kTravelId)).thenAnswer(
      (_) async => Success(
        ChatHistoryEntity(
          messages: [
            chatMessage('m1', 'Estou na portaria'),
            chatMessage('m2', 'Já estou descendo', mine: true, senderRole: 'Passenger'),
          ],
          unreadCount: 0,
        ),
      ),
    );
    when(() => markRead(any())).thenAnswer((_) async => const Success(unit));
    when(() => navigator.pop()).thenReturn(null);

    Modular.init(_EmptyModule());
    Modular.navigatorDelegate = navigator;
  });

  tearDown(() async {
    Modular.navigatorDelegate = null;
    try {
      Modular.destroy();
    } catch (_) {}
    session.stop();
    await realtime.dispose();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MotoTheme.claro(),
        home: BlocProvider<ChatBloc>(
          create: (_) => ChatBloc(send, load, markRead, realtime)..add(const ChatStarted(kTravelId)),
          child: ChatPage(
            travelId: kTravelId,
            title: 'Chat com o passageiro',
            session: session,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('mostra o título, o histórico e o campo de mensagem', (tester) async {
    await pumpPage(tester);

    expect(find.text('Chat com o passageiro'), findsOneWidget);
    expect(find.text('Estou na portaria'), findsOneWidget);
    expect(find.text('Já estou descendo'), findsOneWidget);
    expect(find.byKey(const Key('chat_input')), findsOneWidget);
    expect(find.byKey(const Key('chat_send_button')), findsOneWidget);
  });

  testWidgets('abrir a conversa zera o selo de não lidas da sessão', (tester) async {
    session.unread.value = 3;

    await pumpPage(tester);

    expect(session.unread.value, 0);
  });

  testWidgets('botão de enviar fica desabilitado com o campo vazio', (tester) async {
    await pumpPage(tester);

    final button = tester.widget<IconButton>(find.byKey(const Key('chat_send_button')));
    expect(button.onPressed, isNull);
  });

  testWidgets('digitar habilita o envio, enviar limpa o campo e mostra a mensagem', (tester) async {
    when(() => send(any())).thenAnswer(
      (_) async => Success(chatMessage('srv', 'Vou até a recepção', mine: true, senderRole: 'Passenger')),
    );
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('chat_input')), 'Vou até a recepção');
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byKey(const Key('chat_send_button'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Vou até a recepção'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('chat_input'))).controller!.text, isEmpty);
    verify(() => send(any())).called(1);
  });

  testWidgets('o campo limita a mensagem a 500 caracteres', (tester) async {
    await pumpPage(tester);

    final field = tester.widget<TextField>(find.byKey(const Key('chat_input')));

    expect(field.maxLength, kChatMaxMessageLength);
    expect(kChatMaxMessageLength, 500);
  });

  testWidgets('mensagem recebida em tempo real aparece ao fim da conversa', (tester) async {
    await pumpPage(tester);

    realtime.messages.add(realtimeMessage('m3', 'Cheguei no portão'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Cheguei no portão'), findsOneWidget);
  });

  testWidgets('falha de envio mostra "Não enviada" e permite reenviar sem perder o texto', (tester) async {
    var attempts = 0;
    when(() => send(any())).thenAnswer((_) async {
      attempts++;
      return attempts == 1
          ? const Failure(ServerException('Não foi possível enviar a mensagem. Tente novamente.'))
          : Success(chatMessage('srv', 'Texto que não pode sumir', mine: true));
    });
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('chat_input')), 'Texto que não pode sumir');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Texto que não pode sumir'), findsOneWidget);
    expect(find.byKey(const Key('chat_retry')), findsOneWidget);
    expect(find.text('Não foi possível enviar a mensagem. Tente novamente.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat_retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('chat_retry')), findsNothing);
    expect(attempts, 2);
  });

  testWidgets('sem conexão mostra "reconectando" e desabilita o envio', (tester) async {
    await pumpPage(tester);

    realtime.reconnecting.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byKey(const Key('chat_input')), 'oi');
    await tester.pump();

    expect(find.byKey(const Key('chat_reconnecting_banner')), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('chat_send_button'))).onPressed,
      isNull,
    );
  });

  testWidgets('ao reconectar o aviso some e o envio volta', (tester) async {
    await pumpPage(tester);
    realtime.reconnecting.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    realtime.reconnected.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const Key('chat_input')), 'oi');
    await tester.pump();

    expect(find.byKey(const Key('chat_reconnecting_banner')), findsNothing);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('chat_send_button'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('chat encerrado fecha a conversa e avisa em português', (tester) async {
    await pumpPage(tester);

    realtime.closed.add({'travelId': kTravelId});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('O chat foi encerrado.'), findsOneWidget);
    verify(() => navigator.pop()).called(1);
  });

  testWidgets('viagem iniciada fecha a conversa mesmo sem ChatClosed', (tester) async {
    await pumpPage(tester);

    realtime.travelEnded.add({'travelId': kTravelId});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verify(() => navigator.pop()).called(1);
  });

  testWidgets('falha ao carregar mostra a mensagem e "Tentar novamente"', (tester) async {
    when(() => load(kTravelId)).thenAnswer((_) async => const Failure(NetworkException()));

    await pumpPage(tester);

    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  group('ChatActionButton', () {
    Future<void> pumpButton(WidgetTester tester, VoidCallback onPressed) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MotoTheme.claro(),
          home: Scaffold(
            body: ChatActionButton(session: session, onPressed: onPressed, label: 'Chat com o passageiro'),
          ),
        ),
      );
    }

    testWidgets('sem não lidas mostra só o rótulo', (tester) async {
      await pumpButton(tester, () {});

      expect(find.text('Chat com o passageiro'), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('com não lidas mostra o selo e a contagem', (tester) async {
      session.unread.value = 2;
      await pumpButton(tester, () {});

      expect(find.text('Chat com o passageiro (2)'), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    });

    testWidgets('o selo acompanha a sessão', (tester) async {
      await pumpButton(tester, () {});

      session.unread.value = 5;
      await tester.pump();

      expect(find.text('Chat com o passageiro (5)'), findsOneWidget);
    });

    testWidgets('acima de 99 mostra 99+', (tester) async {
      session.unread.value = 150;
      await pumpButton(tester, () {});

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('toque chama a ação', (tester) async {
      var taps = 0;
      await pumpButton(tester, () => taps++);

      await tester.tap(find.byKey(const Key('chat_action_button')));

      expect(taps, 1);
    });
  });
}
