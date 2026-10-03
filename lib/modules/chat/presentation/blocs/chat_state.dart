enum ChatItemStatus { sent, sending, failed }

/// Linha da conversa: mensagem do servidor ou mensagem local ainda sem confirmação.
class ChatItem {
  /// `messageId` do servidor, ou o `clientMessageId` enquanto não confirmada.
  final String id;
  final String clientMessageId;
  final String text;
  final bool mine;
  final DateTime sentAt;
  final ChatItemStatus status;

  const ChatItem({
    required this.id,
    required this.clientMessageId,
    required this.text,
    required this.mine,
    required this.sentAt,
    required this.status,
  });

  ChatItem copyWith({String? id, ChatItemStatus? status, DateTime? sentAt}) =>
      ChatItem(
        id: id ?? this.id,
        clientMessageId: clientMessageId,
        text: text,
        mine: mine,
        sentAt: sentAt ?? this.sentAt,
        status: status ?? this.status,
      );
}

sealed class ChatState {
  const ChatState();
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatReady extends ChatState {
  final List<ChatItem> items;

  /// Hub conectado. Sem conexão o envio fica desabilitado ("reconectando").
  final bool connected;

  /// Aviso transitório (ex.: falha de envio), em português.
  final String? notice;

  const ChatReady({required this.items, required this.connected, this.notice});

  ChatReady copyWith({
    List<ChatItem>? items,
    bool? connected,
    String? notice,
    bool clearNotice = false,
  }) =>
      ChatReady(
        items: items ?? this.items,
        connected: connected ?? this.connected,
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

class ChatFailure extends ChatState {
  final String message;
  const ChatFailure(this.message);
}

/// Chat encerrado: a tela fecha a conversa e avisa o usuário.
class ChatClosed extends ChatState {
  const ChatClosed();
}
