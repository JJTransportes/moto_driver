// ChatSession (spec pickup-chat-call, req 4.2 a 4.5): selo de não lidas fora da
// conversa, recarga ao reconectar e ao voltar ao primeiro plano, e limpeza ao
// encerrar. Sem push: tudo dentro do app.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';
import 'package:result_dart/result_dart.dart';

import 'chat_test_doubles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoadChatHistoryUsecase load;
  late FakeChatRealtime realtime;
  late ChatSession session;

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  void stubUnread(int unread) {
    when(() => load(kTravelId)).thenAnswer(
      (_) async => Success(ChatHistoryEntity(messages: const [], unreadCount: unread)),
    );
  }

  setUp(() {
    load = MockLoadChatHistoryUsecase();
    realtime = FakeChatRealtime();
    session = ChatSession(load, realtime);
    stubUnread(0);
  });

  tearDown(() async {
    session.stop();
    await realtime.dispose();
  });

  test('começa sem não lidas', () {
    expect(session.unread.value, 0);
    expect(session.travelId, isNull);
  });

  test('start carrega as não lidas do servidor (app reaberto com mensagens pendentes)', () async {
    stubUnread(3);

    session.start(kTravelId);
    await settle();

    expect(session.unread.value, 3);
    expect(session.travelId, kTravelId);
  });

  test('mensagem recebida com o chat fechado incrementa o selo', () async {
    session.start(kTravelId);
    await settle();

    realtime.messages.add(realtimeMessage('m1', 'oi'));
    realtime.messages.add(realtimeMessage('m2', 'oi 2'));
    await settle();

    expect(session.unread.value, 2);
  });

  test('mensagem de outra viagem não conta', () async {
    session.start(kTravelId);
    await settle();

    realtime.messages.add(realtimeMessage('x', 'oi', travelId: 'outra'));
    await settle();

    expect(session.unread.value, 0);
  });

  test('abrir a conversa zera o selo e mensagens recebidas com ela aberta não contam', () async {
    stubUnread(2);
    session.start(kTravelId);
    await settle();
    expect(session.unread.value, 2);

    session.setChatOpen(true);
    expect(session.unread.value, 0);

    realtime.messages.add(realtimeMessage('m1', 'oi'));
    await settle();
    expect(session.unread.value, 0);
  });

  test('ao fechar a conversa, novas mensagens voltam a contar', () async {
    session.start(kTravelId);
    await settle();
    session.setChatOpen(true);
    session.setChatOpen(false);

    realtime.messages.add(realtimeMessage('m1', 'oi'));
    await settle();

    expect(session.unread.value, 1);
  });

  test('reconectar o hub recarrega a contagem pelo servidor', () async {
    session.start(kTravelId);
    await settle();

    stubUnread(4);
    realtime.reconnected.add(null);
    await settle();

    expect(session.unread.value, 4);
  });

  test('voltar ao primeiro plano recarrega a contagem', () async {
    session.start(kTravelId);
    await settle();

    stubUnread(5);
    session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();

    expect(session.unread.value, 5);
  });

  test('ChatClosed encerra a sessão e limpa o selo', () async {
    stubUnread(2);
    session.start(kTravelId);
    await settle();

    realtime.closed.add({'travelId': kTravelId});
    await settle();

    expect(session.unread.value, 0);
    expect(session.travelId, isNull);
  });

  test('viagem iniciada ou cancelada encerra a sessão mesmo sem ChatClosed', () async {
    stubUnread(2);
    session.start(kTravelId);
    await settle();

    realtime.travelEnded.add({'travelId': kTravelId});
    await settle();

    expect(session.unread.value, 0);
    expect(session.travelId, isNull);
  });

  test('stop limpa o selo e deixa de escutar', () async {
    stubUnread(2);
    session.start(kTravelId);
    await settle();

    session.stop();
    realtime.messages.add(realtimeMessage('m1', 'oi'));
    await settle();

    expect(session.unread.value, 0);
  });

  test('start é idempotente para a mesma viagem (não duplica a escuta)', () async {
    session.start(kTravelId);
    session.start(kTravelId);
    await settle();

    realtime.messages.add(realtimeMessage('m1', 'oi'));
    await settle();

    expect(session.unread.value, 1);
    verify(() => load(kTravelId)).called(1);
  });

  test('falha ao recarregar mantém o selo atual', () async {
    stubUnread(2);
    session.start(kTravelId);
    await settle();

    when(() => load(kTravelId)).thenAnswer((_) async => const Failure(NetworkException()));
    realtime.reconnected.add(null);
    await settle();

    expect(session.unread.value, 2);
  });

  test('resposta atrasada de uma viagem anterior é descartada', () async {
    stubUnread(9);
    session.start(kTravelId);
    session.stop(); // viagem acabou antes da resposta chegar
    await settle();

    expect(session.unread.value, 0);
  });
}
