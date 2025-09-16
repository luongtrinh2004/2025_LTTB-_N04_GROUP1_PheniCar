// lib/data/models/station.dart
class Station {
  final String id;
  final String name;
  final double lat;
  final double lng;

  /// Giữ nguyên raw map id từ payload để lọc (FE cũng làm client-side)
  final dynamic mapIdRaw;

  Station({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.mapIdRaw,
  });

  factory Station.fromJson(Map<String, dynamic> j) {
    // id: _id | id | stationId ...
    String _pickId(dynamic v) {
      if (v == null) return '';
      if (v is Map) return (v[r'$oid'] ?? v['_id'] ?? v['id'] ?? '').toString();
      return v.toString();
    }

    final id = _pickId(j['_id'] ?? j['id'] ?? j['stationId']);

    final name =
        (j['name'] ?? j['title'] ?? j['stationName'] ?? j['code'] ?? 'Station')
            .toString();

    // lat/lng: hỗ trợ nhiều dạng khác nhau
    double _toD(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    double lat = 0, lng = 0;
    if (j.containsKey('lat') && j.containsKey('lng')) {
      lat = _toD(j['lat']);
      lng = _toD(j['lng']);
    } else if (j.containsKey('latitude') && j.containsKey('longitude')) {
      lat = _toD(j['latitude']);
      lng = _toD(j['longitude']);
    } else if (j['location'] is Map &&
        (j['location']['coordinates'] is List) &&
        (j['location']['coordinates'] as List).length >= 2) {
      final c = (j['location']['coordinates'] as List);
      // GeoJSON: [lng, lat]
      lng = _toD(c[0]);
      lat = _toD(c[1]);
    } else if (j['point'] is Map &&
        (j['point']['coordinates'] is List) &&
        (j['point']['coordinates'] as List).length >= 2) {
      final c = (j['point']['coordinates'] as List);
      lng = _toD(c[0]);
      lat = _toD(c[1]);
    }

    final mapIdRaw =
        j['map'] ?? j['mapId'] ?? j['map_id'] ?? j['mapRef'] ?? j['mapID'];

    return Station(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      mapIdRaw: mapIdRaw,
    );
  }
}
