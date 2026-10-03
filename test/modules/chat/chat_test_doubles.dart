import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_realtime_datasource.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/data/datasources/phone_dialer.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_get_passenger_phone_usecase.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';
import 'package:result_dart/result_dart.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_load_chat_history_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_mark_chat_read_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_send_chat_message_usecase.dart';

class MockSendChatMessageUsecase extends Mock implements ISendChatMessageUsecase {}

class MockLoadChatHistoryUsecase extends Mock implements ILoadChatHistoryUsecase {}

class MockMarkChatReadUsecase extends Mock implements IMarkChatReadUsecase {}

const kTravelId = 'travel-1';

ChatMessageEntity chatMessage(
  String id,
  String text, {
  bool mine = false,
  String travelId = kTravelId,
  String senderRole = 'Driver',
}) =>
    ChatMessageEntity(
      id: id,
      travelId: travelId,
      senderRole: senderRole,
      text: text,
      sentAt: DateTime.utc(2026, 10, 2, 15),
      mine: mine,
    );

Map<String, dynamic> realtimeMessage(
  String id,
  String text, {
  String travelId = kTravelId,
}) =>
    {
      'travelId': travelId,
      'messageId': id,
      'senderRole': 'Driver',
      'text': text,
      'sentAt': '2026-10-02T15:00:00Z',
    };

/// Eventos em tempo real controlados pelo teste.
class FakeChatRealtime implements IChatRealtimeDatasource {
  final messages = StreamController<Map<String, dynamic>>.broadcast();
  final closed = StreamController<Map<String, dynamic>>.broadcast();
  final travelEnded = StreamController<Map<String, dynamic>>.broadcast();
  final reconnected = StreamController<void>.broadcast();
  final reconnecting = StreamController<void>.broadcast();
  final connectionClosed = StreamController<void>.broadcast();

  @override
  bool isConnected = true;

  @override
  Stream<Map<String, dynamic>> get onMessageReceived => messages.stream;

  @override
  Stream<Map<String, dynamic>> get onChatClosed => closed.stream;

  @override
  Stream<Map<String, dynamic>> get onTravelEnded => travelEnded.stream;

  @override
  Stream<void> get onReconnected => reconnected.stream;

  @override
  Stream<void> get onReconnecting => reconnecting.stream;

  @override
  Stream<void> get onConnectionClosed => connectionClosed.stream;

  Future<void> dispose() async {
    await messages.close();
    await closed.close();
    await travelEnded.close();
    await reconnected.close();
    await reconnecting.close();
    await connectionClosed.close();
  }
}

class MockGetPassengerPhoneUsecase extends Mock implements IGetPassengerPhoneUsecase {}

class MockPhoneDialer extends Mock implements IPhoneDialer {}

/// Sessão de chat com histórico sempre vazio — para telas que só precisam dela montada.
ChatSession buildQuietChatSession() {
  final load = MockLoadChatHistoryUsecase();
  when(() => load(any())).thenAnswer(
    (_) async => const Success(ChatHistoryEntity(messages: [], unreadCount: 0)),
  );
  return ChatSession(load, FakeChatRealtime());
}
