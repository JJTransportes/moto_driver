// ChatBloc (spec pickup-chat-call, req 2.x, 3.x, 6.x): histórico, envio com
// reenvio idempotente, recebimento em tempo real, reconexão e encerramento.
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_bloc.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_event.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_state.dart';
import 'package:result_dart/result_dart.dart';

import 'chat_test_doubles.dart';

void main() {
  late MockSendChatMessageUsecase send;
  late MockLoadChatHistoryUsecase load;
  late MockMarkChatReadUsecase markRead;
  late FakeChatRealtime realtime;

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

    when(() => load(kTravelId)).thenAnswer(
      (_) async => Success(ChatHistoryEntity(messages: [chatMessage('m1', 'oi')], unreadCount: 0)),
    );
    when(() => markRead(any())).thenAnswer((_) async => const Success(unit));
  });

  tearDown(() async => realtime.dispose());

  ChatBloc build() => ChatBloc(send, load, markRead, realtime);

  /// Inicia e espera a conversa ficar pronta.
  Future<void> start(ChatBloc bloc) async {
    bloc.add(const ChatStarted(kTravelId));
    await bloc.stream.firstWhere((s) => s is ChatReady || s is ChatClosed || s is ChatFailure);
  }

  group('início', () {
    blocTest<ChatBloc, ChatState>(
      'carrega o histórico e fica pronto com a conexão atual',
      build: build,
      act: (bloc) => bloc.add(const ChatStarted(kTravelId)),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatReady>()
            .having((s) => s.items.map((i) => i.text), 'textos', ['oi'])
            .having((s) => s.connected, 'connected', true)
            .having((s) => s.items.single.status, 'status', ChatItemStatus.sent),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'marca como lidas quando há não lidas',
      build: () {
        when(() => load(kTravelId)).thenAnswer(
          (_) async => Success(ChatHistoryEntity(messages: [chatMessage('m1', 'oi')], unreadCount: 1)),
        );
        return build();
      },
      act: (bloc) => bloc.add(const ChatStarted(kTravelId)),
      verify: (_) => verify(() => markRead(kTravelId)).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'sem não lidas não chama markRead',
      build: build,
      act: (bloc) => bloc.add(const ChatStarted(kTravelId)),
      verify: (_) => verifyNever(() => markRead(any())),
    );

    blocTest<ChatBloc, ChatState>(
      'falha ao carregar emite ChatFailure com a mensagem',
      build: () {
        when(() => load(kTravelId)).thenAnswer((_) async => const Failure(NetworkException()));
        return build();
      },
      act: (bloc) => bloc.add(const ChatStarted(kTravelId)),
      expect: () => [isA<ChatLoading>(), isA<ChatFailure>()],
    );

    blocTest<ChatBloc, ChatState>(
      'chat indisponível (409) ao carregar emite ChatClosed',
      build: () {
        when(() => load(kTravelId)).thenAnswer((_) async => const Failure(ConflictException()));
        return build();
      },
      act: (bloc) => bloc.add(const ChatStarted(kTravelId)),
      expect: () => [isA<ChatLoading>(), isA<ChatClosed>()],
    );
  });

  group('envio', () {
    blocTest<ChatBloc, ChatState>(
      'envia o texto aparado e confirma com o id do servidor',
      build: () {
        when(() => send(any())).thenAnswer(
          (inv) async => Success(chatMessage('srv-1', 'olá', mine: true, senderRole: 'Passenger')),
        );
        return build();
      },
      act: (bloc) async {
        await start(bloc);
        bloc.add(const ChatMessageSubmitted('  olá  '));
      },
      skip: 2,
      expect: () => [
        isA<ChatReady>().having((s) => s.items.last.status, 'status', ChatItemStatus.sending),
        isA<ChatReady>()
            .having((s) => s.items.last.status, 'status', ChatItemStatus.sent)
            .having((s) => s.items.last.id, 'id do servidor', 'srv-1'),
      ],
      verify: (_) {
        final params = verify(() => send(captureAny())).captured.single as SendChatMessageParams;
        expect(params.text, 'olá');
        expect(params.travelId, kTravelId);
        expect(params.clientMessageId, isNotEmpty);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'texto vazio ou só com espaços não envia',
      build: build,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const ChatMessageSubmitted('   '));
        bloc.add(const ChatMessageSubmitted(''));
      },
      skip: 2,
      expect: () => <ChatState>[],
      verify: (_) => verifyNever(() => send(any())),
    );

    blocTest<ChatBloc, ChatState>(
      'texto acima de 500 caracteres não envia',
      build: build,
      act: (bloc) async {
        await start(bloc);
        bloc.add(ChatMessageSubmitted('a' * (kChatMaxMessageLength + 1)));
      },
      skip: 2,
      expect: () => <ChatState>[],
      verify: (_) => verifyNever(() => send(any())),
    );

    blocTest<ChatBloc, ChatState>(
      'exatamente 500 caracteres é enviado',
      build: () {
        when(() => send(any())).thenAnswer(
          (_) async => Success(chatMessage('srv', 'a' * 500, mine: true)),
        );
        return build();
      },
      act: (bloc) async {
        await start(bloc);
        bloc.add(ChatMessageSubmitted('a' * kChatMaxMessageLength));
      },
      verify: (_) => verify(() => send(any())).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'sem conexão em tempo real não envia',
      build: () {
        realtime.isConnected = false;
        return build();
      },
      act: (bloc) async {
        await start(bloc);
        bloc.add(const ChatMessageSubmitted('oi'));
      },
      skip: 2,
      expect: () => <ChatState>[],
      verify: (_) => verifyNever(() => send(any())),
    );

    blocTest<ChatBloc, ChatState>(
      'falha de envio marca a mensagem como não enviada e avisa em português',
      build: () {
        when(() => send(any())).thenAnswer(
          (_) async => const Failure(ServerException('Não foi possível enviar a mensagem. Tente novamente.')),
        );
        return build();
      },
      act: (bloc) async {
        await start(bloc);
        bloc.add(const ChatMessageSubmitted('oi'));
      },
      skip: 3,
      expect: () => [
        isA<ChatReady>()
            .having((s) => s.items.last.status, 'status', ChatItemStatus.failed)
            .having((s) => s.items.last.text, 'texto preservado', 'oi')
            .having((s) => s.notice, 'aviso', 'Não foi possível enviar a mensagem. Tente novamente.'),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'reenviar usa o MESMO clientMessageId (sem duplicar no servidor)',
      build: () {
        var attempts = 0;
        when(() => send(any())).thenAnswer((_) async {
          attempts++;
          return attempts == 1
              ? const Failure(NetworkException())
              : Success(chatMessage('srv-1', 'oi', mine: true));
        });
        return build();
      },
      act: (bloc) async {
        await start(bloc);
        bloc.add(const ChatMessageSubmitted('oi'));
        final failed = await bloc.stream.firstWhere(
          (s) => s is ChatReady && s.items.last.status == ChatItemStatus.failed,
        ) as ChatReady;
        bloc.add(ChatSendRetried(failed.items.last.clientMessageId));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        final calls = verify(() => send(captureAny())).captured.cast<SendChatMessageParams>();
        expect(calls, hasLength(2));
        expect(calls[0].clientMessageId, calls[1].clientMessageId);
        final state = bloc.state as ChatReady;
        expect(state.items.where((i) => i.text == 'oi'), hasLength(2)); // 1 do histórico + 1 enviada
        expect(state.items.last.status, ChatItemStatus.sent);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'chat encerrado durante o envio (409) emite ChatClosed',
      build: () {
        when(() => send(any())).thenAnswer((_) async => const Failure(ConflictException()));
        return build();
      },
      act: (bloc) async {
        await start(bloc);
        bloc.add(const ChatMessageSubmitted('oi'));
      },
      skip: 3,
      expect: () => [isA<ChatClosed>()],
    );
  });

  group('tempo real', () {
    blocTest<ChatBloc, ChatState>(
      'mensagem recebida entra ao fim da conversa e é marcada como lida',
      build: build,
      act: (bloc) async {
        await start(bloc);
        realtime.messages.add(realtimeMessage('m2', 'cheguei'));
      },
      wait: const Duration(milliseconds: 50),
      skip: 2,
      expect: () => [
        isA<ChatReady>()
            .having((s) => s.items.map((i) => i.text), 'textos', ['oi', 'cheguei'])
            .having((s) => s.items.last.mine, 'mine', false),
      ],
      verify: (_) => verify(() => markRead(kTravelId)).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'mensagem repetida não duplica',
      build: build,
      act: (bloc) async {
        await start(bloc);
        realtime.messages
          ..add(realtimeMessage('m2', 'cheguei'))
          ..add(realtimeMessage('m2', 'cheguei'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect((bloc.state as ChatReady).items, hasLength(2)),
    );

    blocTest<ChatBloc, ChatState>(
      'mensagem de outra viagem é ignorada',
      build: build,
      act: (bloc) async {
        await start(bloc);
        realtime.messages.add(realtimeMessage('x', 'outra', travelId: 'outra-viagem'));
      },
      wait: const Duration(milliseconds: 50),
      skip: 2,
      expect: () => <ChatState>[],
    );

    blocTest<ChatBloc, ChatState>(
      'perder a conexão indica reconectando e recuperar recarrega o histórico',
      build: build,
      act: (bloc) async {
        await start(bloc);
        realtime.reconnecting.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        realtime.isConnected = true;
        realtime.reconnected.add(null);
      },
      wait: const Duration(milliseconds: 80),
      verify: (bloc) {
        expect((bloc.state as ChatReady).connected, isTrue);
        verify(() => load(kTravelId)).called(2); // início + recuperação
      },
    );

    blocTest<ChatBloc, ChatState>(
      'conexão encerrada marca desconectado',
      build: build,
      act: (bloc) async {
        await start(bloc);
        realtime.connectionClosed.add(null);
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect((bloc.state as ChatReady).connected, isFalse),
    );
  });

  group('encerramento', () {
    blocTest<ChatBloc, ChatState>(
      'ChatClosed do backend emite ChatClosed',
      build: build,
      act: (bloc) async {
        await start(bloc);
        realtime.closed.add({'travelId': kTravelId});
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state, isA<ChatClosed>()),
    );

    blocTest<ChatBloc, ChatState>(
      'viagem iniciada, cancelada ou concluída também encerra, mesmo sem ChatClosed',
      build: build,
      act: (bloc) async {
        await start(bloc);
        realtime.travelEnded.add({'travelId': kTravelId});
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state, isA<ChatClosed>()),
    );

    blocTest<ChatBloc, ChatState>(
      'encerramento de outra viagem é ignorado',
      build: build,
      act: (bloc) async {
        await start(bloc);
        realtime.closed.add({'travelId': 'outra'});
        realtime.travelEnded.add({'travelId': 'outra'});
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state, isA<ChatReady>()),
    );
  });
}
