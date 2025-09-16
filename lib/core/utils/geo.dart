import 'dart:math' as math;

class LatLng {
  final double lat, lng;
  const LatLng(this.lat, this.lng);
}

class LatLngBounds {
  final LatLng sw, ne;
  const LatLngBounds(this.sw, this.ne);
}

double haversine(LatLng a, LatLng b) {
  const R = 6371000.0;
  final dLat = (b.lat - a.lat) * math.pi / 180.0;
  final dLng = (b.lng - a.lng) * math.pi / 180.0;
  final s1 = math.sin(dLat / 2), s2 = math.sin(dLng / 2);
  final aa = s1 * s1 +
      math.cos(a.lat * math.pi / 180.0) *
          math.cos(b.lat * math.pi / 180.0) *
          s2 *
          s2;
  return 2 * R * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
}
