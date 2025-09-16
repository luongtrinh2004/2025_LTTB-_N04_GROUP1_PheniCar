import '../../core/utils/geo.dart';

class Telemetry {
  final String carId;
  final int statusNum;
  final double lat, lng, speed, charge;
  final List<OrderPoint> points;
  final List<LatLng>? serverPath;

  Telemetry({
    required this.carId,
    required this.statusNum,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.charge,
    required this.points,
    this.serverPath,
  });

  factory Telemetry.fromJson(Map<String, dynamic> j) {
    final path = (j['path'] as List?)
        ?.map((p) =>
            LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();

    final orders = (j['orders'] as List? ?? [])
        .map((o) => OrderPoint.fromJson(o as Map<String, dynamic>))
        .toList();

    return Telemetry(
      carId: j['carID']?.toString() ?? j['carId']?.toString() ?? '',
      statusNum: (j['statusNum'] ?? 0) as int,
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      speed: (j['speed'] as num?)?.toDouble() ?? 0,
      charge: (j['charge'] as num?)?.toDouble() ?? 0,
      points: orders,
      serverPath: path,
    );
  }
}

class OrderPoint {
  final double lat, lng;
  final int orderStatus; // 0..4
  final String? title;
  OrderPoint(
      {required this.lat,
      required this.lng,
      required this.orderStatus,
      this.title});

  factory OrderPoint.fromJson(Map<String, dynamic> j) {
    final raw = j['orderStatus'];
    final st = raw is String
        ? const {
              'routing': 0,
              'routed': 1,
              'going': 2,
              'stopping': 3,
              'done': 4
            }[raw] ??
            0
        : (raw ?? 0) as int;
    return OrderPoint(
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      orderStatus: st,
      title: j['title'] as String?,
    );
  }
}
