import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../moto_tokens.dart';

/// Visual Cobalto para uma geometria já calculada.
///
/// Este helper não busca, decodifica ou modifica a rota. As duas camadas usam
/// exatamente os mesmos pontos para preservar o comportamento do mapa.
abstract final class MotoMapRouteStyle {
  static Set<Polyline> polylines({
    required String id,
    required List<LatLng> points,
  }) {
    if (points.isEmpty) return const <Polyline>{};

    return <Polyline>{
      Polyline(
        polylineId: PolylineId('$id-halo'),
        points: points,
        color: MotoRaw.cobalto300.withValues(alpha: .48),
        width: 12,
        zIndex: 1,
        geodesic: true,
      ),
      Polyline(
        polylineId: PolylineId('$id-core'),
        points: points,
        color: MotoRaw.cobalto600,
        width: 5,
        zIndex: 2,
        geodesic: true,
      ),
    };
  }
}
