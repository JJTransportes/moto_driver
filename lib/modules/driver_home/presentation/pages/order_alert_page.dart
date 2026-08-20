import 'dart:async';
import 'dart:developer' show log;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/driver_home/domain/entities/travel_order_entity.dart';
import 'package:moto_driver/modules/driver_home/presentation/widgets/incoming_order_sheet.dart';
import 'package:moto_driver/widgets/app_button.dart';

enum _PageState { loading, order, unavailable, error }

class OrderAlertPage extends StatefulWidget {
  final String? orderId;

  const OrderAlertPage({super.key, this.orderId});

  @override
  State<OrderAlertPage> createState() => _OrderAlertPageState();
}

class _OrderAlertPageState extends State<OrderAlertPage> {
  _PageState _state = _PageState.loading;
  TravelOrderEntity? _order;
  String? _message;
  String? _orderId;
  bool _hubConnectedHere = false;
  StreamSubscription<Map<String, dynamic>>? _cancelSub;

  @override
  void initState() {
    super.initState();
    NotificationService.setOrderAlertOpen(true);
    _orderId = widget.orderId ?? NotificationService.peekPendingOrder();

    // RF10: eventos em tempo real — cancelamento do pedido pelo passageiro.
    _cancelSub = Modular.get<SignalRService>().onOrderCancelled.listen((data) {
      final cancelledId = data['orderId'] as String?;
      if (cancelledId != null && cancelledId != _orderId) return;
      if (!mounted) return;
      setState(() {
        _state = _PageState.unavailable;
        _message = 'Pedido cancelado pelo passageiro.';
      });
    });

    _connectHub(); // fire-and-forget — falha não bloqueia a página
    _fetchOrder();
  }

  @override
  void dispose() {
    _cancelSub?.cancel();
    NotificationService.setOrderAlertOpen(false);
    if (_hubConnectedHere) {
      Modular.get<SignalRService>().disconnect('travel-orders');
    }
    super.dispose();
  }

  /// Conecta ao hub de travel-orders apenas se ainda não houver conexão
  /// (não derruba a conexão da home em warm start). Em cold start, esta
  /// conexão é a única fonte de eventos em tempo real.
  Future<void> _connectHub() async {
    try {
      final signalR = Modular.get<SignalRService>();
      if (signalR.isConnected('travel-orders')) return;

      final authStorage = Modular.get<AuthStorage>();
      final token = await authStorage.getToken();
      if (token == null) return;

      await signalR.connect(
        'travel-orders',
        '${AppConfig.getBaseUrl()}/hubs/travel-orders',
        token,
      );
      _hubConnectedHere = true;
    } catch (e) {
      log('[ORDER-ALERT] Hub connect failed: $e', name: 'push');
    }
  }

  Future<void> _fetchOrder({int attempt = 0}) async {
    final orderId = _orderId;
    if (orderId == null) {
      setState(() {
        _state = _PageState.error;
        _message = 'Pedido não encontrado.';
      });
      return;
    }

    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('${AppConfig.getBaseUrl()}/api/travels/orders/$orderId');
      if (!mounted) return;

      final entity = TravelOrderEntity.fromJson(response.data as Map<String, dynamic>);

      if (entity.status == 'cancelled' || entity.status == 'accepted') {
        setState(() {
          _state = _PageState.unavailable;
          _message = 'Pedido não está mais disponível.';
        });
        return;
      }

      setState(() {
        _order = entity;
        _state = _PageState.order;
      });
    } on DioException catch (e) {
      if (!mounted) return;

      switch (e.response?.statusCode) {
        case 403:
          setState(() {
            _state = _PageState.unavailable;
            _message = 'Este pedido não está mais disponível para você.';
          });
          return;
        case 404:
          setState(() {
            _state = _PageState.unavailable;
            _message = 'Pedido não encontrado.';
          });
          return;
        case 401:
          // Não deve ocorrer: o token já foi renovado pelo fluxo de entrada
          // (OrderRefreshPage). Tratado como erro de sessão.
          setState(() {
            _state = _PageState.error;
            _message = 'Sessão expirada.';
          });
          return;
      }

      // Erro de rede/timeout — retry 1x após 1s.
      if (attempt == 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        await _fetchOrder(attempt: 1);
        return;
      }

      setState(() {
        _state = _PageState.error;
        _message = 'Não foi possível carregar o pedido.';
      });
    }
  }

  /// Dono da navegação de saída (modo embutido do IncomingOrderSheet).
  void _handleDecision(OrderDecision decision, Map<String, dynamic>? result) {
    if (decision == OrderDecision.accepted) {
      // Em viagem, novo pedido pendente é descartado (RF08/RF12).
      NotificationService.clearPendingOrder();
      Modular.to.pushReplacementNamed(
        '/active-travel',
        arguments: {
          'travelId': result?['travelId'],
          'pickupRoute': result?['pickupRoute'],
          'tripRoute': result?['tripRoute'],
        },
      );
      return;
    }

    _exitToHome();
  }

  /// Saída padrão por recusar/timeout/cancelado/indisponível/erro:
  /// limpa o pendente, garante exatamente uma home na pilha e reexibe
  /// um novo pedido pendente (RF11).
  void _exitToHome() {
    // RF11: captura novo pendente ANTES de limpar.
    final holder = NotificationService.peekPendingOrder();
    final nextOrderId = (holder != null && holder != _orderId) ? holder : null;
    NotificationService.clearPendingOrder();

    Modular.to.popUntil((route) => route.isFirst);
    if (Modular.to.path != '/home') {
      Modular.to.pushReplacementNamed('/home');
    }

    if (nextOrderId != null) {
      Modular.to.pushNamed('/order-refresh', arguments: {'orderId': nextOrderId});
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _PageState.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case _PageState.order:
        final order = _order;
        if (order == null) {
          return _buildMessage('Pedido não encontrado.');
        }
        return SingleChildScrollView(
          child: IncomingOrderSheet(
            order: order.toJson(),
            onDecision: _handleDecision,
          ),
        );
      case _PageState.unavailable:
        return _buildMessage(_message ?? 'Pedido não está mais disponível.');
      case _PageState.error:
        return _buildMessage(_message ?? 'Não foi possível carregar o pedido.', showRetry: true);
    }
  }

  Widget _buildMessage(String message, {bool showRetry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.secondary),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (showRetry) ...[
              AppButton(
                label: 'Tentar novamente',
                onPressed: () {
                  setState(() => _state = _PageState.loading);
                  _fetchOrder(); // recomeça do zero (attempt reset)
                },
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: _exitToHome,
              child: const Text('Voltar para a Home'),
            ),
          ],
        ),
      ),
    );
  }
}
