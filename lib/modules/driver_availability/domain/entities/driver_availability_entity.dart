class DriverAvailabilityEntity {
  final String status;
  final DateTime? activatedAt;
  final DateTime? expiresAt;

  const DriverAvailabilityEntity({
    required this.status,
    this.activatedAt,
    this.expiresAt,
  });

  bool get isActive => status == 'active';
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory DriverAvailabilityEntity.fromJson(Map<String, dynamic> json) =>
      DriverAvailabilityEntity(
        status: json['status'] as String? ?? 'inactive',
        activatedAt: json['activatedAt'] != null
            ? DateTime.parse(json['activatedAt'] as String)
            : null,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
      );
}
