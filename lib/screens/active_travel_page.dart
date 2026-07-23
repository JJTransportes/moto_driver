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
import 'package:moto_driver/core/maps/directions_service.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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

  double? _passengerLat;
  double? _passengerLng;
  double? _destLat;
  double? _destLng;

  bool _isActing = false;
  bool _hubConnected = false;
  Timer? _locationTimer;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  Map<String, dynamic>? _pickupRoute;
  Map<String, dynamic>? _tripRoute;

  Map<String, dynamic>? get _currentRoute {
    if (_status == 'Accepted') return _pickupRoute;
    if (_status == 'InProgress') return _tripRoute;
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Extract route arguments only after the widget is in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) => _extractRouteArgs());
    _loadTravel();
  }

  void _extractRouteArgs() {
    if (!mounted) return;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map<String, dynamic>) {
      _pickupRoute = routeArgs['pickupRoute'] as Map<String, dynamic>?;
      _tripRoute = routeArgs['tripRoute'] as Map<String, dynamic>?;
      // Re-render map if routes were extracted after loadTravel completed
      if (_pickupRoute != null || _tripRoute != null) {
        _updateMapMarkers();
      }
    }
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

        // Parse routes from API response (fallback if not passed via args)
        if (_pickupRoute == null && routes.isNotEmpty) {
          _pickupRoute = routes[0] as Map<String, dynamic>;
        }
        if (_tripRoute == null && routes.length > 1) {
          _tripRoute = routes[1] as Map<String, dynamic>;
        }

        // Extract coordinates from routes
        _passengerLat = (_pickupRoute?['destinationLatitude'] as num?)?.toDouble()
            ?? (routes.isNotEmpty ? (routes[0]['initialLatitude'] as num?)?.toDouble() : null);
        _passengerLng = (_pickupRoute?['destinationLongitude'] as num?)?.toDouble()
            ?? (routes.isNotEmpty ? (routes[0]['initialLongitude'] as num?)?.toDouble() : null);
        _destLat = (_tripRoute?['destinationLatitude'] as num?)?.toDouble()
            ?? (routes.isNotEmpty ? (routes[0]['destinationLatitude'] as num?)?.toDouble() : null);
        _destLng = (_tripRoute?['destinationLongitude'] as num?)?.toDouble()
            ?? (routes.isNotEmpty ? (routes[0]['destinationLongitude'] as num?)?.toDouble() : null);

        // Endereços das rotas
        _departureAddress = _pickupRoute?['destinationAddress'] as String?;
        _destinationAddress = _tripRoute?['destinationAddress'] as String?;

        _isLoading = false;
      });

      _updateMapMarkers();

      // Connect to travel-management hub
      // Only start location tracking when travel is InProgress
      if (_status == 'Accepted' || _status == 'InProgress') {
        await _connectManagementHub();
        if (_status == 'InProgress') {
          _startLocationTracking();
        }
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
      _polylines.clear();

      // Marcadores
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

      // Polyline da rota atual (Accepted → pickup, InProgress → trip)
      final route = _currentRoute;
      if (route != null) {
        final encoded = route['encodedPolyline'] as String?;
        if (encoded != null && encoded.isNotEmpty) {
          try {
            final points = DirectionsResult.decode(encoded);
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: const Color(0xFF4685C0),
                width: 4,
              ),
            );
          } catch (_) {
            // Polyline inválida — apenas não renderiza
          }
        }
      }
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
        // Get current location to send with finish event
        double? lat;
        double? lng;
        try {
          final locationService = Modular.get<LocationService>();
          final pos = await locationService.getCurrentPosition();
          if (pos.isGranted) {
            lat = pos.position!.latitude;
            lng = pos.position!.longitude;
          }
        } catch (_) {
          // Location is optional — proceed without it
        }

        final signalR = Modular.get<SignalRService>();
        await signalR.finishTravel(widget.travelId, latitude: lat, longitude: lng);
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

  /// Abre Google Maps com destino baseado na rota atual
  Future<void> _navigateToDestination() async {
    final route = _currentRoute;
    if (route == null) return;

    final activeRoute = _status == 'Accepted' ? _pickupRoute : _tripRoute;
    final destLat = activeRoute?['destinationLatitude'] as num?;
    final destLng = activeRoute?['destinationLongitude'] as num?;

    if (destLat == null || destLng == null) return;

    final url = 'https://www.google.com/maps/dir/?api=1'
        '&destination=$destLat,$destLng'
        '&travelmode=driving';

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App de mapas não disponível'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFF4E4E4E)),
                textAlign: TextAlign.center,
              ),
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
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dados da rota atual
                if (isAccepted && _departureAddress != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin, color: Color(0xFF4685C0), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Embarque: ${_departureAddress!}', style: const TextStyle(color: Color(0xFF4E4E4E), fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                if (!isAccepted && _departureAddress != null)
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
                // Distância e tempo da rota atual
                ...() {
                  final route = _currentRoute;
                  final dist = route?['distanceMeters'] as int?;
                  final timeMin = route?['timeMinutes'] as int?;
                  if (dist != null && timeMin != null) {
                    final h = timeMin ~/ 60;
                    final m = timeMin % 60;
                    return [
                      Row(
                        children: [
                          const Icon(Icons.route, color: Color(0xFF4685C0), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$dist m — ${h}h ${m}min',
                            style: const TextStyle(color: Color(0xFF4E4E4E), fontSize: 14),
                          ),
                        ],
                      ),
                    ];
                  }
                  return [const SizedBox.shrink()];
                }(),
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
                const SizedBox(height: 12),
                // Botão de navegação
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToDestination,
                    icon: const Icon(Icons.directions, color: Colors.white, size: 20),
                    label: Text(
                      isAccepted ? 'Navegar até o passageiro' : 'Navegar até o destino',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAccepted ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
