import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/driver_availability/data/datasources/availability_datasource.dart';
import 'package:moto_driver/modules/driver_availability/domain/entities/driver_availability_entity.dart';
import 'package:moto_driver/modules/driver_availability/presentation/widgets/availability_sheet.dart';
import 'package:moto_driver/modules/driver_home/presentation/widgets/incoming_order_sheet.dart';
import 'package:moto_driver/widgets/profile_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderCancelledSub;
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
  String? _processedOrderId; // Evita processar mesmo pushOrderId duas vezes
  bool _permissionDenied = false;

  // ── Disponibilidade (modo de atendimento) ──
  DriverAvailabilityEntity? _availability;
  Timer? _availabilityTimer;

  @override
  Widget build(BuildContext context) {
    // RF04: Capturar pushOrderId em warm start (app já está em /home)
    _checkPushOrderInArgs();

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
              // RF06: Banner de permissão de notificação negada
              if (_permissionDenied) _buildPermissionBanner(),
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
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _availabilityTimer?.cancel();
    _newOrderSub?.cancel();
    _orderCancelledSub?.cancel();
    _travelCancelledSub?.cancel();
    _reconnectingSub?.cancel();
    _reconnectedSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserId();
    _checkActiveTravelHttp();
    _connectSignalR();

    // RF04: Verificar se abriu via push notification (cold start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePushOrder();
    });

    // RF06: Verificar permissão de notificação
    _checkNotificationPermission();

    // RF02: Tentar late login se falhou antes
    _tryLateLogin();

    // Disponibilidade: verificar status ao entrar no app (concorrente)
    _checkAvailability();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // RF06: Reavaliar permissão ao voltar ao foreground
      // (usuário pode ter ido às Configurações e concedido permissão)
      _checkNotificationPermission();
    }
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
    if (active != null && mounted) {
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
    if (token == null) return;

    // ── Subscribe to events BEFORE connecting ──
    // The backend sends NewOrder during OnConnectedAsync (re-dispatch).
    // If we subscribe after connect(), the event is lost.
    _newOrderSub = signalR.onNewOrder.listen((data) {
      if (_currentTravelId != null) return; // Already in a travel

      final orderId = data['orderId'] as String?;
      if (orderId == null) return;

      // If this order was already denied, ignore the re-send
      if (_deniedOrderIds.contains(orderId)) return;

      // A new (non-denied) order signals a fresh dispatch round — clear old denials
      if (_deniedOrderIds.isNotEmpty) {
        _deniedOrderIds.clear();
      }

      IncomingOrderSheet.show(
        context,
        data,
        onDenied: () {
          _deniedOrderIds.add(orderId);
          NotificationService.setSheetVisible(false);
        },
      );

      // RF05: Marcar sheet como visível para suprimir foreground dup
      NotificationService.setSheetVisible(true);
    });

    // Listen for travel cancellations
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

    _orderCancelledSub = signalR.onOrderCancelled.listen((data) {
      if (!mounted) return;
      // Dismiss any open bottom sheet and notify the driver
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido cancelado pelo passageiro.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    // ── Now connect to hubs (listeners are already registered) ──
    await signalR.connect(
      'travel-orders',
      '${AppConfig.getBaseUrl()}/hubs/travel-orders',
      token,
    );

    try {
      await signalR.connect(
        'travel-management',
        '${AppConfig.getBaseUrl()}/hubs/travel-management',
        token,
      );
    } catch (_) {
      // Non-critical — cancels won't arrive in real-time without this hub
    }

    _startLocationReporting(signalR);
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

    _stopAvailabilityTimer();
    await Modular.get<SignalRService>().disconnectAll();
    await Modular.get<TravelLocalRepository>().clearTravels();
    await Modular.get<SignOutService>().signOut();
  }

  // ── Disponibilidade (modo de atendimento) ──

  /// Verifica o status de disponibilidade ao entrar no app.
  /// Fire-and-forget — não bloqueia SignalR nem viagem ativa.
  Future<void> _checkAvailability() async {
    try {
      final datasource = Modular.get<AvailabilityDatasource>();
      final availability = await datasource.getAvailability();
      if (!mounted) return;

      setState(() => _availability = availability);

      if (availability.isActive) {
        _startAvailabilityTimer();
      } else if (!AvailabilitySheet.isOpen) {
        final result = await AvailabilitySheet.show(context, datasource: datasource);
        if (!mounted || result == null) return; // cancelou — permanece inactive
        setState(() => _availability = result);
        _startAvailabilityTimer();
      }
    } catch (e) {
      // RF06: falha silenciosa — re-tenta na próxima entrada do app
      developer.log('[AVAILABILITY] GET failed: $e', name: 'availability');
    }
  }

  void _startAvailabilityTimer() {
    _stopAvailabilityTimer();
    final availability = _availability;
    if (availability == null || !availability.isActive) return;

    _availabilityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {}); // recalcula a contagem regressiva
      if (availability.isExpired) {
        _stopAvailabilityTimer(); // indicador passa a exibir ramo inativo
      }
    });
  }

  void _stopAvailabilityTimer() {
    _availabilityTimer?.cancel();
    _availabilityTimer = null;
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

  // ── Push Notification Methods (RF04, RF05, RF06) ──

  /// Verifica se há pushOrderId nos argumentos da rota (warm start).
  void _checkPushOrderInArgs() {
    final args = Modular.args.data;
    if (args is Map) {
      final orderId = args['pushOrderId'] as String?;
      if (orderId != null && _processedOrderId != orderId) {
        _processedOrderId = orderId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchAndShowOrder(orderId);
        });
      }
    }
  }

  /// RF04: Processa pushOrderId recebido via argumentos de rota.
  void _handlePushOrder() {
    final args = Modular.args.data;
    final pushOrderId = args is Map ? args['pushOrderId'] as String? : null;
    if (pushOrderId == null) return;

    _processedOrderId = pushOrderId;
    _fetchAndShowOrder(pushOrderId);
  }

  /// RF04: Busca dados completos do pedido e exibe IncomingOrderSheet.
  Future<void> _fetchAndShowOrder(String orderId) async {
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('${AppConfig.getBaseUrl()}/api/travels/orders/$orderId');
      if (!mounted) return;

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String?;

      // RF04: Tratamento de erros de negócio
      if (status == 'cancelled' || status == 'accepted') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pedido não está mais disponível')),
          );
        }
        return;
      }

      // RF05: Marcar sheet como visível (suprime foreground dup)
      NotificationService.setSheetVisible(true);

      if (mounted) {
        IncomingOrderSheet.show(
          context,
          data,
          onDenied: () {
            _deniedOrderIds.add(orderId);
            NotificationService.setSheetVisible(false);
          },
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // RF04: Não pertence ao motorista — ignorar silenciosamente
        developer.log('[PUSH] Order $orderId does not belong to current driver',
            name: 'push');
      } else {
        developer.log('[PUSH] Failed to fetch order $orderId: $e', name: 'push', level: 900);
      }
    }
  }

  /// RF06: Banner informativo quando permissão de notificação está negada.
  Widget _buildPermissionBanner() {
    return Container(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.notifications_off, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Notificações desativadas — você pode perder novas corridas. Ative nas Configurações do app.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// RF06: Verifica status da permissão de notificação.
  Future<void> _checkNotificationPermission() async {
    final granted = await NotificationService.permissionGranted;
    if (mounted) {
      setState(() => _permissionDenied = !granted);
    }
  }

  /// RF02: Tenta recuperar OneSignal.login se o primeiro fluxo falhou.
  Future<void> _tryLateLogin() async {
    final userId = _userId;
    if (userId != null) {
      NotificationService.tryLateLogin(userId);
    }
  }
}
