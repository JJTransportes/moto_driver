class AuthLocalData {
  final String userId;
  final String accessToken;
  final List<String> roles;

  AuthLocalData({
    required this.userId,
    required this.accessToken,
    required this.roles,
  });

  factory AuthLocalData.fromMap(Map<String, dynamic> map) => AuthLocalData(
        userId: map['user_id'] as String,
        accessToken: map['access_token'] as String,
        roles: (map['roles'] as String)
            .split(',')
            .where((r) => r.isNotEmpty)
            .toList(),
      );
}

class ProfileLocalData {
  final String userId;
  final String fullName;
  final String email;

  ProfileLocalData({
    required this.userId,
    required this.fullName,
    required this.email,
  });

  factory ProfileLocalData.fromMap(Map<String, dynamic> map) => ProfileLocalData(
        userId: map['user_id'] as String,
        fullName: map['full_name'] as String,
        email: map['email'] as String,
      );
}

class TravelLocalData {
  final String travelId;
  final String status;
  final String? driverName;
  final String? passengerName;
  final String? departureAddress;
  final String? destinationAddress;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  TravelLocalData({
    required this.travelId,
    required this.status,
    this.driverName,
    this.passengerName,
    this.departureAddress,
    this.destinationAddress,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });

  factory TravelLocalData.fromMap(Map<String, dynamic> map) => TravelLocalData(
        travelId: map['travel_id'] as String,
        status: map['status'] as String,
        driverName: map['driver_name'] as String?,
        passengerName: map['passenger_name'] as String?,
        departureAddress: map['departure_address'] as String?,
        destinationAddress: map['destination_address'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        startedAt: map['started_at'] != null
            ? DateTime.parse(map['started_at'] as String)
            : null,
        finishedAt: map['finished_at'] != null
            ? DateTime.parse(map['finished_at'] as String)
            : null,
      );
}
