/// Eventos em tempo real do chat (SignalR), isolados atrás de uma interface
/// para o Bloc e a sessão não dependerem do pacote de SignalR.
abstract class IChatRealtimeDatasource {
  /// `ChatMessageReceived`: `{travelId, messageId, senderRole, text, sentAt}`.
  Stream<Map<String, dynamic>> get onMessageReceived;

  /// `ChatClosed`: `{travelId}`.
  Stream<Map<String, dynamic>> get onChatClosed;

  /// Viagem iniciada, cancelada ou concluída: também encerra o chat, mesmo que
  /// o `ChatClosed` se perca. Payload com `travelId`.
  Stream<Map<String, dynamic>> get onTravelEnded;

  Stream<void> get onReconnected;
  Stream<void> get onReconnecting;
  Stream<void> get onConnectionClosed;

  bool get isConnected;
}
