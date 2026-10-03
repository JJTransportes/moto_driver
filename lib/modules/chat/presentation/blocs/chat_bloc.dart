import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_realtime_datasource.dart';
import 'package:moto_driver/modules/chat/data/repositories/chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/client_message_id.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_load_chat_history_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_mark_chat_read_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_send_chat_message_usecase.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_event.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_state.dart';

/// Conversa do chat temporário da viagem (spec pickup-chat-call). Nunca registra
/// o texto das mensagens.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ISendChatMessageUsecase _send;
  final ILoadChatHistoryUsecase _loadHistory;
  final IMarkChatReadUsecase _markRead;
  final IChatRealtimeDatasource _realtime;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String _travelId = '';

  ChatBloc(this._send, this._loadHistory, this._markRead, this._realtime)
    : super(const ChatInitial()) {
    on<ChatStarted>(_onStarted);
    on<ChatMessageSubmitted>(_onSubmitted);
    on<ChatSendRetried>(_onRetried);
    on<ChatSendCompleted>(_onSendCompleted);
    on<ChatRealtimeMessageReceived>(_onRealtimeMessage);
    on<ChatConnectionChanged>(_onConnectionChanged);
    on<ChatReloadRequested>(_onReload);
    on<ChatEnded>(_onEnded);
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    return super.close();
  }

  // ─── Início e tempo real ────────────────────────────────────────────────

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    _travelId = event.travelId;
    _listen();
    emit(const ChatLoading());
    await _refresh(emit, firstLoad: true);
  }

  void _listen() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions
      ..clear()
      ..addAll([
        _realtime.onMessageReceived
            .where((d) => d['travelId'] == _travelId)
            .listen((d) => add(ChatRealtimeMessageReceived(d))),
        _realtime.onChatClosed
            .where((d) => d['travelId'] == _travelId)
            .listen((_) => add(const ChatEnded())),
        _realtime.onTravelEnded
            .where((d) => d['travelId'] == _travelId)
            .listen((_) => add(const ChatEnded())),
        _realtime.onReconnected.listen(
          (_) => add(const ChatConnectionChanged(true)),
        ),
        _realtime.onReconnecting.listen(
          (_) => add(const ChatConnectionChanged(false)),
        ),
        _realtime.onConnectionClosed.listen(
          (_) => add(const ChatConnectionChanged(false)),
        ),
      ]);
  }

  // ─── Histórico ──────────────────────────────────────────────────────────

  Future<void> _refresh(
    Emitter<ChatState> emit, {
    bool firstLoad = false,
  }) async {
    final result = await _loadHistory(_travelId);
    final history = result.getOrNull();

    if (history == null) {
      final error = result.exceptionOrNull();
      if (_chatIsGone(error)) {
        emit(const ChatClosed());
      } else if (firstLoad) {
        emit(
          ChatFailure(error?.toString() ?? 'Não foi possível carregar o chat.'),
        );
      }
      return;
    }

    final current = state;
    final pendingLocal = current is ChatReady
        ? current.items.where((i) => i.status != ChatItemStatus.sent)
        : const <ChatItem>[];

    final items = [...history.messages.map(_toItem), ...pendingLocal];
    emit(ChatReady(items: items, connected: _realtime.isConnected));

    if (history.unreadCount > 0) {
      unawaited(_markRead(_travelId));
    }
  }

  Future<void> _onReload(
    ChatReloadRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatReady) return;
    await _refresh(emit);
  }

  // ─── Envio ──────────────────────────────────────────────────────────────

  void _onSubmitted(ChatMessageSubmitted event, Emitter<ChatState> emit) {
    final current = state;
    if (current is! ChatReady || !current.connected) return;

    final text = event.text.trim();
    if (text.isEmpty || text.length > kChatMaxMessageLength) return;

    final clientId = generateClientMessageId();
    final item = ChatItem(
      id: clientId,
      clientMessageId: clientId,
      text: text,
      mine: true,
      sentAt: DateTime.now(),
      status: ChatItemStatus.sending,
    );
    emit(current.copyWith(items: [...current.items, item], clearNotice: true));
    _dispatchSend(item);
  }

  void _onRetried(ChatSendRetried event, Emitter<ChatState> emit) {
    final current = state;
    if (current is! ChatReady || !current.connected) return;

    final index = current.items.indexWhere(
      (i) =>
          i.clientMessageId == event.clientMessageId &&
          i.status == ChatItemStatus.failed,
    );
    if (index < 0) return;

    final retrying = current.items[index].copyWith(
      status: ChatItemStatus.sending,
    );
    final items = [...current.items]..[index] = retrying;
    emit(current.copyWith(items: items, clearNotice: true));
    _dispatchSend(retrying);
  }

  /// Dispara o envio sem esperar: o resultado volta como [ChatSendCompleted].
  void _dispatchSend(ChatItem item) {
    unawaited(() async {
      final result = await _send(
        SendChatMessageParams(
          travelId: _travelId,
          text: item.text,
          clientMessageId: item.clientMessageId,
        ),
      );
      if (isClosed) return;
      add(
        ChatSendCompleted(
          item.clientMessageId,
          message: result.getOrNull(),
          error: result.exceptionOrNull(),
        ),
      );
    }());
  }

  void _onSendCompleted(ChatSendCompleted event, Emitter<ChatState> emit) {
    final current = state;
    if (current is! ChatReady) return;

    final index = current.items.indexWhere(
      (i) => i.clientMessageId == event.clientMessageId,
    );
    if (index < 0) return;

    final error = event.error;
    if (error != null) {
      if (_chatIsGone(error)) {
        emit(const ChatClosed());
        return;
      }
      final items = [...current.items]
        ..[index] = current.items[index].copyWith(
          status: ChatItemStatus.failed,
        );
      emit(current.copyWith(items: items, notice: error.toString()));
      return;
    }

    final message = event.message as ChatMessageEntity;
    final items = [...current.items]
      ..[index] = current.items[index].copyWith(
        id: message.id,
        status: ChatItemStatus.sent,
        sentAt: message.sentAt,
      );
    emit(current.copyWith(items: items));
  }

  // ─── Recebimento, conexão e encerramento ────────────────────────────────

  void _onRealtimeMessage(
    ChatRealtimeMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    final current = state;
    if (current is! ChatReady) return;

    final message = chatMessageFromJson(event.data);
    if (current.items.any((i) => i.id == message.id)) return;

    emit(current.copyWith(items: [...current.items, _toItem(message)]));
    // Conversa aberta: a mensagem já foi vista.
    unawaited(_markRead(_travelId));
  }

  void _onConnectionChanged(
    ChatConnectionChanged event,
    Emitter<ChatState> emit,
  ) {
    final current = state;
    if (current is! ChatReady) return;

    emit(current.copyWith(connected: event.connected));
    // Reconectou: recupera o que chegou enquanto estava fora.
    if (event.connected) add(const ChatReloadRequested());
  }

  void _onEnded(ChatEnded event, Emitter<ChatState> emit) {
    if (state is ChatClosed) return;
    emit(const ChatClosed());
  }

  // ─── Utilitários ────────────────────────────────────────────────────────

  /// 409 (chat indisponível) ou 403/404: a viagem saiu de `Accepted`.
  bool _chatIsGone(Exception? error) =>
      error is ConflictException ||
      error is ForbiddenException ||
      error is NotFoundException;

  ChatItem _toItem(ChatMessageEntity m) => ChatItem(
    id: m.id,
    clientMessageId: m.id,
    text: m.text,
    mine: m.mine,
    sentAt: m.sentAt,
    status: ChatItemStatus.sent,
  );
}
