import 'dart:convert' show jsonEncode;
import 'dart:developer' show log;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/models/local_data_models.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/maps/directions_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';

class IncomingOrderSheet extends StatefulWidget {
  final Map<String, dynamic> order;

  const IncomingOrderSheet({super.key, required this.order});

  @override
  State<IncomingOrderSheet> createState() => _IncomingOrderSheetState();

  static void show(BuildContext context, Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => IncomingOrderSheet(order: order),
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

  @override
  Widget build(BuildContext context) {
    final orderId = widget.order['orderId'] as String;
    final distance = widget.order['distanceToPassengerInMeters'] as int;
    final timeHours = widget.order['averageTravelTimeInHours'] as int;
    final timeMinutes = widget.order['averageTravelTimeInMinutes'] as int;
    final totalDest = widget.order['distanceToDestinationInMeters'] as int;
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
          const Row(
            children: [
              Icon(Icons.directions_car, color: Color(0xFF4685C0)),
              SizedBox(width: 8),
              Text(
                'Nova Viagem',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4E4E4E)),
              ),
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
              Text('$distance m ate o passageiro', style: const TextStyle(color: Color(0xFF4E4E4E))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xFF4685C0), size: 20),
              const SizedBox(width: 8),
              Text('$totalDest m ate o destino', style: const TextStyle(color: Color(0xFF4E4E4E))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer, color: Color(0xFF4685C0), size: 20),
              const SizedBox(width: 8),
              Text('${timeHours}h ${timeMinutes}min', style: const TextStyle(color: Color(0xFF4E4E4E))),
            ],
          ),
          const SizedBox(height: 24),
          // Error message container
          if (_status == _AcceptStatus.error && _errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : () => _deny(context, orderId),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: _status == _AcceptStatus.denying ? Colors.red.shade300 : Colors.red,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _status == _AcceptStatus.denying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Text('Recusar', style: TextStyle(color: Colors.red, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _accept(context, orderId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _status == _AcceptStatus.success ? Colors.green : const Color(0xFF4685C0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _status == _AcceptStatus.accepting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : _status == _AcceptStatus.success
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text('Viagem aceita!', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        )
                      : const Text('Aceitar', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
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

      // Success feedback — show confirmation for 1.5s then navigate to active travel
      setState(() => _status = _AcceptStatus.success);
      await Future.delayed(const Duration(milliseconds: 1500));

      // Get travelId from response
      final travelId = response.data['travelId'] as String;
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

      // Open Google Maps navigation to destination
      final destLat = widget.order['destinationLatitude'] as num;
      final destLng = widget.order['destinationLongitude'] as num;
      final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1'
          '&destination=$destLat,$destLng'
          '&travelmode=driving';

      try {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } catch (_) {
        // Google Maps not available — continue to active travel page
      }

      Navigator.of(context).pop();
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
    setState(() {
      _status = _AcceptStatus.denying;
      _errorMessage = null;
    });

    try {
      await Modular.get<SignalRService>().denyOrder(orderId);
      Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _status = _AcceptStatus.error;
        _errorMessage = 'Erro ao recusar viagem. Tente novamente.';
      });
    }
  }

  Future<void> _loadDriverLocation() async {
    final locationService = Modular.get<LocationService>();
    final result = await locationService.getCurrentPosition();

    final passLat = (widget.order['passengerLatitude'] as num).toDouble();
    final passLng = (widget.order['passengerLongitude'] as num).toDouble();
    final destLat = (widget.order['destinationLatitude'] as num).toDouble();
    final destLng = (widget.order['destinationLongitude'] as num).toDouble();

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
  }
}
