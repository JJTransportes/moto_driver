import 'package:moto_driver/modules/chat/data/datasources/i_chat_datasource.dart';
import 'package:moto_driver/modules/chat/data/repositories/i_chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:result_dart/result_dart.dart';

class ChatRepository implements IChatRepository {
  final IChatDatasource _datasource;

  ChatRepository(this._datasource);

  @override
  Future<Result<ChatMessageEntity>> sendMessage(
    SendChatMessageParams params,
  ) async {
    try {
      final json = await _datasource.sendMessage(
        params.travelId,
        params.text,
        params.clientMessageId,
      );
      return Success(chatMessageFromJson(json));
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<ChatHistoryEntity>> loadHistory(String travelId) async {
    try {
      final json = await _datasource.getHistory(travelId);
      final messages = (json['messages'] as List<dynamic>? ?? [])
          .map((m) => chatMessageFromJson(m as Map<String, dynamic>))
          .toList();
      return Success(
        ChatHistoryEntity(
          messages: messages,
          unreadCount: json['unreadCount'] as int? ?? 0,
        ),
      );
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<void>> markRead(String travelId) async {
    try {
      await _datasource.markRead(travelId);
      return const Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<PassengerContactEntity>> getPassengerContact(String travelId) async {
    try {
      final json = await _datasource.getPassengerContact(travelId);
      final phone = (json['phone'] as String?)?.trim();
      return Success(
        PassengerContactEntity(phone: phone == null || phone.isEmpty ? null : phone),
      );
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}

/// Converte a mensagem do backend. Funciona também para o evento em tempo real
/// (`ChatMessageReceived`), que não traz `mine` (é sempre do outro lado).
ChatMessageEntity chatMessageFromJson(Map<String, dynamic> json) {
  return ChatMessageEntity(
    id: json['messageId'] as String,
    travelId: json['travelId'] as String,
    senderRole: json['senderRole'] as String? ?? '',
    text: json['text'] as String? ?? '',
    sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ?? DateTime.now(),
    mine: json['mine'] as bool? ?? false,
  );
}
