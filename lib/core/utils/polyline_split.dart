import 'geo.dart';

class PolySplit {
  final List<LatLng> visited, remaining;
  PolySplit(this.visited, this.remaining);
}

PolySplit splitByPosition(List<LatLng> line, LatLng pos) {
  if (line.length < 2) return PolySplit(const [], line);
  var bestI = 0;
  var bestD = double.infinity;
  for (var i = 0; i < line.length; i++) {
    final d = haversine(pos, line[i]);
    if (d < bestD) {
      bestD = d;
      bestI = i;
    }
  }
  final v = line.sublist(0, bestI + 1);
  final r = line.sublist(bestI);
  return PolySplit(v, r);
}

double polylineLength(List<LatLng> pts) {
  double sum = 0;
  for (var i = 0; i < pts.length - 1; i++) {
    sum += haversine(pts[i], pts[i + 1]);
  }
  return sum;
}
