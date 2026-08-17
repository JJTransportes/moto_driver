import 'dart:developer' show log;

class NotificationService {
  static bool _sheetVisible = false;

  static bool setSheetVisible(bool visible) {
    _sheetVisible = visible;
    return _sheetVisible;
  }

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

  // ── Página de pedido aberta ──────────────────────────────────────────

  static bool _orderAlertOpen = false;

  /// Indica se a `OrderAlertPage` está aberta — usada para suprimir
  /// duplicação (novo clique / eventos SignalR enquanto a página está em foco).
  static bool get orderAlertOpen => _orderAlertOpen;

  static void setOrderAlertOpen(bool open) {
    _orderAlertOpen = open;
  }
}
