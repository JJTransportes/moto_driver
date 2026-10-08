import 'dart:developer' show log;

class NotificationService {
  static const _dismissedOrderTtl = Duration(hours: 6);
  static const _pushSoundSuppressionTtl = Duration(seconds: 20);
  static final Map<String, int> _dismissedOrders = {};
  static final Map<String, int> _pushSoundSuppressions = {};

  static bool _sheetVisible = false;

  static bool setSheetVisible(bool visible) {
    _sheetVisible = visible;
    return _sheetVisible;
  }

  /// True enquanto o `IncomingOrderSheet` já está na tela — usada pra evitar
  /// abrir um segundo sheet por cima do primeiro se o backend reenviar o
  /// mesmo evento `NewOrder` (reconexão do hub, retry) antes do motorista
  /// decidir aceitar/recusar o pedido atual.
  static bool get sheetVisible => _sheetVisible;

  // ── Pedido pendente (push notification) ──────────────────────────────

  static String? _pendingOrderId;

  /// Registra o orderId de um pedido pendente (clique em notificação).
  /// Rede de segurança para cliques que chegam antes do app estar pronto
  /// (navegação lança e é engolida) — o pendente é consumido pela guarda
  /// de termos no fim do fluxo de sessão.
  static void setPendingOrder(String orderId) {
    _pendingOrderId = orderId;
    log('[PUSH] Pending order set: $orderId', name: 'push');
  }

  /// Lê o pedido pendente sem consumir.
  static String? peekPendingOrder() => _pendingOrderId;

  /// Limpa o pedido pendente (saídas da página de pedido, logout).
  static void clearPendingOrder() {
    _pendingOrderId = null;
  }

  /// Registra uma oferta que este motorista já recusou, deixou expirar ou
  /// descobriu estar indisponível. A memória bloqueia imediatamente um evento
  /// SignalR duplicado ou um clique tardio no push da mesma sessão.
  static void dismissOrder(String orderId) {
    if (orderId.isEmpty) return;
    _dismissedOrders[orderId] = DateTime.now().millisecondsSinceEpoch;
    if (_pendingOrderId == orderId) _pendingOrderId = null;
    _trimDismissedOrders();
  }

  static Future<bool> isOrderDismissed(String orderId) async {
    if (orderId.isEmpty) return false;
    _trimDismissedOrders();
    return _dismissedOrders.containsKey(orderId);
  }

  static void _trimDismissedOrders() {
    final cutoff = DateTime.now()
        .subtract(_dismissedOrderTtl)
        .millisecondsSinceEpoch;
    _dismissedOrders.removeWhere((_, timestamp) => timestamp < cutoff);
    if (_dismissedOrders.length > 100) {
      final oldest = _dismissedOrders.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final entry in oldest.take(_dismissedOrders.length - 100)) {
        _dismissedOrders.remove(entry.key);
      }
    }
  }

  /// Marca uma oferta aberta pelo toque na push. O sistema operacional já
  /// reproduziu o som dessa notificação; se o SignalR reenviar o NewOrder ao
  /// reconectar, a Home não deve tocar o mesmo áudio uma segunda vez.
  static void suppressForegroundSound(String orderId) {
    if (orderId.isEmpty) return;
    _pushSoundSuppressions[orderId] = DateTime.now().millisecondsSinceEpoch;
    _trimPushSoundSuppressions();
  }

  static bool shouldSuppressForegroundSound(String orderId) {
    _trimPushSoundSuppressions();
    return _pushSoundSuppressions.containsKey(orderId);
  }

  static void _trimPushSoundSuppressions() {
    final cutoff = DateTime.now()
        .subtract(_pushSoundSuppressionTtl)
        .millisecondsSinceEpoch;
    _pushSoundSuppressions.removeWhere((_, timestamp) => timestamp < cutoff);
  }

  // ── Página de pedido aberta ──────────────────────────────────────────

  static bool _orderAlertOpen = false;

  /// Indica se a `OrderAlertPage` está aberta — usada para suprimir
  /// duplicação (novo clique / eventos SignalR enquanto a página está em foco).
  static bool get orderAlertOpen => _orderAlertOpen;

  static void setOrderAlertOpen(bool open) {
    _orderAlertOpen = open;
  }
}
