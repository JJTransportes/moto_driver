import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_driver/design_system/design_system.dart';

void main() {
  test('cria halo e núcleo sobre exatamente os mesmos pontos', () {
    const points = <LatLng>[LatLng(-23.3, -45.9), LatLng(-23.31, -45.91)];

    final routes = MotoMapRouteStyle.polylines(id: 'route', points: points);
    final byId = {for (final route in routes) route.polylineId.value: route};

    expect(byId.keys, containsAll(<String>['route-halo', 'route-core']));
    expect(byId['route-halo']!.points, same(points));
    expect(byId['route-core']!.points, same(points));
    expect(byId['route-halo']!.width, greaterThan(byId['route-core']!.width));
    expect(byId['route-halo']!.zIndex, lessThan(byId['route-core']!.zIndex));
  });

  test('não cria traço sem geometria', () {
    expect(MotoMapRouteStyle.polylines(id: 'route', points: const []), isEmpty);
  });
}
