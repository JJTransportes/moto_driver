import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/driver_home/presentation/widgets/incoming_order_sheet.dart';
import 'package:moto_driver/widgets/profile_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _newOrderSub;
  StreamSubscription? _reconnectingSub;
  StreamSubscription? _reconnectedSub;
  StreamSubscription? _travelCancelledSub;
  bool _isReconnecting = false;
  String? _currentTravelStatus;
  String? _currentTravelId;
  String? _currentPassengerName;
  Timer? _locationTimer;
  String? _userId;
  String? _userPhotoUrl;
  String? _userName;

  final Set<String> _deniedOrderIds = {};
  bool _isProcessingPendingOrder = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isReconnecting)
                Container(
                  color: Colors.orange,
                  padding: const EdgeInsets.all(8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Text('Reconectando...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ProfileHeader(
                fullName: _userName ?? 'Motorista',
                photoUrl: _userPhotoUrl,
                userId: _userId ?? '',
                onSignOut: _handleSignOut,
                onSettingsTap: () async {
                  await Modular.to.pushNamed('/profile-configuration', arguments: {'userId': _userId});
                  _loadUserId();
                },
              ),
              const SizedBox(height: 24),
              // Active travel card
              if (_currentTravelId != null && _currentTravelStatus != 'Cancelled' && _currentTravelStatus != 'Completed') _buildActiveTravelCard(),
              if (_currentTravelId == null || _currentTravelStatus == 'Cancelled' || _currentTravelStatus == 'Completed')
                const Expanded(
                  child: Center(
                    child: Text('Aguardando novas viagens...', style: TextStyle(color: Color(0xFF4E4E4E), fontSize: 16)),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Modular.to.pushNamed('/travel-history'),
                  icon: const Icon(Icons.history),
                  label: const Text('Histórico de Viagens'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4685C0),
                    side: const BorderSide(color: Color(0xFF4685C0)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTravelCard() {
    final isInProgress = _currentTravelStatus == 'InProgress';

    return GestureDetector(
      onTap: () => Modular.to.pushNamed('/active-travel', arguments: {'travelId': _currentTravelId}),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.directions_car, color: Color(0xFF4685C0), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Viagem Ativa',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4E4E4E)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_currentPassengerName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF4685C0), size: 20),
                      const SizedBox(width: 8),
                      Text(_currentPassengerName!, style: const TextStyle(color: Color(0xFF4E4E4E), fontSize: 14)),
                    ],
                  ),
                ),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF4685C0), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isInProgress ? 'Em andamento' : 'Aceita — aguardando início',
                    style: const TextStyle(color: Color(0xFF4E4E4E), fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isInProgress ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isInProgress ? 'Em andamento' : 'Aceita',
                  style: TextStyle(
                    color: isInProgress ? Colors.green.shade800 : Colors.orange.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Modular.to.pushNamed('/active-travel', arguments: {'travelId': _currentTravelId}),
                  child: const Text('Abrir Viagem', style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _newOrderSub?.cancel();
    _travelCancelledSub?.cancel();
    _reconnectingSub?.cancel();
    _reconnectedSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _checkActiveTravelHttp();
    _connectSignalR();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingOrder());
  }

  Future<void> _loadUserId() async {
    final authStorage = Modular.get<AuthStorage>();
    final userId = await authStorage.getUserId();
    setState(() => _userId = userId);
    if (userId != null) {
      await _loadUserName(userId);
    }
  }

  Future<void> _loadUserName(String userId) async {
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('${AppConfig.getBaseUrl()}/api/drivers/$userId');
      if (!mounted) return;
      if (response.statusCode == 200 && response.data != null) {
        final name = response.data['name'] as String?;
        var photoUrl = response.data['photoUrl'] as String?;
        if (photoUrl != null && photoUrl.isNotEmpty
            && !photoUrl.startsWith('http://') && !photoUrl.startsWith('https://')) {
          photoUrl = '${AppConfig.getBaseUrl()}$photoUrl';
        }
        setState(() {
          if (name != null && name.isNotEmpty) _userName = name;
          _userPhotoUrl = photoUrl;
        });
      }
    } catch (_) {
      // Silently fallback — name stays null, ProfileHeader handles gracefully
    }
  }

  Future<void> _checkActiveTravelHttp() async {
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('${AppConfig.getBaseUrl()}/api/travels/active');
      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && data['travelId'] != null) {
          final status = data['status'] as String?;
          if (status == 'Accepted' || status == 'InProgress') {
            setState(() {
              _currentTravelId = data['travelId'] as String;
              _currentTravelStatus = status;
              _currentPassengerName = data['passengerName'] as String?;
            });
            return;
          }
        }
      }
      // Sem viagem ativa via REST — limpa estado
      setState(() {
        _currentTravelId = null;
        _currentTravelStatus = null;
        _currentPassengerName = null;
      });
    } catch (_) {
      // Fallback silencioso para cache local
      await _loadActiveTravelFromLocal();
    }
  }

  Future<void> _loadActiveTravelFromLocal() async {
    final travelRepo = Modular.get<TravelLocalRepository>();
    final active = await travelRepo.getActiveTravel();
    // Só restaura viagens ativas (Accepted/InProgress).
    // Viagens finalizadas/canceladas no cache NÃO devem setar _currentTravelId,
    // pois isso bloquearia o recebimento de novos pedidos via SignalR.
    if (active != null && mounted &&
        (active.status == 'Accepted' || active.status == 'InProgress')) {
      setState(() {
        _currentTravelId = active.travelId;
        _currentTravelStatus = active.status;
      });
    }
  }

  Future<void> _connectSignalR() async {
    final signalR = Modular.get<SignalRService>();
    final authStorage = Modular.get<AuthStorage>();
    final token = await authStorage.getToken();
    if (token == null) {
      debugPrint('SignalR: token nulo — conexão abortada');
      return;
    }

    // -------------------------------------------------------------------
    // IMPORTANTE: registrar listeners ANTES de conectar para evitar perda
    // de eventos (condição de corrida com broadcast stream sem buffer).
    // -------------------------------------------------------------------

    _newOrderSub = signalR.onNewOrder.listen((data) {
      debugPrint('HomeScreen: NewOrder recebido do stream — $data');
      try {
        if (_currentTravelId != null) {
          debugPrint('HomeScreen: NewOrder ignorado — viagem ativa $_currentTravelId');
          return;
        }

        final orderId = data['orderId'] as String?;
        if (orderId == null) {
          debugPrint('HomeScreen: NewOrder ignorado — orderId nulo');
          return;
        }

        // If this order was already shown (denied or currently displayed), skip
        if (_deniedOrderIds.contains(orderId)) {
          debugPrint('HomeScreen: NewOrder ignorado — orderId $orderId já exibido');
          return;
        }

        // A new (non-denied) order signals a fresh dispatch round — clear old denials
        if (_deniedOrderIds.isNotEmpty) {
          _deniedOrderIds.clear();
        }

        // Track this order to prevent duplicate display (SignalR + push)
        _deniedOrderIds.add(orderId);

        IncomingOrderSheet.show(
          context,
          data,
          onDenied: () {
            // orderId já está em _deniedOrderIds — evita reexibição
          },
        );
      } catch (e) {
        debugPrint('HomeScreen: ERRO ao processar NewOrder — $e');
      }
    });

    _travelCancelledSub = signalR.onTravelCancelled.listen((data) {
      if (!mounted) return;
      final travelId = data['travelId'] as String?;
      if (travelId != null && travelId == _currentTravelId) {
        setState(() {
          _currentTravelId = null;
          _currentTravelStatus = null;
          _currentPassengerName = null;
        });
        Modular.get<TravelLocalRepository>().clearTravels();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viagem cancelada'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _reconnectingSub = signalR.onReconnecting.listen((_) {
      setState(() => _isReconnecting = true);
    });

    _reconnectedSub = signalR.onReconnected.listen((_) {
      setState(() => _isReconnecting = false);
    });

    // Conectar hubs (listeners já estão prontos)
    try {
      await signalR.connect(
        'travel-orders',
        '${AppConfig.getBaseUrl()}/hubs/travel-orders',
        token,
      );
      debugPrint('SignalR: conectado ao hub travel-orders');
    } catch (e) {
      debugPrint('SignalR: FALHA ao conectar travel-orders — $e');
    }

    // Also connect to travel-management for cancellation events
    try {
      await signalR.connect(
        'travel-management',
        '${AppConfig.getBaseUrl()}/hubs/travel-management',
        token,
      );
      debugPrint('SignalR: conectado ao hub travel-management');
    } catch (e) {
      debugPrint('SignalR: travel-management não conectado — $e');
    }

    // Start periodic location reporting for dashboard map
    _startLocationReporting(signalR);
  }

  /// Verifica se há um pedido pendente vindo de uma notificação push.
  /// Lê [pendingOrderId] dos route arguments e busca os detalhes via REST.
  Future<void> _checkPendingOrder() async {
    if (!mounted) return;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map<String, dynamic>) {
      final orderId = routeArgs['pendingOrderId'] as String?;
      if (orderId != null && orderId.isNotEmpty) {
        await _fetchAndShowOrder(orderId);
      }
    }
  }

  /// Busca detalhes de um pedido via REST e exibe a tela de aceitação/recusa.
  /// Inclui guarda contra duplicação com o caminho SignalR.
  Future<void> _fetchAndShowOrder(String orderId) async {
    if (_isProcessingPendingOrder) return;

    // Se o pedido já foi exibido (SignalR chegou primeiro), não duplica
    if (_deniedOrderIds.contains(orderId)) return;
    if (_currentTravelId != null) return;

    _isProcessingPendingOrder = true;

    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get(
        '${AppConfig.getBaseUrl()}/api/travels/orders/$orderId',
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final orderData = response.data as Map<String, dynamic>;

        // Re-verifica após a chamada de rede (estado pode ter mudado)
        if (_currentTravelId != null || _deniedOrderIds.contains(orderId)) return;

        // Track para evitar duplicação
        _deniedOrderIds.add(orderId);

        IncomingOrderSheet.show(context, orderData);
      }
    } on DioException {
      // Pedido expirado, já aceito por outro motorista ou inválido — ignorar silenciosamente
    } catch (e) {
      debugPrint('Erro ao buscar pedido $orderId: $e');
    } finally {
      if (mounted) _isProcessingPendingOrder = false;
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await Modular.get<SignalRService>().disconnectAll();
    await Modular.get<TravelLocalRepository>().clearTravels();
    await Modular.get<SignOutService>().signOut();
  }

  void _startLocationReporting(SignalRService signalR) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        try {
          final hasPermission = await Geolocator.checkPermission();
          if (hasPermission == LocationPermission.denied || hasPermission == LocationPermission.deniedForever) {
            return;
          }
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          await signalR.reportLocation(position.latitude, position.longitude);
        } catch (_) {
          // Silently skip on error
        }
      },
    );
  }
}
