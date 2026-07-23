import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  final Dio _dio;

  DirectionsService(this._dio);

  Future<DirectionsResult?> getDirections(
      double originLat, double originLng,
      double destLat, double destLng) async {
    final apiKey = const String.fromEnvironment('MAPS_API_KEY',
        defaultValue: '');
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          'key': apiKey,
          'mode': 'driving',
        },
      );

      if (response.data['status'] != 'OK') return null;
      final route = response.data['routes'][0];
      final leg = route['legs'][0];

      return DirectionsResult(
        distanceMeters: leg['distance']['value'] as int,
        timeMinutes: (leg['duration']['value'] as int) ~/ 60,
        encodedPolyline: route['overview_polyline']['points'] as String,
        startLat: (leg['start_location']['lat'] as num).toDouble(),
        startLng: (leg['start_location']['lng'] as num).toDouble(),
        endLat: (leg['end_location']['lat'] as num).toDouble(),
        endLng: (leg['end_location']['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

class DirectionsResult {
  final int distanceMeters;
  final int timeMinutes;
  final String encodedPolyline;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;

  const DirectionsResult({
    required this.distanceMeters,
    required this.timeMinutes,
    required this.encodedPolyline,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
  });

  /// Decodifica uma string encoded polyline do Google Maps sem precisar
  /// instanciar um DirectionsResult com valores artificiais.
  static List<LatLng> decode(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  List<LatLng> decodePolyline() => decode(encodedPolyline);
}
