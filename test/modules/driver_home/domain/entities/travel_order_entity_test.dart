import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/modules/driver_home/domain/entities/travel_order_entity.dart';

void main() {
  group('TravelOrderEntity.fromJson', () {
    test('parseia payload completo do TravelOrderDetailResponse', () {
      final json = <String, dynamic>{
        'orderId': 'order-1',
        'travelId': 'travel-1',
        'customerId': 'customer-1',
        'driverId': 'driver-1',
        'status': 'pending',
        'distanceToPassengerInMeters': 1500,
        'distanceToDestinationInMeters': 5000,
        'averageTravelTimeInHours': 1,
        'averageTravelTimeInMinutes': 30,
        'passengerLatitude': -23.55,
        'passengerLongitude': -46.63,
        'destinationLatitude': -23.60,
        'destinationLongitude': -46.65,
        'routes': [
          {'routeId': 'r1'},
        ],
        'createdAt': '2026-08-17T10:00:00Z',
        'startedAt': null,
        'finishedAt': null,
        'cancelledAt': null,
        'cancellationReason': null,
        'departureAddress': 'Av. Paulista, 1000',
        'destinationAddress': 'Av. Faria Lima, 2000',
        'encodedPolyline': 'abc123',
        'routeJson': null,
      };

      final entity = TravelOrderEntity.fromJson(json);

      expect(entity.orderId, 'order-1');
      expect(entity.travelId, 'travel-1');
      expect(entity.customerId, 'customer-1');
      expect(entity.driverId, 'driver-1');
      expect(entity.status, 'pending');
      expect(entity.distanceToPassengerInMeters, 1500);
      expect(entity.distanceToDestinationInMeters, 5000);
      expect(entity.averageTravelTimeInHours, 1);
      expect(entity.averageTravelTimeInMinutes, 30);
      expect(entity.passengerLatitude, -23.55);
      expect(entity.passengerLongitude, -46.63);
      expect(entity.destinationLatitude, -23.60);
      expect(entity.destinationLongitude, -46.65);
      expect(entity.routes, hasLength(1));
      expect(entity.createdAt, DateTime.parse('2026-08-17T10:00:00Z'));
      expect(entity.startedAt, isNull);
      expect(entity.departureAddress, 'Av. Paulista, 1000');
      expect(entity.destinationAddress, 'Av. Faria Lima, 2000');
      expect(entity.encodedPolyline, 'abc123');
      expect(entity.routeJson, isNull);
    });

    test('null-safe: campos opcionais ausentes não lançam', () {
      final entity = TravelOrderEntity.fromJson({
        'orderId': 'order-1',
        'status': 'pending',
      });

      expect(entity.orderId, 'order-1');
      expect(entity.status, 'pending');
      expect(entity.passengerLatitude, 0.0);
      expect(entity.passengerLongitude, 0.0);
      expect(entity.destinationLatitude, 0.0);
      expect(entity.destinationLongitude, 0.0);
      expect(entity.distanceToPassengerInMeters, 0);
      expect(entity.distanceToDestinationInMeters, 0);
      expect(entity.averageTravelTimeInHours, 0);
      expect(entity.averageTravelTimeInMinutes, 0);
      expect(entity.travelId, '');
      expect(entity.customerId, '');
      expect(entity.driverId, isNull);
      expect(entity.departureAddress, isNull);
      expect(entity.destinationAddress, isNull);
      expect(entity.encodedPolyline, isNull);
      expect(entity.routes, isEmpty);
    });

    test('null-safe: lat/lng inválidos (não-num) caem para 0.0', () {
      final entity = TravelOrderEntity.fromJson({
        'orderId': 'order-1',
        'status': 'pending',
        'passengerLatitude': 'invalido',
      });

      expect(entity.passengerLatitude, 0.0);
    });

    test('createdAt inválido não lança (usa agora)', () {
      final entity = TravelOrderEntity.fromJson({
        'orderId': 'order-1',
        'status': 'pending',
        'createdAt': 'data-invalida',
      });

      expect(entity.createdAt, isA<DateTime>());
    });
  });

  group('TravelOrderEntity.toJson', () {
    test('round-trip toJson → fromJson preserva os valores', () {
      final original = TravelOrderEntity.fromJson(<String, dynamic>{
        'orderId': 'order-1',
        'travelId': 'travel-1',
        'customerId': 'customer-1',
        'driverId': 'driver-1',
        'status': 'pending',
        'distanceToPassengerInMeters': 1500,
        'distanceToDestinationInMeters': 5000,
        'averageTravelTimeInHours': 1,
        'averageTravelTimeInMinutes': 30,
        'passengerLatitude': -23.55,
        'passengerLongitude': -46.63,
        'destinationLatitude': -23.60,
        'destinationLongitude': -46.65,
        'routes': [
          {'routeId': 'r1'},
        ],
        'createdAt': '2026-08-17T10:00:00Z',
        'departureAddress': 'Av. Paulista, 1000',
        'destinationAddress': 'Av. Faria Lima, 2000',
        'encodedPolyline': 'abc123',
      });

      final restored = TravelOrderEntity.fromJson(original.toJson());

      expect(restored.orderId, original.orderId);
      expect(restored.travelId, original.travelId);
      expect(restored.customerId, original.customerId);
      expect(restored.driverId, original.driverId);
      expect(restored.status, original.status);
      expect(restored.distanceToPassengerInMeters, original.distanceToPassengerInMeters);
      expect(restored.distanceToDestinationInMeters, original.distanceToDestinationInMeters);
      expect(restored.averageTravelTimeInHours, original.averageTravelTimeInHours);
      expect(restored.averageTravelTimeInMinutes, original.averageTravelTimeInMinutes);
      expect(restored.passengerLatitude, original.passengerLatitude);
      expect(restored.passengerLongitude, original.passengerLongitude);
      expect(restored.destinationLatitude, original.destinationLatitude);
      expect(restored.destinationLongitude, original.destinationLongitude);
      expect(restored.routes, hasLength(1));
      expect(restored.createdAt, original.createdAt);
      expect(restored.departureAddress, original.departureAddress);
      expect(restored.destinationAddress, original.destinationAddress);
      expect(restored.encodedPolyline, original.encodedPolyline);
    });
  });
}
