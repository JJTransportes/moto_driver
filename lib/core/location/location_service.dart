import 'package:geolocator/geolocator.dart';

enum LocationStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationResult {
  final Position? position;
  final LocationStatus status;

  const LocationResult({this.position, required this.status});

  bool get isGranted => status == LocationStatus.granted && position != null;
}

class LocationService {
  static Future<void> requestPermissionIfNeeded() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<LocationResult> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(status: LocationStatus.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult(status: LocationStatus.denied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(status: LocationStatus.deniedForever);
    }

    final position = await Geolocator.getCurrentPosition();
    return LocationResult(position: position, status: LocationStatus.granted);
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
