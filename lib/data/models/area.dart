import '../../core/utils/geo.dart';

class MapArea {
  final String id;
  final String name;
  final LatLngBounds? bounds;
  MapArea({required this.id, required this.name, this.bounds});

  factory MapArea.fromJson(Map<String, dynamic> j) {
    return MapArea(
      id: (j['_id'] ?? j['id']).toString(),
      name: j['name'] ?? 'Khu vực',
      bounds: null, // có thể parse từ bbox nếu BE trả
    );
  }
}
