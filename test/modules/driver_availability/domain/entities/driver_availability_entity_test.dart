import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/modules/driver_availability/domain/entities/driver_availability_entity.dart';

void main() {
  group('DriverAvailabilityEntity.fromJson', () {
    test('parses active with full dates', () {
      final now = DateTime.now();
      final activated = now.subtract(const Duration(minutes: 30));
      final expires = now.add(const Duration(hours: 3));

      final entity = DriverAvailabilityEntity.fromJson({
        'status': 'active',
        'activatedAt': activated.toIso8601String(),
        'expiresAt': expires.toIso8601String(),
      });

      expect(entity.status, 'active');
      expect(entity.isActive, isTrue);
      expect(entity.activatedAt, activated);
      expect(entity.expiresAt, expires);
      expect(entity.isExpired, isFalse);
    });

    test('parses inactive with null dates', () {
      final entity = DriverAvailabilityEntity.fromJson({
        'status': 'inactive',
        'activatedAt': null,
        'expiresAt': null,
      });

      expect(entity.status, 'inactive');
      expect(entity.isActive, isFalse);
      expect(entity.activatedAt, isNull);
      expect(entity.expiresAt, isNull);
      expect(entity.isExpired, isFalse);
    });

    test('falls back to inactive when status is missing', () {
      final entity = DriverAvailabilityEntity.fromJson({
        'activatedAt': null,
        'expiresAt': null,
      });

      expect(entity.status, 'inactive');
      expect(entity.isActive, isFalse);
    });

    test('isExpired reflects past expiresAt', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final future = DateTime.now().add(const Duration(hours: 2));

      final expired = DriverAvailabilityEntity.fromJson({
        'status': 'active',
        'activatedAt': past.toIso8601String(),
        'expiresAt': past.toIso8601String(),
      });
      final valid = DriverAvailabilityEntity.fromJson({
        'status': 'active',
        'activatedAt': past.toIso8601String(),
        'expiresAt': future.toIso8601String(),
      });

      expect(expired.isExpired, isTrue);
      expect(valid.isExpired, isFalse);
    });
  });
}
