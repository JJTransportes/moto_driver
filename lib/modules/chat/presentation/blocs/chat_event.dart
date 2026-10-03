sealed class ChatEvent {
  const ChatEvent();
}

class ChatStarted extends ChatEvent {
  final String travelId;
  const ChatStarted(this.travelId);
}

class ChatMessageSubmitted extends ChatEvent {
  final String text;
  const ChatMessageSubmitted(this.text);
}

/// Reenvia uma mensagem que falhou, com o MESMO `clientMessageId` (sem duplicar).
class ChatSendRetried extends ChatEvent {
  final String clientMessageId;
  const ChatSendRetried(this.clientMessageId);
}

class ChatRealtimeMessageReceived extends ChatEvent {
  final Map<String, dynamic> data;
  const ChatRealtimeMessageReceived(this.data);
}

/// O chat acabou: `ChatClosed` do backend ou viagem iniciada/cancelada/concluída.
class ChatEnded extends ChatEvent {
  const ChatEnded();
}

class ChatConnectionChanged extends ChatEvent {
  final bool connected;
  const ChatConnectionChanged(this.connected);
}

class ChatReloadRequested extends ChatEvent {
  const ChatReloadRequested();
}

/// Interno: resultado de um envio disparado por [ChatMessageSubmitted] ou
/// [ChatSendRetried]. Mantém o handler de envio sem `await`, para eventos em
/// tempo real não ficarem esperando a resposta HTTP.
class ChatSendCompleted extends ChatEvent {
  final String clientMessageId;
  final Object? message;
  final Exception? error;
  const ChatSendCompleted(this.clientMessageId, {this.message, this.error});
}
