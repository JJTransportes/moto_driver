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
  final String _userName = 'Motorista';

  final Set<String> _deniedOrderIds = {};

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
                fullName: _userName,
                photoUrl: _userPhotoUrl,
                userId: _userId ?? '',
                onSignOut: _handleSignOut,
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
  }

  Future<void> _loadUserId() async {
    final authStorage = Modular.get<AuthStorage>();
    final userId = await authStorage.getUserId();
    setState(() => _userId = userId);
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

    await signalR.connect(
      'travel-orders',
      '${AppConfig.getBaseUrl()}/hubs/travel-orders',
      token,
    );

    // Also connect to travel-management for cancellation events
    try {
      await signalR.connect(
        'travel-management',
        '${AppConfig.getBaseUrl()}/hubs/travel-management',
        token,
      );
    } catch (_) {
      // Non-critical — cancels won't arrive in real-time without this hub
    }

    // Start periodic location reporting for dashboard map
    _startLocationReporting(signalR);

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
        },
      );
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
