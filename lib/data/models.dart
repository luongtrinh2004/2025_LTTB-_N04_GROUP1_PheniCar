// lib/data/models.dart

class Area {
  final String id;
  final String name;

  Area({required this.id, required this.name});

  factory Area.fromJson(Map<String, dynamic> js) {
    final id = (js['_id'] ?? js['id'] ?? js['mapId'] ?? '').toString();
    final name = (js['name'] ?? js['title'] ?? js['label'] ?? '').toString();
    return Area(id: id, name: name);
  }
}

class Station {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? mapIdRaw;

  Station({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.mapIdRaw,
  });

  static String? _normalizeId(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(v)) return v;
      final m = RegExp(r'[0-9a-fA-F]{24}').firstMatch(v);
      return m?.group(0) ?? v;
    }
    if (v is Map) {
      return _normalizeId(v['_id'] ?? v['id'] ?? v[r'$oid'] ?? v['\$oid']);
    }
    return v.toString();
  }

  factory Station.fromJson(Map<String, dynamic> js) {
    final id = (js['_id'] ?? js['id'] ?? js['stationId'] ?? '').toString();
    final name = (js['name'] ?? js['title'] ?? '').toString();

    double? lat = (js['lat'] ?? js['latitude']) is num
        ? (js['lat'] ?? js['latitude']).toDouble()
        : null;
    double? lng = (js['lng'] ?? js['longitude']) is num
        ? (js['lng'] ?? js['longitude']).toDouble()
        : null;

    final coords = (js['location']?['coordinates'] ??
        js['point']?['coordinates'] ??
        js['geometry']?['coordinates']);
    if ((lat == null || lng == null) && coords is List && coords.length >= 2) {
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }

    final normMapId = _normalizeId(js['mapId'] ?? js['map'] ?? js['areaId']);

    return Station(
      id: id,
      name: name,
      lat: lat ?? 0,
      lng: lng ?? 0,
      mapIdRaw: normMapId,
    );
  }
}

class Vehicle {
  final String id;
  final String? mapId; // id khu vực xe đang thuộc
  final double lat;
  final double lng;
  final bool online;
  final int? status;
  final double? speed;
  final double? charge; // % pin
  final int? updatedAt;

  Vehicle({
    required this.id,
    required this.lat,
    required this.lng,
    required this.online,
    this.mapId,
    this.status,
    this.speed,
    this.charge,
    this.updatedAt,
  });

  static String? _normalizeId(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final m = RegExp(r'[0-9a-fA-F]{24}').firstMatch(v);
      return m?.group(0) ?? v;
    }
    if (v is Map) {
      return _normalizeId(v['_id'] ?? v['id'] ?? v[r'$oid'] ?? v['\$oid']);
    }
    return v.toString();
  }

  factory Vehicle.fromJson(Map<String, dynamic> js) {
    return Vehicle(
      id: (js['id'] ?? js['_id'] ?? '').toString(),
      mapId: _normalizeId(js['mapId'] ?? js['areaId'] ?? js['map']),
      lat: (js['lat'] as num?)?.toDouble() ?? 0,
      lng: (js['lng'] as num?)?.toDouble() ?? 0,
      online: js['online'] == true,
      status: (js['status'] is num) ? (js['status'] as num).toInt() : null,
      speed: (js['speed'] as num?)?.toDouble(),
      charge: (js['charge'] as num?)?.toDouble(),
      updatedAt: (js['updatedAt'] as num?)?.toInt(),
    );
  }
}

class Telemetry {
  final String carId;
  final double lat;
  final double lng;
  final int status;
  final double speed;
  final int ts;

  Telemetry({
    required this.carId,
    required this.lat,
    required this.lng,
    required this.status,
    required this.speed,
    required this.ts,
  });

  factory Telemetry.fromJson(Map<String, dynamic> js) {
    return Telemetry(
      carId: (js['carID'] ?? js['carId'] ?? js['id'] ?? '').toString(),
      lat: (js['lat'] as num?)?.toDouble() ?? 0,
      lng: (js['lng'] as num?)?.toDouble() ?? 0,
      status: (js['status'] as num?)?.toInt() ?? 0,
      speed: (js['speed'] as num?)?.toDouble() ?? 0,
      ts: (js['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
