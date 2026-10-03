import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_realtime_datasource.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_load_chat_history_usecase.dart';

/// Mantém, fora da tela de conversa, a contagem de mensagens não lidas da viagem
/// em `Accepted` — para o card mostrar o selo sem o chat aberto (spec
/// pickup-chat-call, req 4.2 a 4.5). Sem push: tudo acontece dentro do app.
class ChatSession with WidgetsBindingObserver {
  final ILoadChatHistoryUsecase _loadHistory;
  final IChatRealtimeDatasource _realtime;

  ChatSession(this._loadHistory, this._realtime);

  /// Mensagens não lidas da viagem atual (0 quando não há chat).
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _travelId;
  bool _chatOpen = false;
  bool _observing = false;

  String? get travelId => _travelId;

  /// Começa a acompanhar a viagem. Idempotente para o mesmo [travelId].
  void start(String travelId) {
    if (_travelId == travelId) return;
    stop();

    _travelId = travelId;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    _subscriptions.addAll([
      _realtime.onMessageReceived
          .where((d) => d['travelId'] == travelId)
          .listen((_) {
            if (!_chatOpen) unread.value = unread.value + 1;
          }),
      _realtime.onChatClosed.where((d) => d['travelId'] == travelId).listen((_) => stop()),
      _realtime.onTravelEnded.where((d) => d['travelId'] == travelId).listen((_) => stop()),
      // Um alerta ou mensagem emitido com o hub fora do ar não é reenviado.
      _realtime.onReconnected.listen((_) => refresh()),
    ]);

    refresh();
  }

  /// Encerra o acompanhamento e limpa o selo (viagem iniciada, cancelada, etc.).
  void stop() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _travelId = null;
    _chatOpen = false;
    unread.value = 0;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  /// A tela de conversa abriu (zera o selo) ou fechou.
  void setChatOpen(bool open) {
    _chatOpen = open;
    if (open) unread.value = 0;
  }

  /// Recarrega a contagem de não lidas pelo servidor.
  Future<void> refresh() async {
    final travelId = _travelId;
    if (travelId == null) return;

    final result = await _loadHistory(travelId);
    if (_travelId != travelId) return; // mudou de viagem durante a chamada

    final history = result.getOrNull();
    if (history != null) {
      unread.value = _chatOpen ? 0 : history.unreadCount;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}
