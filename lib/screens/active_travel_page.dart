import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/errors/user_error_message.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/location/background_location_service.dart';
import 'package:moto_driver/core/location/location_service.dart';
import 'package:moto_driver/core/maps/directions_service.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/chat/data/datasources/phone_dialer.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_get_passenger_phone_usecase.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';
import 'package:moto_driver/modules/chat/presentation/widgets/call_passenger_button.dart';
import 'package:moto_driver/modules/chat/presentation/widgets/chat_action_button.dart';
import 'package:moto_driver/widgets/pickup_proximity_banner.dart';
import 'package:url_launcher/url_launcher.dart';

class ActiveTravelPage extends StatefulWidget {
  final String travelId;

  const ActiveTravelPage({super.key, required this.travelId});

  @override
  State<ActiveTravelPage> createState() => _ActiveTravelPageState();
}

class _ActiveTravelPageState extends State<ActiveTravelPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _error;

  String? _status;
  String? _passengerName;
  String? _passengerPhotoUrl;
  int? _passengerSolicitationCount;
  String? _passengerPartitionName;
  String? _passengerDepartments;
  DateTime? _requestedAt;
  String? _authToken;
  String? _departureAddress;
  String? _destinationAddress;
  String? _cancellationReason;
  String? _cancelledByRole;

  double? _passengerLat;
  double? _passengerLng;
  double? _destLat;
  double? _destLng;

  bool _isActing = false;
  bool _travelPanelExpanded = true;
  bool _navigationCameraEnabled = false;
  GoogleMapController? _mapController;
  bool _hubConnected = false;
  Timer? _locationTimer;
  bool _locationUpdateInFlight = false;
  // F09: conta ciclos consecutivos sem localização válida durante o
  // tracking; após 3 (~30s) mostra aviso — sem isso o motorista não tinha
  // nenhum sinal de que a posição parou de ser compartilhada.
  int _locationFailureStreak = 0;
  bool _locationUnavailable = false;
  StreamSubscription<Map<String, dynamic>>? _travelCancelledSub;
  StreamSubscription<Map<String, dynamic>>? _driverNearbySub;
  StreamSubscription<Map<String, dynamic>>? _driverArrivedSub;
  StreamSubscription<void>? _reconnectedSub;

  // Spec pickup-arrival-alerts: só faz sentido em Accepted; nunca regride
  // (arrived não volta a nearby se um evento atrasado chegar fora de ordem).
  PickupProximity _pickupProximity = PickupProximity.none;

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
    WakelockPlus.enable();
    // Extract route arguments only after the widget is in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) => _extractRouteArgs());
    _loadTravel();

    // RF: cancelamento pelo passageiro precisa refletir aqui em tempo real —
    // antes só a home escutava esse evento, então esta tela (aberta por cima
    // da home) continuava mostrando a viagem como ativa até o motorista
    // tentar finalizar/cancelar e tomar erro do backend.
    _travelCancelledSub = Modular.get<SignalRService>().onTravelCancelled
        .listen((data) {
          if (!mounted) return;
          final travelId = data['travelId'] as String?;
          if (travelId != null && travelId != widget.travelId) return;

          final role = data['cancelledByRole'] as String?;
          setState(() {
            _status = 'Cancelled';
            _cancellationReason = data['reason'] as String?;
            _cancelledByRole = role;
          });
          _syncBackgroundTravelStatus(null);
          _locationTimer?.cancel();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cancelledByMessage(role)),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });

    WidgetsBinding.instance.addObserver(this);
    final signalR = Modular.get<SignalRService>();
    _driverNearbySub = signalR.onDriverNearby.listen(_onProximityAlert);
    _driverArrivedSub = signalR.onDriverArrived.listen(_onProximityAlert);
    // Um alerta emitido com o hub fora do ar não é reenviado: ao reconectar,
    // reidrata pelo estado da viagem.
    _reconnectedSub = signalR.onReconnected.listen(
      (_) => _refreshPickupProximity(),
    );
  }

  /// Abre o chat temporário da viagem (spec pickup-chat-call).
  Future<void> _openChat() async {
    final session = Modular.get<ChatSession>();
    session.setChatOpen(true);
    try {
      await Modular.to.pushNamed(
        '/chat/',
        arguments: {
          'travelId': widget.travelId,
          'title': 'Chat com o passageiro',
        },
      );
    } finally {
      session.setChatOpen(false);
      unawaited(session.refresh());
    }
  }

  /// `DriverNearby` / `DriverArrived` do hub `travel-management`.
  /// `data` = `{travelId, kind: "Nearby"|"Arrived", occurredAt}`.
  void _onProximityAlert(Map<String, dynamic> data) {
    if (!mounted || _status != 'Accepted') return;
    if (data['travelId'] != widget.travelId) return;

    final next = PickupProximity.parse(data['kind'] as String?);
    if (next.index <= _pickupProximity.index) return;
    setState(() => _pickupProximity = next);
  }

  static PickupProximity _maxProximity(PickupProximity a, PickupProximity b) =>
      b.index > a.index ? b : a;

  /// Reidrata só a indicação de proximidade pelo estado atual da viagem —
  /// para o app que volta do segundo plano ou reconecta o hub e perdeu um
  /// alerta. Best-effort: falha silenciosa, não derruba a tela.
  Future<void> _refreshPickupProximity() async {
    if (!mounted || _status != 'Accepted') return;
    try {
      final response = await Modular.get<Dio>().get(
        '${AppConfig.getBaseUrl()}/api/travels/${widget.travelId}',
      );
      if (!mounted) return;

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 'Accepted') return;

      final next = _maxProximity(
        _pickupProximity,
        PickupProximity.parse(data['pickupProximity'] as String?),
      );
      if (next != _pickupProximity) {
        setState(() => _pickupProximity = next);
      }
    } catch (_) {
      // Best-effort — o próximo evento ou resume tenta de novo.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPickupProximity();
    }
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
    WakelockPlus.disable();
    _mapController?.dispose();
    _locationTimer?.cancel();
    _travelCancelledSub?.cancel();
    _driverNearbySub?.cancel();
    _driverArrivedSub?.cancel();
    _reconnectedSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try {
      Modular.get<ChatSession>().stop();
    } catch (_) {
      // Módulo já descartado: nada a parar.
    }
    // F07: NÃO desconectar 'travel-management' aqui — é a mesma conexão que
    // a HomeScreen usa (reportLocation em modo idle, eventos de viagem) e
    // continua montada por baixo desta página. Desconectar deixava a Home
    // "muda" nesse hub até um resume acidental do app reconectar sozinho.
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
      final previousStatus = _status;
      final nextStatus = data['status'] as String?;
      final enteredActiveTravel =
          previousStatus != nextStatus &&
          (nextStatus == 'Accepted' || nextStatus == 'InProgress');

      setState(() {
        _status = nextStatus;
        if (enteredActiveTravel) {
          _navigationCameraEnabled = false;
        }
        _passengerName = data['passengerName'] as String?;
        _passengerPhotoUrl = data['passengerPhotoUrl'] as String?;
        _requestedAt = DateTime.tryParse(data['createdAt']?.toString() ?? '');
        _pickupProximity = _status == 'Accepted'
            ? _maxProximity(
                _pickupProximity,
                PickupProximity.parse(data['pickupProximity'] as String?),
              )
            : PickupProximity.none;

        // Parse routes from API response (fallback if not passed via args)
        if (_pickupRoute == null && routes.isNotEmpty) {
          _pickupRoute = routes[0] as Map<String, dynamic>;
        }
        if (_tripRoute == null && routes.length > 1) {
          _tripRoute = routes[1] as Map<String, dynamic>;
        }

        // Extract coordinates from routes
        _passengerLat =
            (_pickupRoute?['destinationLatitude'] as num?)?.toDouble() ??
            (routes.isNotEmpty
                ? (routes[0]['initialLatitude'] as num?)?.toDouble()
                : null);
        _passengerLng =
            (_pickupRoute?['destinationLongitude'] as num?)?.toDouble() ??
            (routes.isNotEmpty
                ? (routes[0]['initialLongitude'] as num?)?.toDouble()
                : null);
        _destLat =
            (_tripRoute?['destinationLatitude'] as num?)?.toDouble() ??
            (routes.isNotEmpty
                ? (routes[0]['destinationLatitude'] as num?)?.toDouble()
                : null);
        _destLng =
            (_tripRoute?['destinationLongitude'] as num?)?.toDouble() ??
            (routes.isNotEmpty
                ? (routes[0]['destinationLongitude'] as num?)?.toDouble()
                : null);

        // Endereços das rotas
        _departureAddress = _pickupRoute?['destinationAddress'] as String?;
        _destinationAddress = _tripRoute?['destinationAddress'] as String?;
        _cancellationReason = data['cancellationReason'] as String?;
        _cancelledByRole = data['cancelledByRole'] as String?;

        _isLoading = false;
      });

      _syncBackgroundTravelStatus(_status);

      _updateMapMarkers();
      if (enteredActiveTravel) {
        unawaited(_resetMapToOverview());
      }

      // Chat temporário (spec pickup-chat-call): só existe em Accepted.
      final chatSession = Modular.get<ChatSession>();
      if (_status == 'Accepted') {
        chatSession.start(widget.travelId);
      } else {
        chatSession.stop();
      }

      final authStorage = Modular.get<AuthStorage>();
      _authToken = await authStorage.getToken();

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
        _error = userErrorMessage(
          e,
          fallback: 'Não foi possível carregar a viagem. Tente novamente.',
        );
      });
    }
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConfig.getBaseUrl()}$url';
  }

  String _initialsOf(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  Map<String, String>? get _authHeaders {
    final token = _authToken;
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _connectManagementHub() async {
    final signalR = Modular.get<SignalRService>();

    // F07: a HomeScreen (sempre montada por baixo desta página) já conecta
    // 'travel-management' assim que abre e é a dona do ciclo de vida dessa
    // conexão (também usada pelo reportLocation dela quando não há viagem
    // ativa). connect() para e recria a conexão do zero — chamar de novo
    // aqui sem necessidade derrubaria/recriaria à toa a conexão que a Home
    // já mantém. Só conecta se, por algum motivo, ainda não estiver.
    if (signalR.isConnected('travel-management')) {
      if (mounted) setState(() => _hubConnected = true);
      return;
    }

    final authStorage = Modular.get<AuthStorage>();
    final token = await authStorage.getToken();
    if (token == null) return;

    try {
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
    _reportTravelLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _reportTravelLocation(),
    );
  }

  Future<void> _reportTravelLocation() async {
    if (!_hubConnected || _locationUpdateInFlight) return;
    _locationUpdateInFlight = true;
    try {
      final locationService = Modular.get<LocationService>();
      final result = await locationService.getCurrentPosition();
      if (!result.isGranted) {
        _registerLocationFailure();
        return;
      }

      final signalR = Modular.get<SignalRService>();
      await signalR.updateLocation(
        widget.travelId,
        result.position!.latitude,
        result.position!.longitude,
      );
      await _followDriverOnMap(result.position!);
      _registerLocationSuccess();
    } catch (_) {
      // Best-effort — location send failure should not break anything
      _registerLocationFailure();
    } finally {
      _locationUpdateInFlight = false;
    }
  }

  void _registerLocationFailure() {
    if (!mounted) return;
    _locationFailureStreak++;
    if (_locationFailureStreak >= 3 && !_locationUnavailable) {
      setState(() => _locationUnavailable = true);
    }
  }

  void _registerLocationSuccess() {
    _locationFailureStreak = 0;
    if (mounted && _locationUnavailable) {
      setState(() => _locationUnavailable = false);
    }
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Passageiro'),
        ),
      );
      if (_destLat != null && _destLng != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(_destLat!, _destLng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
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
            _polylines.addAll(
              MotoMapRouteStyle.polylines(id: 'route', points: points),
            );
          } catch (_) {
            // Polyline inválida — apenas não renderiza
          }
        }
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_navigationCameraEnabled) {
      unawaited(_recenterNavigationCamera());
    } else {
      unawaited(_resetMapToOverview());
    }
  }

  Future<void> _resetMapToOverview() async {
    final controller = _mapController;
    if (controller == null) return;

    LatLng? target;
    final result = await Modular.get<LocationService>().getCurrentPosition();
    if (result.isGranted && result.position != null) {
      target = LatLng(
        result.position!.latitude,
        result.position!.longitude,
      );
    } else if (_passengerLat != null && _passengerLng != null) {
      target = LatLng(_passengerLat!, _passengerLng!);
    }
    if (target == null || _navigationCameraEnabled) return;

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16, tilt: 0, bearing: 0),
        ),
      );
    } catch (_) {
      // O mapa pode estar sendo recriado durante a troca de estado.
    }
  }

  Future<void> _recenterNavigationCamera() async {
    final result = await Modular.get<LocationService>().getCurrentPosition();
    if (!result.isGranted) return;
    await _followDriverOnMap(result.position!, force: true);
  }

  Future<void> _followDriverOnMap(
    Position position, {
    bool force = false,
  }) async {
    final controller = _mapController;
    if (controller == null || (!_navigationCameraEnabled && !force)) return;

    final heading = position.heading.isFinite && position.heading >= 0
        ? position.heading
        : 0.0;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 18,
            tilt: 55,
            bearing: heading,
          ),
        ),
      );
    } catch (_) {
      // O mapa pode estar sendo recriado enquanto a posição chega.
    }
  }

  void _toggleNavigationCamera() {
    setState(() => _navigationCameraEnabled = !_navigationCameraEnabled);
    if (_navigationCameraEnabled) unawaited(_recenterNavigationCamera());
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
        await dio.post(
          '${AppConfig.getBaseUrl()}/api/travels/${widget.travelId}/start',
        );
      }
      if (!mounted) return;
      _loadTravel();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao iniciar viagem'),
          backgroundColor: context.moto.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _finishTravel() async {
    if (_isActing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar viagem'),
        content: const Text('Tem certeza que deseja finalizar esta viagem?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
        await signalR.finishTravel(
          widget.travelId,
          latitude: lat,
          longitude: lng,
        );
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        final dio = Modular.get<Dio>();
        await dio.post(
          '${AppConfig.getBaseUrl()}/api/travels/${widget.travelId}/finish',
        );
      }
      if (!mounted) return;
      _loadTravel();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao finalizar viagem'),
          backgroundColor: context.moto.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _cancelTravel() async {
    if (_isActing) return;
    var value = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            title: const Text('Cancelar viagem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informe o motivo do cancelamento. Esta informação será registrada no histórico da viagem.',
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Motivo do cancelamento',
                    hintText: 'Descreva o motivo...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) => setDialogState(
                    () => value = text.trim(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Voltar'),
              ),
              TextButton(
                onPressed: value.isEmpty
                    ? null
                    : () => Navigator.of(ctx).pop(value),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: const Text('Confirmar cancelamento'),
              ),
            ],
          );
        },
      ),
    );

    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _isActing = true);

    try {
      final dio = Modular.get<Dio>();
      await dio.post(
        '${AppConfig.getBaseUrl()}/api/travels/${widget.travelId}/cancel',
        data: {'reason': reason},
      );
      if (!mounted) return;
      _loadTravel();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao cancelar viagem'),
          backgroundColor: context.moto.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _goHome() async {
    _locationTimer?.cancel();
    _syncBackgroundTravelStatus(null);
    // F07: ver comentário em dispose() — 'travel-management' é da Home, não
    // desconectar aqui.
    await Modular.get<TravelLocalRepository>().clearTravels();
    Modular.to.navigate('/home');
  }

  void _syncBackgroundTravelStatus(String? status) {
    try {
      unawaited(
        Modular.get<BackgroundLocationService>().setTravelStatus(status),
      );
    } catch (_) {
      // O serviço é exclusivo do Android e pode não existir em testes/iOS.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          _statusLabel(),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.moto.textPrimary, fontSize: 18),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.moto.textPrimary),
          onPressed: () => Modular.to.pop(),
        ),
        actions: [
          if (_status == 'Accepted')
            ValueListenableBuilder<int>(
              valueListenable: Modular.get<ChatSession>().unread,
              builder: (context, unread, _) {
                if (unread <= 0) return const SizedBox.shrink();
                return IconButton(
                  key: const Key('header-chat-button'),
                  tooltip:
                      '$unread mensagem${unread == 1 ? '' : 's'} nova${unread == 1 ? '' : 's'}',
                  onPressed: _openChat,
                  icon: Badge(
                    key: const Key('header-chat-unread-badge'),
                    backgroundColor: context.moto.danger,
                    label: Text(unread > 99 ? '99+' : '$unread'),
                    child: Icon(
                      Icons.notifications_rounded,
                      color: context.moto.danger,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
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

    final url =
        'https://www.google.com/maps/dir/?api=1'
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
              Icon(Icons.error_outline, size: 48, color: context.moto.danger),
              const SizedBox(height: 16),
              const Text(
                'Erro ao carregar viagem',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: context.moto.textPrimary),
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

    if (isCompleted) {
      return MotoCanvas(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MotoSpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MotoSuccessCheck(),
                const SizedBox(height: MotoSpace.s6),
                Text(
                  'Viagem concluída!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MotoSpace.s8),
                MotoButton(
                  label: 'Voltar para a tela inicial',
                  large: false,
                  expand: false,
                  onPressed: _goHome,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MotoCanvas(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MotoSpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_rounded, size: 64, color: context.moto.danger),
              const SizedBox(height: MotoSpace.s4),
              Text(
                'Viagem cancelada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: MotoSpace.s2),
              Text(
                _cancelledByMessage(_cancelledByRole),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_cancellationReason?.isNotEmpty == true) ...[
                const SizedBox(height: MotoSpace.s2),
                Text(
                  'Motivo: ${_cancellationReason!}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: MotoSpace.s8),
              MotoButton(
                label: 'Voltar para a tela inicial',
                variant: MotoButtonVariant.danger,
                large: false,
                expand: false,
                onPressed: _goHome,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cancelledByMessage(String? role) => switch (role) {
    'Driver' => 'A viagem foi cancelada pelo motorista.',
    'Passenger' => 'A viagem foi cancelada pelo passageiro.',
    'Administrator' => 'A viagem foi cancelada pelo administrador.',
    _ => 'A viagem foi cancelada.',
  };

  Widget _buildActiveTravel() {
    final isAccepted = _status == 'Accepted';

    return SafeArea(
      child: Column(
        children: [
          // Status indicator
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0x26246BFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x24246BFD)),
            ),
            child: Row(
              children: [
                MotoAvatar(
                  initials: _initialsOf(_passengerName),
                  size: 44,
                  image:
                      _passengerPhotoUrl != null &&
                          _passengerPhotoUrl!.isNotEmpty
                      ? NetworkImage(
                          _resolveImageUrl(_passengerPhotoUrl!),
                          headers: _authHeaders,
                        )
                      : null,
                ),
                const SizedBox(width: MotoSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MotoStatusBadge.trip(
                        isAccepted ? TripStatus.aceita : TripStatus.emAndamento,
                      ),
                      if (_passengerName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _passengerName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (_passengerSolicitationCount != null)
                          Text(
                            '$_passengerSolicitationCount solicitaç${_passengerSolicitationCount == 1 ? 'ão' : 'ões'} realizada${_passengerSolicitationCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (_passengerPartitionName != null)
                          Text(
                            _passengerDepartments != null
                                ? '$_passengerPartitionName · $_passengerDepartments'
                                : _passengerPartitionName!,
                            style: Theme.of(context).textTheme.bodySmall,
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
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_passengerLat!, _passengerLng!),
                            zoom: 16,
                          ),
                          onMapCreated: _onMapCreated,
                          markers: _markers,
                          polylines: _polylines,
                          zoomControlsEnabled: false,
                          compassEnabled: true,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'navigation-camera',
                          tooltip: _navigationCameraEnabled
                              ? 'Desativar acompanhamento do motorista'
                              : 'Acompanhar motorista',
                          onPressed: _toggleNavigationCamera,
                          backgroundColor: _navigationCameraEnabled
                              ? context.moto.accent
                              : context.moto.bgRaised,
                          foregroundColor: _navigationCameraEnabled
                              ? Colors.white
                              : context.moto.textPrimary,
                          child: Icon(
                            _navigationCameraEnabled
                                ? Icons.navigation_rounded
                                : Icons.my_location_rounded,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(child: Text('Localização não disponível')),
          ),

          // Travel info panel
          GestureDetector(
            key: const ValueKey('travel-info-panel'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() < 120) return;
              final expanded = velocity < 0;
              if (expanded != _travelPanelExpanded) {
                setState(() => _travelPanelExpanded = expanded);
              }
            },
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.moto.bgRaised,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.moto.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  (_travelPanelExpanded ? 20 : 10) +
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Semantics(
                        label: _travelPanelExpanded
                            ? 'Arraste para baixo para ampliar o mapa'
                            : 'Arraste para cima para mostrar as ações',
                        child: Container(
                          key: const ValueKey('travel-panel-handle'),
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: context.moto.textSecondary.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    if (_travelPanelExpanded && isAccepted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            if (_pickupProximity != PickupProximity.none) ...[
                              Expanded(
                                child: CallPassengerButton(
                                  travelId: widget.travelId,
                                  getPassengerPhone:
                                      Modular.get<IGetPassengerPhoneUsecase>(),
                                  dialer: Modular.get<IPhoneDialer>(),
                                  onOpenChat: _openChat,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: ChatActionButton(
                                session: Modular.get<ChatSession>(),
                                onPressed: _openChat,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_travelPanelExpanded && isAccepted)
                      PickupProximityBanner(proximity: _pickupProximity),
                    if (_requestedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_note,
                              color: context.moto.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Solicitada às ${_formatTime(_requestedAt!)}',
                              style: TextStyle(
                                color: context.moto.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Dados da rota atual
                    if (isAccepted && _departureAddress != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_pin,
                              color: context.moto.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Embarque: ${_departureAddress!}',
                                style: TextStyle(
                                  color: context.moto.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isAccepted && _departureAddress != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.trip_origin,
                              color: context.moto.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _departureAddress!,
                                style: TextStyle(
                                  color: context.moto.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_destinationAddress != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag,
                              color: context.moto.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _destinationAddress!,
                                style: TextStyle(
                                  color: context.moto.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Distância e tempo da rota atual
                    if (_travelPanelExpanded)
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
                                Icon(
                                  Icons.route,
                                  color: context.moto.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$dist m — ${h}h ${m}min',
                                  style: TextStyle(
                                    color: context.moto.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ];
                        }
                        return [const SizedBox.shrink()];
                      }(),
                    if (_travelPanelExpanded &&
                        _hubConnected &&
                        !_locationUnavailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: context.moto.success,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Compartilhando localização',
                              style: TextStyle(
                                color: context.moto.success,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // F09: sem isso o indicador acima simplesmente sumia (deixava
                    // de renderizar em silêncio) quando o GPS ficava indisponível
                    // durante a viagem — o motorista não tinha nenhum sinal de
                    // que parou de compartilhar a posição.
                    if (_travelPanelExpanded &&
                        _hubConnected &&
                        _locationUnavailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          onTap: () => Modular.get<LocationService>()
                              .openLocationSettings(),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_off,
                                color: context.moto.warning,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Localização indisponível — toque para ativar o GPS',
                                  style: TextStyle(
                                    color: context.moto.warning,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_travelPanelExpanded) const SizedBox(height: 12),
                    if (_travelPanelExpanded)
                      MotoButton(
                        label: isAccepted
                            ? 'Navegar até o passageiro'
                            : 'Navegar até o destino',
                        icon: Icons.directions,
                        variant: MotoButtonVariant.glass,
                        large: false,
                        onPressed: _navigateToDestination,
                      ),
                    if (_travelPanelExpanded) const SizedBox(height: 16),
                    if (_travelPanelExpanded && isAccepted)
                      Row(
                        children: [
                          Expanded(
                            child: MotoButton(
                              label: 'Cancelar',
                              variant: MotoButtonVariant.danger,
                              large: false,
                              loading: _isActing,
                              onPressed: _isActing ? null : _cancelTravel,
                            ),
                          ),
                          const SizedBox(width: MotoSpace.s4),
                          Expanded(
                            flex: 2,
                            child: MotoButton(
                              label: 'Iniciar viagem',
                              large: false,
                              loading: _isActing,
                              onPressed: _isActing ? null : _startTravel,
                            ),
                          ),
                        ],
                      )
                    else if (_travelPanelExpanded) ...[
                      MotoSwipeToConfirm(
                        label: 'Deslize para finalizar',
                        onConfirmed: () {
                          if (!_isActing) _finishTravel();
                        },
                      ),
                      const SizedBox(height: MotoSpace.s3),
                      MotoButton(
                        label: 'Cancelar viagem',
                        variant: MotoButtonVariant.glass,
                        large: false,
                        loading: _isActing,
                        onPressed: _isActing ? null : _cancelTravel,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
