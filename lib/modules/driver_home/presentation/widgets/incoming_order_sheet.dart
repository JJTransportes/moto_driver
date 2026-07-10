import 'dart:convert' show jsonEncode;
import 'dart:developer' show log;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/models/local_data_models.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/maps/directions_service.dart';
import 'package:url_launcher/url_launcher.dart';

class IncomingOrderSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onDenied;

  const IncomingOrderSheet({super.key, required this.order, this.onDenied});

  @override
  State<IncomingOrderSheet> createState() => _IncomingOrderSheetState();

  static void show(BuildContext context, Map<String, dynamic> order, {VoidCallback? onDenied}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => IncomingOrderSheet(order: order, onDenied: onDenied),
    );
  }
}

enum _AcceptStatus { idle, accepting, denying, success, error }

class _IncomingOrderSheetState extends State<IncomingOrderSheet> {
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _driverLocation;
  bool _mapLoaded = false;

  _AcceptStatus _status = _AcceptStatus.idle;
  String? _errorMessage;

  // Fallback: locally-computed distance/time when backend values are missing
  int? _distanceMeters;
  int? _timeMinutes;
  bool _fallbackLoading = false;

  @override
  Widget build(BuildContext context) {
    final orderId = widget.order['orderId'] as String;
    final distance = (widget.order['distanceToPassengerInMeters'] as int?) ?? 0;
    final timeHours = (widget.order['averageTravelTimeInHours'] as int?) ?? 0;
    final timeMinutes = (widget.order['averageTravelTimeInMinutes'] as int?) ?? 0;
    final totalDest = (widget.order['distanceToDestinationInMeters'] as int?) ?? 0;

    // Fallback — if backend didn't send distance/time, calculate locally via Google Maps
    final shouldFallback = distance == 0 && totalDest == 0 && _driverLocation != null;
    final passLat = (widget.order['passengerLatitude'] as num).toDouble();
    final passLng = (widget.order['passengerLongitude'] as num).toDouble();

    final isLoading = _status == _AcceptStatus.accepting || _status == _AcceptStatus.denying;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com título + botões de ação
          Row(
            children: [
              const Icon(Icons.directions_car, color: Color(0xFF4685C0)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Nova Viagem',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4E4E4E)),
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                _IconActionButton(
                  icon: Icons.close,
                  color: Colors.red,
                  tooltip: 'Recusar',
                  onPressed: () => _deny(context, orderId),
                ),
                const SizedBox(width: 12),
                _IconActionButton(
                  icon: _status == _AcceptStatus.success ? Icons.check : Icons.check_circle_outline,
                  color: _status == _AcceptStatus.success ? Colors.green : const Color(0xFF4685C0),
                  tooltip: 'Aceitar',
                  onPressed: () => _accept(context, orderId),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _mapLoaded
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(passLat, passLng),
                      zoom: 13,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    zoomControlsEnabled: false,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 12),
          // Endereço de partida (origem do passageiro)
          if (widget.order['departureAddress'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.trip_origin, color: Color(0xFF4685C0), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.order['departureAddress'] as String,
                      style: const TextStyle(color: Color(0xFF4E4E4E)),
                    ),
                  ),
                ],
              ),
            ),
          // Endereço de destino
          if (widget.order['destinationAddress'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.flag, color: Color(0xFF4685C0), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.order['destinationAddress'] as String,
                      style: const TextStyle(color: Color(0xFF4E4E4E)),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF4685C0), size: 20),
              const SizedBox(width: 8),
              Text(
                _resolveDistanceText(distance, shouldFallback),
                style: const TextStyle(color: Color(0xFF4E4E4E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xFF4685C0), size: 20),
              const SizedBox(width: 8),
              Text(
                _resolveTotalDestText(totalDest, shouldFallback),
                style: const TextStyle(color: Color(0xFF4E4E4E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer, color: Color(0xFF4685C0), size: 20),
              const SizedBox(width: 8),
              Text(
                _resolveTimeText(timeHours, timeMinutes, shouldFallback),
                style: const TextStyle(color: Color(0xFF4E4E4E)),
              ),
            ],
          ),
          // Error message container
          if (_status == _AcceptStatus.error && _errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    log(jsonEncode(widget.order), name: 'travel-order');
    _loadDriverLocation();
  }

  Future<void> _accept(BuildContext context, String id) async {
    setState(() {
      _status = _AcceptStatus.accepting;
      _errorMessage = null;
    });

    try {
      final dio = Modular.get<Dio>();
      final orderId = widget.order['orderId'] as String;
      final response = await dio.post('${AppConfig.getBaseUrl()}/api/travels/orders/$orderId/accept');

      // Get travelId from response
      final travelId = response.data['travelId'] as String;

      // Close the sheet immediately
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Persist travel locally
      final travelRepo = Modular.get<TravelLocalRepository>();
      await travelRepo.saveActiveTravel(
        TravelLocalData(
          travelId: travelId,
          status: 'Accepted',
          departureAddress: widget.order['departureAddress'] as String?,
          destinationAddress: widget.order['destinationAddress'] as String?,
          createdAt: DateTime.now(),
        ),
      );

      // Open Google Maps navigation to destination (best-effort)
      final destLat = widget.order['destinationLatitude'] as num;
      final destLng = widget.order['destinationLongitude'] as num;
      final googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1'
          '&destination=$destLat,$destLng'
          '&travelmode=driving';

      try {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } catch (_) {
        // Google Maps not available — continue to active travel page
      }

      // Navigate to active travel
      Modular.to.pushNamed('/active-travel', arguments: {'travelId': travelId});
    } on DioException catch (e) {
      String message;
      switch (e.response?.statusCode) {
        case 401:
          message = 'Sessão expirada. Faça login novamente.';
          break;
        case 409:
          message = 'Viagem já foi aceita por outro motorista.';
          break;
        case 404:
          message = 'Viagem não encontrada.';
          break;
        default:
          message = 'Erro ao aceitar viagem. Tente novamente.';
      }

      setState(() {
        _status = _AcceptStatus.error;
        _errorMessage = message;
      });
    }
  }

  Future<void> _deny(BuildContext context, String orderId) async {
    // Notify parent that this order was denied (for duplicate tracking)
    widget.onDenied?.call();

    // Close the sheet immediately — denial is fire-and-forget
    Navigator.of(context).pop();

    try {
      final dio = Modular.get<Dio>();
      await dio.post('${AppConfig.getBaseUrl()}/api/travels/orders/$orderId/deny');
    } on DioException catch (e) {
      // Log the error but don't block the UI — backend already recorded the denial
      log('Deny failed (order $orderId): ${e.response?.statusCode} ${e.response?.statusMessage}',
          name: 'travel-deny');
    }
  }

  Future<void> _loadDriverLocation() async {
    final locationService = Modular.get<LocationService>();
    final result = await locationService.getCurrentPosition();

    final passLat = (widget.order['passengerLatitude'] as num).toDouble();
    final passLng = (widget.order['passengerLongitude'] as num).toDouble();
    final destLat = (widget.order['destinationLatitude'] as num).toDouble();
    final destLng = (widget.order['destinationLongitude'] as num).toDouble();

    final distance = (widget.order['distanceToPassengerInMeters'] as int?) ?? 0;
    final totalDest = (widget.order['distanceToDestinationInMeters'] as int?) ?? 0;

    setState(() {
      if (result.isGranted) {
        _driverLocation = LatLng(result.position!.latitude, result.position!.longitude);
      }

      _markers = {
        Marker(
          markerId: const MarkerId('passenger'),
          position: LatLng(passLat, passLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Passageiro'),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat, destLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destino'),
        ),
        if (_driverLocation != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Você'),
          ),
      };

      final encodedPolyline = widget.order['encodedPolyline'] as String?;
      if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
        final result = DirectionsResult(
          distanceMeters: 0,
          timeMinutes: 0,
          encodedPolyline: encodedPolyline,
          startLat: passLat,
          startLng: passLng,
          endLat: destLat,
          endLng: destLng,
        );
        final points = result.decodePolyline();
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: const Color(0xFF4685C0),
            width: 4,
          ),
        };
      }

      _mapLoaded = true;
    });

    // Fallback: calculate distance/time locally if backend values are zero/missing
    if (distance == 0 && totalDest == 0 && _driverLocation != null) {
      _calculateFallbackDistance(passLat, passLng, destLat, destLng);
    }
  }

  /// Calculates distance/time using Google Maps Directions API as fallback
  Future<void> _calculateFallbackDistance(
    double passLat,
    double passLng,
    double destLat,
    double destLng,
  ) async {
    setState(() => _fallbackLoading = true);

    try {
      final directionsService = Modular.get<DirectionsService>();
      final result = await directionsService.getDirections(
        _driverLocation!.latitude,
        _driverLocation!.longitude,
        destLat,
        destLng,
      );

      if (result != null && mounted) {
        setState(() {
          _distanceMeters = result.distanceMeters;
          _timeMinutes = result.timeMinutes;
          _fallbackLoading = false;
        });
      } else {
        if (mounted) setState(() => _fallbackLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _fallbackLoading = false);
    }
  }

  String _resolveDistanceText(int distance, bool shouldFallback) {
    if (shouldFallback) {
      if (_fallbackLoading) return 'Calculando distância...';
      if (_distanceMeters != null) return '$_distanceMeters m até o passageiro (estimado)';
      return 'Distância não disponível';
    }
    return '$distance m até o passageiro';
  }

  String _resolveTotalDestText(int totalDest, bool shouldFallback) {
    if (shouldFallback) {
      if (_fallbackLoading) return 'Calculando...';
      return '— até o destino';
    }
    return '$totalDest m até o destino';
  }

  String _resolveTimeText(int timeHours, int timeMinutes, bool shouldFallback) {
    if (shouldFallback) {
      if (_fallbackLoading) return 'Calculando...';
      if (_timeMinutes != null) {
        final h = _timeMinutes! ~/ 60;
        final m = _timeMinutes! % 60;
        return '${h}h ${m}min (estimado)';
      }
      return 'Tempo não disponível';
    }
    return '${timeHours}h ${timeMinutes}min';
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.color,
    this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: color.withAlpha(25),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}
