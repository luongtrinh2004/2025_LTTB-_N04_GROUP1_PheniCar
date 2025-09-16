import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/env.dart';
import '../../core/utils/geo.dart';

class RoutingService {
  final String osrm; // .../route/v1/driving
  RoutingService({String? osrmBase})
      : osrm = (osrmBase ?? Env.osrmBase).replaceFirst(RegExp(r'/*$'), '');

  Uri _url(LatLng a, LatLng b) => Uri.parse(
      '$osrm/${a.lng},${a.lat};${b.lng},${b.lat}?overview=full&geometries=geojson');

  Future<List<LatLng>> route(LatLng a, LatLng b) async {
    final r = await http.get(_url(a, b)).timeout(Env.routeTimeout);
    if (r.statusCode != 200) throw Exception('OSRM ${r.statusCode}');
    final js = jsonDecode(r.body);
    final coords =
        (js['routes']?[0]?['geometry']?['coordinates'] as List?) ?? [];
    return coords
        .map((xy) =>
            LatLng((xy[1] as num).toDouble(), (xy[0] as num).toDouble()))
        .toList();
  }
}
