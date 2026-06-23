import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/core/theme/app_theme.dart';

class ActiveTravelPage extends StatefulWidget {
  final String travelId;

  const ActiveTravelPage({super.key, required this.travelId});

  @override
  State<ActiveTravelPage> createState() => _ActiveTravelPageState();
}

class _ActiveTravelPageState extends State<ActiveTravelPage> {
  bool _isLoading = true;
  String? _error;

  String? _status;
  String? _passengerName;
  String? _departureAddress;
  String? _destinationAddress;
  
  int? _distanceToDestination;
  int? _timeHours;
  int? _timeMinutes;
  double? _passengerLat;
  double? _passengerLng;
  double? _destLat;
  double? _destLng;

  bool _isActing = false;
  bool _hubConnected = false;
  Timer? _locationTimer;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadTravel();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    if (_hubConnected) {
      Modular.get<SignalRService>().disconnect('travel-management');
    }
    super.dispose();
  }

  Future<void> _loadTravel() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get(
        '${AppConfig.getBaseUrl()}/api/travels/${widget.travelId}',
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>;
      final routes = (data['routes'] as List?) ?? [];

      setState(() {
        _status = data['status'] as String?;
        _passengerName = data['passengerName'] as String?;
        _departureAddress = routes.isNotEmpty ? routes[0]['departureAddress'] as String? : null;
        _destinationAddress = routes.isNotEmpty ? routes[0]['destinationAddress'] as String? : null;
        _distanceToDestination = routes.isNotEmpty ? (routes[0]['routeDestinationInMeters'] as int?) ?? 0 : 0;
        _timeHours = routes.isNotEmpty ? (routes[0]['averageTravelTimeInHours'] as int?) ?? 0 : 0;
        _timeMinutes = routes.isNotEmpty ? (routes[0]['averageTravelTimeInMinutes'] as int?) ?? 0 : 0;
        _passengerLat = routes.isNotEmpty ? (routes[0]['initialLatitude'] as num?)?.toDouble() : null;
        _passengerLng = routes.isNotEmpty ? (routes[0]['initialLongitude'] as num?)?.toDouble() : null;
        _destLat = routes.isNotEmpty ? (routes[0]['destinationLatitude'] as num?)?.toDouble() : null;
        _destLng = routes.isNotEmpty ? (routes[0]['destinationLongitude'] as num?)?.toDouble() : null;
        _isLoading = false;
      });

      _updateMapMarkers();

      // Connect to travel-management hub and start location tracking
      if (_status == 'Accepted' || _status == 'InProgress') {
        await _connectManagementHub();
        _startLocationTracking();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _connectManagementHub() async {
    final authStorage = Modular.get<AuthStorage>();
    final token = await authStorage.getToken();
    if (token == null) return;

    try {
      final signalR = Modular.get<SignalRService>();
      await signalR.connect(
        'travel-management',
        '${AppConfig.getBaseUrl()}/hubs/travel-management',
        token,
      );
      if (mounted) setState(() => _hubConnected = true);
    } catch (_) {
      // Non-critical — location updates will be best-effort
    }
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_hubConnected) return;

      try {
        final locationService = Modular.get<LocationService>();
        final result = await locationService.getCurrentPosition();
        if (!result.isGranted) return;

        final signalR = Modular.get<SignalRService>();
        await signalR.updateLocation(
          widget.travelId,
          result.position!.latitude,
          result.position!.longitude,
        );
      } catch (_) {
        // Best-effort — location send failure should not break anything
      }
    });
  }

  void _updateMapMarkers() {
    if (_passengerLat == null || _passengerLng == null) return;

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('passenger'),
          position: LatLng(_passengerLat!, _passengerLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Passageiro'),
        ),
      );

      if (_destLat != null && _destLng != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(_destLat!, _destLng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Destino'),
          ),
        );
      }

      _polylines.clear();
    });
  }

  Future<void> _startTravel() async {
    if (_isActing) return;
    setState(() => _isActing = true);

    try {
      if (_hubConnected) {
        final signalR = Modular.get<SignalRService>();
        await signalR.startTravel(widget.travelId);
        // Give the backend a moment to process before reloading
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        // Fallback to HTTP if SignalR not connected
        final dio = Modular.get<Dio>();
        await dio.post('${AppConfig.getBaseUrl()}/api/travels/${widget.travelId}/start');
      }
      if (!mounted) return;
      _loadTravel();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao iniciar viagem'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _finishTravel() async {
    if (_isActing) return;
    setState(() => _isActing = true);

    try {
      if (_hubConnected) {
        final signalR = Modular.get<SignalRService>();
        await signalR.finishTravel(widget.travelId);
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        final dio = Modular.get<Dio>();
        await dio.post('${AppConfig.getBaseUrl()}/api/travels/${widget.travelId}/finish');
      }
      if (!mounted) return;
      _loadTravel();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao finalizar viagem'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _cancelTravel() async {
    if (_isActing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar viagem'),
        content: const Text('Tem certeza que deseja cancelar esta viagem?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sim, cancelar')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isActing = true);

    try {
      final dio = Modular.get<Dio>();
      await dio.post('${AppConfig.getBaseUrl()}/api/travels/${widget.travelId}/cancel');
      if (!mounted) return;
      _loadTravel();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao cancelar viagem'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _goHome() async {
    _locationTimer?.cancel();
    if (_hubConnected) {
      await Modular.get<SignalRService>().disconnect('travel-management');
    }
    await Modular.get<TravelLocalRepository>().clearTravels();
    Modular.to.navigate('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_statusLabel(), style: const TextStyle(color: Color(0xFF4E4E4E), fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4E4E4E)),
          onPressed: () => Modular.to.pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  String _statusLabel() {
    switch (_status) {
      case 'Accepted':
        return 'A caminho do passageiro';
      case 'InProgress':
        return 'Viagem em andamento';
      case 'Completed':
        return 'Viagem concluída';
      case 'Cancelled':
        return 'Viagem cancelada';
      default:
        return 'Viagem';
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erro ao carregar viagem', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFF4E4E4E)), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadTravel,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_status == 'Completed' || _status == 'Cancelled') {
      return _buildTerminalState();
    }

    return _buildActiveTravel();
  }

  Widget _buildTerminalState() {
    final isCompleted = _status == 'Completed';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.task_alt : Icons.cancel,
              size: 64,
              color: isCompleted ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              isCompleted ? 'Viagem concluída!' : 'Viagem cancelada',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: _goHome,
              child: const Text('Voltar para Home', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTravel() {
    final isAccepted = _status == 'Accepted';

    return SafeArea(
      child: Column(
        children: [
          // Status indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: isAccepted ? Colors.orange.shade50 : Colors.green.shade50,
            child: Row(
              children: [
                Icon(
                  isAccepted ? Icons.access_time : Icons.directions_car,
                  color: isAccepted ? Colors.orange : Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAccepted ? 'Aguardando início' : 'Em andamento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAccepted ? Colors.orange.shade800 : Colors.green.shade800,
                        ),
                      ),
                      if (_passengerName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Passageiro: $_passengerName',
                          style: TextStyle(color: isAccepted ? Colors.orange.shade700 : Colors.green.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: _passengerLat != null
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_passengerLat!, _passengerLng!),
                      zoom: 14,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    zoomControlsEnabled: false,
                    myLocationEnabled: true,
                  )
                : const Center(child: Text('Localização não disponível')),
          ),

          // Travel info panel
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_departureAddress != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.trip_origin, color: Color(0xFF4685C0), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_departureAddress!, style: const TextStyle(color: Color(0xFF4E4E4E), fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                if (_destinationAddress != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.flag, color: Color(0xFF4685C0), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_destinationAddress!, style: const TextStyle(color: Color(0xFF4E4E4E), fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    const Icon(Icons.route, color: Color(0xFF4685C0), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_distanceToDestination ?? 0} m — ${_timeHours ?? 0}h ${_timeMinutes ?? 0}min',
                      style: const TextStyle(color: Color(0xFF4E4E4E), fontSize: 14),
                    ),
                  ],
                ),
                if (_hubConnected)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        const Text('Compartilhando localização', style: TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isActing ? null : _cancelTravel,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isActing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Cancelar', style: TextStyle(color: Colors.red, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isActing ? null : (isAccepted ? _startTravel : _finishTravel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAccepted ? Colors.orange : Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isActing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                isAccepted ? 'Iniciar Viagem' : 'Finalizar Viagem',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
