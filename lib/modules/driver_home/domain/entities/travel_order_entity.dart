import 'dart:developer' show log;

/// Entidade tipada de um travel order (pedido de viagem).
///
/// Espelho do `TravelOrderDetailResponse` do backend (`GET /api/travels/orders/{orderId}`),
/// com serialização camelCase — a mesma usada pelo evento `NewOrder` do hub SignalR.
///
/// Notas:
/// - `fromJson` é null-safe: nenhum campo ausente lança exceção.
/// - `routeJson` é campo **exclusivo do evento `NewOrder` do hub** (travel-v2+).
///   O GET REST não o retorna — apenas `encodedPolyline`. O `IncomingOrderSheet`
///   usa `routeJson` quando presente e cai para `encodedPolyline` como fallback.
class TravelOrderEntity {
  final String orderId;
  final String travelId;
  final String customerId;
  final String? driverId;
  final String status;
  final int distanceToPassengerInMeters;
  final int distanceToDestinationInMeters;
  final int averageTravelTimeInHours;
  final int averageTravelTimeInMinutes;
  final double passengerLatitude;
  final double passengerLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final List<dynamic> routes;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? departureAddress;
  final String? destinationAddress;
  final String? encodedPolyline;

  /// Rota pré-calculada (String JSON ou Map) — campo hub-only; ausente no GET REST.
  final dynamic routeJson;

  const TravelOrderEntity({
    required this.orderId,
    this.travelId = '',
    this.customerId = '',
    this.driverId,
    required this.status,
    this.distanceToPassengerInMeters = 0,
    this.distanceToDestinationInMeters = 0,
    this.averageTravelTimeInHours = 0,
    this.averageTravelTimeInMinutes = 0,
    this.passengerLatitude = 0.0,
    this.passengerLongitude = 0.0,
    this.destinationLatitude = 0.0,
    this.destinationLongitude = 0.0,
    this.routes = const [],
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.departureAddress,
    this.destinationAddress,
    this.encodedPolyline,
    this.routeJson,
  });

  factory TravelOrderEntity.fromJson(Map<String, dynamic> json) {
    double asDouble(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value != null) {
        log('[TRAVEL-ORDER] Campo $key ausente ou inválido — usando 0.0', name: 'travel-order');
      }
      return 0.0;
    }

    DateTime? asDateTime(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return TravelOrderEntity(
      orderId: json['orderId'] as String? ?? '',
      travelId: json['travelId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      driverId: json['driverId'] as String?,
      status: json['status'] as String? ?? '',
      distanceToPassengerInMeters: (json['distanceToPassengerInMeters'] as num?)?.toInt() ?? 0,
      distanceToDestinationInMeters: (json['distanceToDestinationInMeters'] as num?)?.toInt() ?? 0,
      averageTravelTimeInHours: (json['averageTravelTimeInHours'] as num?)?.toInt() ?? 0,
      averageTravelTimeInMinutes: (json['averageTravelTimeInMinutes'] as num?)?.toInt() ?? 0,
      passengerLatitude: asDouble('passengerLatitude'),
      passengerLongitude: asDouble('passengerLongitude'),
      destinationLatitude: asDouble('destinationLatitude'),
      destinationLongitude: asDouble('destinationLongitude'),
      routes: json['routes'] as List? ?? const [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      startedAt: asDateTime('startedAt'),
      finishedAt: asDateTime('finishedAt'),
      cancelledAt: asDateTime('cancelledAt'),
      cancellationReason: json['cancellationReason'] as String?,
      departureAddress: json['departureAddress'] as String?,
      destinationAddress: json['destinationAddress'] as String?,
      encodedPolyline: json['encodedPolyline'] as String?,
      routeJson: json['routeJson'],
    );
  }

  /// Round-trip com as mesmas chaves camelCase consumidas pelo [IncomingOrderSheet].
  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'travelId': travelId,
        'customerId': customerId,
        'driverId': driverId,
        'status': status,
        'distanceToPassengerInMeters': distanceToPassengerInMeters,
        'distanceToDestinationInMeters': distanceToDestinationInMeters,
        'averageTravelTimeInHours': averageTravelTimeInHours,
        'averageTravelTimeInMinutes': averageTravelTimeInMinutes,
        'passengerLatitude': passengerLatitude,
        'passengerLongitude': passengerLongitude,
        'destinationLatitude': destinationLatitude,
        'destinationLongitude': destinationLongitude,
        'routes': routes,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'cancelledAt': cancelledAt?.toIso8601String(),
        'cancellationReason': cancellationReason,
        'departureAddress': departureAddress,
        'destinationAddress': destinationAddress,
        'encodedPolyline': encodedPolyline,
        'routeJson': routeJson,
      };
}
