import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  final _connections = <String, HubConnection>{};

  final _newOrderController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _travelStartedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _travelCompletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _travelCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _driverNearbyController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _driverArrivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatClosedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _reconnectingController = StreamController<void>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();
  final _closedController = StreamController<void>.broadcast();

  Stream<void> get onClosed => _closedController.stream;
  Stream<Map<String, dynamic>> get onNewOrder => _newOrderController.stream;
  Stream<Map<String, dynamic>> get onOrderCancelled =>
      _orderCancelledController.stream;
  Stream<void> get onReconnected => _reconnectedController.stream;
  Stream<void> get onReconnecting => _reconnectingController.stream;
  Stream<Map<String, dynamic>> get onTravelCancelled =>
      _travelCancelledController.stream;
  Stream<Map<String, dynamic>> get onTravelCompleted =>
      _travelCompletedController.stream;
  Stream<Map<String, dynamic>> get onTravelStarted =>
      _travelStartedController.stream;
  Stream<Map<String, dynamic>> get onDriverNearby =>
      _driverNearbyController.stream;
  Stream<Map<String, dynamic>> get onDriverArrived =>
      _driverArrivedController.stream;
  Stream<Map<String, dynamic>> get onChatMessageReceived =>
      _chatMessageController.stream;
  Stream<Map<String, dynamic>> get onChatClosed => _chatClosedController.stream;

  /// Conecta a um hub específico, identificado por [hubName].
  /// Se já existir uma conexão com o mesmo nome, ela é recriada.
  /// Não afeta conexões de outros hubs.
  Future<void> connect(
    String hubName,
    String hubUrl,
    String accessToken,
  ) async {
    await _connections[hubName]?.stop();
    _connections.remove(hubName);

    final connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
          ),
        )
        // Backoff curto — reconectar rápido importa mais aqui do que
        // economizar tentativas. Depois da última entrada o client desiste
        // e emite onclose (ver _registerLifecycleHandlers/onClosed), que é
        // tratado pela tela para forçar um connect() novo.
        .withAutomaticReconnect(retryDelays: [0, 1000, 2000, 5000, 5000])
        .build();

    _registerHubHandlers(connection, hubName);
    _registerLifecycleHandlers(connection);

    await connection.start();
    _connections[hubName] = connection;
  }

  /// Indica se já existe conexão ativa para o hub [hubName].
  /// Necessário porque [connect] para e recria a conexão com o mesmo nome —
  /// a OrderAlertPage usa este check para não derrubar a conexão da home
  /// (warm start) ao abrir.
  ///
  /// Checa o estado real da [HubConnection], não só a presença no map: uma
  /// vez que o backoff automático se esgota (onclose), a entrada continua no
  /// map mas a conexão já está `Disconnected` — só olhar o map daria falso
  /// positivo e impediria a reconexão forçada no resume do app.
  bool isConnected(String hubName) =>
      _connections[hubName]?.state == HubConnectionState.Connected;

  /// Envia um comando 'DenyOrder' para o hub de travel-orders.
  /// Lança exceção se a conexão não estiver estabelecida.
  Future<void> denyOrder(String travelId) async {
    final conn = _connections['travel-orders'];
    if (conn == null) {
      throw Exception('Conexão SignalR não estabelecida para travel-orders');
    }
    await conn.invoke('DenyOrder', args: [travelId]);
  }

  /// Desconecta apenas o hub especificado.
  Future<void> disconnect(String hubName) async {
    await _connections[hubName]?.stop();
    _connections.remove(hubName);
  }

  /// Desconecta todos os hubs.
  Future<void> disconnectAll() async {
    for (final conn in _connections.values) {
      await conn.stop();
    }
    _connections.clear();
  }

  void dispose() {
    disconnectAll();
    _newOrderController.close();
    _orderCancelledController.close();
    _travelStartedController.close();
    _travelCompletedController.close();
    _travelCancelledController.close();
    _driverNearbyController.close();
    _driverArrivedController.close();
    _chatMessageController.close();
    _chatClosedController.close();
    _reconnectingController.close();
    _reconnectedController.close();
    _closedController.close();
  }

  /// Finaliza a viagem (InProgress → Completed) via SignalR.
  /// [latitude]/[longitude] são genuinamente opcionais — quando qualquer um
  /// dos dois for nulo (localização indisponível), o argumento de posição é
  /// omitido da invocação em vez de forçar um `!` sobre um valor nulo.
  Future<void> finishTravel(
    String travelId, {
    double? latitude,
    double? longitude,
  }) async {
    final conn = _connections['travel-management'];
    final hasPosition = latitude != null && longitude != null;
    await conn?.invoke(
      'FinishTravel',
      args: hasPosition ? [travelId, latitude, longitude] : [travelId],
    );
  }

  /// Inicia a viagem (Accepted → InProgress) via SignalR.
  Future<void> startTravel(String travelId) async {
    final conn = _connections['travel-management'];
    await conn?.invoke('StartTravel', args: [travelId]);
  }

  /// Envia a localização atual do motorista durante uma viagem ativa.
  Future<void> updateLocation(
    String travelId,
    double latitude,
    double longitude,
  ) async {
    final conn = _connections['travel-management'];
    await conn?.invoke('UpdateLocation', args: [travelId, latitude, longitude]);
  }

  /// Reports the current location to the backend for dashboard map tracking.
  /// Used when the driver is online but not in an active travel.
  Future<void> reportLocation(double latitude, double longitude) async {
    final conn = _connections['travel-management'];
    await conn?.invoke('ReportLocation', args: [latitude, longitude]);
  }

  void _registerHubHandlers(HubConnection connection, String hubName) {
    switch (hubName) {
      case 'travel-orders':
        connection.on('NewOrder', (args) {
          if (args != null && args.isNotEmpty) {
            _newOrderController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('OrderCancelled', (args) {
          if (args != null && args.isNotEmpty) {
            _orderCancelledController.add(args.first as Map<String, dynamic>);
          }
        });
        break;

      case 'travel-management':
        connection.on('TravelStarted', (args) {
          if (args != null && args.isNotEmpty) {
            _travelStartedController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('TravelCompleted', (args) {
          if (args != null && args.isNotEmpty) {
            _travelCompletedController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('TravelCancelled', (args) {
          if (args != null && args.isNotEmpty) {
            _travelCancelledController.add(args.first as Map<String, dynamic>);
          }
        });
        // Spec pickup-arrival-alerts: o backend avisa motorista e passageiro quando o
        // motorista está próximo do embarque e quando chegou (viagem em Accepted).
        connection.on('DriverNearby', (args) {
          if (args != null && args.isNotEmpty) {
            _driverNearbyController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('DriverArrived', (args) {
          if (args != null && args.isNotEmpty) {
            _driverArrivedController.add(args.first as Map<String, dynamic>);
          }
        });
        // Spec pickup-chat-call: chat temporário (só em Accepted), sem push.
        connection.on('ChatMessageReceived', (args) {
          if (args != null && args.isNotEmpty) {
            _chatMessageController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('ChatClosed', (args) {
          if (args != null && args.isNotEmpty) {
            _chatClosedController.add(args.first as Map<String, dynamic>);
          }
        });
        break;
    }
  }

  void _registerLifecycleHandlers(HubConnection connection) {
    connection.onreconnecting(({error}) {
      _reconnectingController.add(null);
    });

    connection.onreconnected(({connectionId}) {
      _reconnectedController.add(null);
    });

    connection.onclose(({error}) {
      _closedController.add(null);
    });
  }
}
