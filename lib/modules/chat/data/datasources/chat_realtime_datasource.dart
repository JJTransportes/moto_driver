import 'dart:async';

import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_realtime_datasource.dart';

class ChatRealtimeDatasource implements IChatRealtimeDatasource {
  static const _hub = 'travel-management';

  final SignalRService _signalR;

  ChatRealtimeDatasource(this._signalR);

  @override
  Stream<Map<String, dynamic>> get onMessageReceived =>
      _signalR.onChatMessageReceived;

  @override
  Stream<Map<String, dynamic>> get onChatClosed => _signalR.onChatClosed;

  @override
  Stream<Map<String, dynamic>> get onTravelEnded {
    late final StreamController<Map<String, dynamic>> controller;
    final subscriptions = <StreamSubscription<Map<String, dynamic>>>[];

    controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        for (final stream in [
          _signalR.onTravelStarted,
          _signalR.onTravelCancelled,
          _signalR.onTravelCompleted,
        ]) {
          subscriptions.add(stream.listen(controller.add));
        }
      },
      onCancel: () {
        for (final subscription in subscriptions) {
          subscription.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  @override
  Stream<void> get onReconnected => _signalR.onReconnected;

  @override
  Stream<void> get onReconnecting => _signalR.onReconnecting;

  @override
  Stream<void> get onConnectionClosed => _signalR.onClosed;

  @override
  bool get isConnected => _signalR.isConnected(_hub);
}
