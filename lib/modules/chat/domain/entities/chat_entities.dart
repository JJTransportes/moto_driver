/// Mensagem do chat temporário da viagem (spec pickup-chat-call).
class ChatMessageEntity {
  final String id;
  final String travelId;

  /// `Driver` ou `Passenger`.
  final String senderRole;
  final String text;
  final DateTime sentAt;

  /// Se a mensagem é do próprio usuário.
  final bool mine;

  const ChatMessageEntity({
    required this.id,
    required this.travelId,
    required this.senderRole,
    required this.text,
    required this.sentAt,
    required this.mine,
  });
}

class ChatHistoryEntity {
  final List<ChatMessageEntity> messages;
  final int unreadCount;

  const ChatHistoryEntity({required this.messages, required this.unreadCount});
}

/// Parâmetros de envio. O [clientMessageId] identifica a mensagem: reenviar
/// com o mesmo id não duplica no servidor.
class SendChatMessageParams {
  final String travelId;
  final String text;
  final String clientMessageId;

  const SendChatMessageParams({
    required this.travelId,
    required this.text,
    required this.clientMessageId,
  });
}

/// Tamanho máximo de uma mensagem, igual ao do backend.
const int kChatMaxMessageLength = 500;

/// Contato do passageiro da viagem em `Accepted`. [phone] é nulo quando o
/// passageiro não cadastrou telefone. Nunca é guardado nem registrado em log.
class PassengerContactEntity {
  final String? phone;

  const PassengerContactEntity({this.phone});
}
