import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:developer' show log;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/core/local_db/models/local_data_models.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/maps/directions_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';

enum OrderDecision { accepted, denied }

class IncomingOrderSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onDenied;

  final void Function(
    OrderDecision decision,
    Map<String, dynamic>? acceptResult,
  )?
  onDecision;

  const IncomingOrderSheet({
    super.key,
    required this.order,
    this.onDenied,
    this.onDecision,
  });

  @override
  State<IncomingOrderSheet> createState() => _IncomingOrderSheetState();

  static void show(
    BuildContext context,
    Map<String, dynamic> order, {
    VoidCallback? onDenied,
  }) {
    showModalBottomSheet(
      useSafeArea: true,
      constraints: BoxConstraints.expand(
        width: MediaQuery.sizeOf(context).width,
        height: MediaQuery.sizeOf(context).height * 0.8,
      ),
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

  // F16: `isLoading` (derivado de `_status`) só esconde os botões depois do
  // rebuild — um duplo toque entre os dois toques do usuário e o frame
  // seguinte ainda dispara `_accept`/`_deny` duas vezes. Guarda síncrona,
  // checada antes de qualquer `await`, fecha essa janela.
  bool _actionInFlight = false;

  // Alinhado ao prazo de resposta do backend (20s) — passageiro agora vê
  // esse mesmo prazo via evento DriverContacted, então os dois lados
  // precisam bater. MotoCountdownRing controla a contagem visualmente e
  // dispara _autoReject sozinho ao chegar em zero (onTimeout).
  static const int _rejectTimeoutSeconds = 20;

  @override
  Widget build(BuildContext context) {
    final orderId = widget.order['orderId'] as String;
    final distance = (widget.order['distanceToPassengerInMeters'] as int?) ?? 0;
    final timeHours = (widget.order['averageTravelTimeInHours'] as int?) ?? 0;
    final timeMinutes =
        (widget.order['averageTravelTimeInMinutes'] as int?) ?? 0;
    final totalDest =
        (widget.order['distanceToDestinationInMeters'] as int?) ?? 0;

    final passLat = (widget.order['passengerLatitude'] as num).toDouble();
    final passLng = (widget.order['passengerLongitude'] as num).toDouble();

    final isLoading =
        _status == _AcceptStatus.accepting || _status == _AcceptStatus.denying;

    return MotoGlass(
      level: GlassLevel.sheet,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: título + anel de contagem regressiva
          Row(
            children: [
              const MotoTile(
                icon: Icons.directions_car,
                accent: true,
                size: 40,
              ),
              const SizedBox(width: MotoSpace.s3),
              Expanded(
                child: Text(
                  'Nova viagem',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              MotoCountdownRing(
                seconds: _rejectTimeoutSeconds,
                size: 52,
                onTimeout: _autoReject,
              ),
            ],
          ),
          const SizedBox(height: MotoSpace.s4),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.order['departureAddress'] != null &&
                      widget.order['destinationAddress'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MotoSpace.s4),
                      child: MotoRoute(
                        from: (
                          widget.order['departureAddress'] as String,
                          'Embarque',
                        ),
                        to: (
                          widget.order['destinationAddress'] as String,
                          'Destino',
                        ),
                      ),
                    ),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.16,
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
                  const SizedBox(height: MotoSpace.s4),
                  MotoMetrics(
                    items: [
                      (
                        _metricDistanceValue(distance),
                        _metricDistanceUnit(distance),
                        'Até o passageiro',
                      ),
                      (
                        _metricDistanceValue(totalDest),
                        _metricDistanceUnit(totalDest),
                        'Até o destino',
                      ),
                      (_resolveTimeText(timeHours, timeMinutes), '', 'Duração'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MotoSpace.s5),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: MotoButton(
                    label: 'Recusar',
                    variant: MotoButtonVariant.glass,
                    large: false,
                    onPressed: () => _deny(context, orderId),
                  ),
                ),
                const SizedBox(width: MotoSpace.s3),
                Expanded(
                  flex: 2,
                  child: MotoButton(
                    label: _status == _AcceptStatus.success
                        ? 'Aceita!'
                        : 'Aceitar',
                    onPressed: () => _accept(context, orderId),
                  ),
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
                  color: context.moto.dangerSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.moto.danger),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: context.moto.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: context.moto.danger,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    if (_actionInFlight) return;
    _actionInFlight = true;
    setState(() {
      _status = _AcceptStatus.accepting;
      _errorMessage = null;
    });

    try {
      // Obtain current GPS position to send to backend
      final locationService = Modular.get<LocationService>();
      final locResult = await locationService.getCurrentPosition();

      final dio = Modular.get<Dio>();
      final orderId = widget.order['orderId'] as String;

      // Build request body with optional GPS data
      final body = <String, dynamic>{};
      if (locResult.isGranted && locResult.position != null) {
        body['currentLatitude'] = locResult.position!.latitude;
        body['currentLongitude'] = locResult.position!.longitude;
      }

      final response = await dio.post(
        '${AppConfig.getBaseUrl()}/api/travels/orders/$orderId/accept',
        data: body.isNotEmpty ? body : null,
      );

      // Get travelId and routes from response
      final travelId = response.data['travelId'] as String;
      final routesList = response.data['routes'] as List? ?? [];
      final pickupRoute = routesList.isNotEmpty
          ? routesList[0] as Map<String, dynamic>
          : null;
      final tripRoute = routesList.length > 1
          ? routesList[1] as Map<String, dynamic>
          : null;

      final acceptResult = {
        'travelId': travelId,
        'pickupRoute': pickupRoute,
        'tripRoute': tripRoute,
      };

      // Modo embutido: o dono (OrderAlertPage) decide a navegação de saída.
      final onDecision = widget.onDecision;
      if (onDecision != null) {
        NotificationService.setSheetVisible(false);
        await _persistActiveTravel(travelId, pickupRoute, tripRoute);
        onDecision(OrderDecision.accepted, acceptResult);
        return;
      }

      // Modo modal (SignalR): comportamento atual preservado.
      // Close the sheet immediately
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // RF05: Sheet fechado — permitir foreground notifications novamente
      NotificationService.setSheetVisible(false);

      await _persistActiveTravel(travelId, pickupRoute, tripRoute);

      // Navigate to active travel with route data
      Modular.to.pushNamed('/active-travel', arguments: acceptResult);
    } on DioException catch (e) {
      // 403: a oferta já passou pro próximo motorista da fila (timeout de
      // 20s) — é definitivo, não transitório. Não faz sentido deixar o card
      // aberto pra um reenvio, então fecha igual ao fluxo de recusa.
      if (e.response?.statusCode == 403) {
        const message = 'Essa corrida não está mais disponível.';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(message),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        final onDecision = widget.onDecision;
        if (onDecision != null) {
          NotificationService.setSheetVisible(false);
          onDecision(OrderDecision.denied, null);
        } else {
          widget.onDenied?.call();
          if (context.mounted) Navigator.of(context).pop();
          NotificationService.setSheetVisible(false);
        }
        return;
      }

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

      _actionInFlight = false;
      setState(() {
        _status = _AcceptStatus.error;
        _errorMessage = message;
      });
    }
  }

  /// Persiste a viagem aceita no cache local (usado nos dois modos).
  Future<void> _persistActiveTravel(
    String travelId,
    Map<String, dynamic>? pickupRoute,
    Map<String, dynamic>? tripRoute,
  ) async {
    final travelRepo = Modular.get<TravelLocalRepository>();
    await travelRepo.saveActiveTravel(
      TravelLocalData(
        travelId: travelId,
        status: 'Accepted',
        departureAddress:
            pickupRoute?['destinationAddress'] as String? ??
            widget.order['departureAddress'] as String?,
        destinationAddress:
            tripRoute?['destinationAddress'] as String? ??
            widget.order['destinationAddress'] as String?,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _deny(BuildContext context, String orderId) async {
    if (_actionInFlight) return;
    _actionInFlight = true;

    final onDecision = widget.onDecision;
    if (onDecision != null) {
      // Modo embutido: o dono decide a saída; sem pop.
      NotificationService.setSheetVisible(false);
      onDecision(OrderDecision.denied, null);
    } else {
      // Modo modal: notifica o pai (duplicate tracking) e fecha o sheet.
      widget.onDenied?.call();
      // Close the sheet immediately — denial is fire-and-forget
      Navigator.of(context).pop();
      // RF05: Sheet fechado — permitir foreground notifications novamente
      NotificationService.setSheetVisible(false);
    }

    try {
      final signalR = Modular.get<SignalRService>();
      await signalR.denyOrder(orderId);
    } catch (_) {
      try {
        final dio = Modular.get<Dio>();
        await dio.post(
          '${AppConfig.getBaseUrl()}/api/travels/orders/$orderId/deny',
        );
      } on DioException catch (e) {
        // Log the error but don't block the UI — backend already recorded the denial
        log(
          'Deny failed (order $orderId): ${e.response?.statusCode} ${e.response?.statusMessage}',
          name: 'travel-deny',
        );
      }
    }
  }

  void _autoReject() {
    if (!mounted) return;
    final orderId = widget.order['orderId'] as String;

    final onDecision = widget.onDecision;
    if (onDecision != null) {
      // Modo embutido: sem pop — o dono decide a saída.
      NotificationService.setSheetVisible(false);
      onDecision(OrderDecision.denied, null);
    } else {
      // Modo modal: notifica o pai (duplicate tracking) e fecha o sheet.
      widget.onDenied?.call();
      // Close the sheet
      Navigator.of(context).pop();
    }

    // Fire-and-forget deny request (SignalR first, REST fallback)
    try {
      final signalR = Modular.get<SignalRService>();
      signalR.denyOrder(orderId);
    } catch (_) {
      try {
        final dio = Modular.get<Dio>();
        dio.post('${AppConfig.getBaseUrl()}/api/travels/orders/$orderId/deny');
      } on DioException catch (e) {
        log(
          'Auto-deny failed (order $orderId): ${e.response?.statusCode} ${e.response?.statusMessage}',
          name: 'travel-deny',
        );
      }
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
        _driverLocation = LatLng(
          result.position!.latitude,
          result.position!.longitude,
        );
      }

      _markers = {
        Marker(
          markerId: const MarkerId('passenger'),
          position: LatLng(passLat, passLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
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
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: 'Você'),
          ),
      };

      // Tentar usar routeJson do payload (travel-v2+) — rota pré-calculada
      final routeJson = widget.order['routeJson'];
      if (routeJson != null) {
        try {
          final routeData = routeJson is String
              ? jsonDecode(routeJson)
              : routeJson;
          final encodedPolyline = routeData['encodedPolyline'] as String?;
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
            _polylines = MotoMapRouteStyle.polylines(
              id: 'route',
              points: points,
            );
          }
        } catch (_) {
          // Fallback: tentar encodedPolyline direto do payload
        }
      }

      // Fallback: encodedPolyline direto (backends antigos ou se routeJson falhou)
      if (_polylines.isEmpty) {
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
          _polylines = MotoMapRouteStyle.polylines(
            id: 'route',
            points: points,
          );
        }
      }

      _mapLoaded = true;
    });
  }

  String _metricDistanceValue(int meters) =>
      meters >= 1000 ? (meters / 1000).toStringAsFixed(1) : '$meters';

  String _metricDistanceUnit(int meters) => meters >= 1000 ? 'km' : 'm';

  String _resolveTimeText(int timeHours, int timeMinutes) {
    return '${timeHours}h ${timeMinutes}min';
  }
}
