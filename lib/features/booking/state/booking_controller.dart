import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import '../../../core/utils/polyline_split.dart';
import '../../../data/models/area.dart';
import '../../../data/models/station.dart';
import '../../../data/models/telemetry.dart';
import '../../../data/sources/dapi_service.dart';
import '../../../data/sources/routing_service.dart';

class BookingController extends ChangeNotifier {
  BookingController({DapiService? dapi, RoutingService? router})
      : dapi = dapi ?? DapiService(),
        router = router ?? RoutingService();

  final DapiService dapi;
  final RoutingService router;

  // header
  List<MapArea> areas = [];
  MapArea? selected;

  // stations
  List<Station> stations = [];
  final List<String> pickedIds = [];
  List<Station> get pickedStations {
    final map = {for (final s in stations) s.id: s};
    return pickedIds.map((id) => map[id]).whereType<Station>().toList();
  }

  // map/route
  LatLng? vehiclePos;
  List<LatLng> serverPath = [];
  List<LatLng> osrmPath = [];
  List<LatLng> get activePath => serverPath.isNotEmpty ? serverPath : osrmPath;
  List<LatLng> visited = [];
  List<LatLng> remaining = [];

  // telemetry
  Telemetry? tel;

  // ui flags
  bool loadingAreas = false;
  bool loadingStations = false;
  bool routing = false;

  // ===== bootstrap =====
  Future<void> init() async {
    loadingAreas = true;
    notifyListeners();
    try {
      areas = await dapi.getAllMaps();
      if (areas.isNotEmpty) {
        await selectArea(areas.first);
      }
    } finally {
      loadingAreas = false;
      notifyListeners();
    }
  }

  Future<void> selectArea(MapArea a) async {
    selected = a;
    loadingStations = true;
    notifyListeners();
    try {
      stations = await dapi.getStationsByMapSafe(a.id);
      pickedIds.clear();
      serverPath = [];
      osrmPath = [];
      visited = [];
      remaining = [];
    } finally {
      loadingStations = false;
      notifyListeners();
    }
  }

  void addStation(String id) {
    if (!pickedIds.contains(id)) {
      pickedIds.add(id);
      notifyListeners();
    }
  }

  void removeStation(String id) {
    pickedIds.remove(id);
    notifyListeners();
  }

  bool get canBook => pickedIds.length >= 2;

  Future<void> createRide() async {
    if (!canBook) return;
    await dapi.createRide(stationIds: pickedIds);
  }

  // ===== Telemetry listener (gọi từ MQTT) =====
  void onTelemetry(Telemetry t) {
    tel = t;
    vehiclePos = LatLng(t.lat, t.lng);
    if (t.serverPath != null && t.serverPath!.length >= 2) {
      serverPath = t.serverPath!;
    }
    _split();
    notifyListeners();
  }

  // ===== FE OSRM khi chưa có server path =====
  Future<void> ensureOsrm() async {
    if (vehiclePos == null || pickedStations.isEmpty) return;
    routing = true;
    notifyListeners();
    try {
      final pts = <LatLng>[
        vehiclePos!,
        ...pickedStations.map((s) => LatLng(s.lat, s.lng)),
      ];
      final acc = <LatLng>[];
      for (var i = 0; i < pts.length - 1; i++) {
        final seg = await router.route(pts[i], pts[i + 1]);
        if (acc.isNotEmpty && seg.isNotEmpty) seg.removeAt(0);
        acc.addAll(seg);
      }
      osrmPath = acc;
      _split();
    } finally {
      routing = false;
      notifyListeners();
    }
  }

  void _split() {
    if (vehiclePos == null || activePath.length < 2) {
      visited = [];
      remaining = activePath;
      return;
    }
    final sp = splitByPosition(activePath, vehiclePos!);
    visited = sp.visited;
    remaining = sp.remaining;
  }

  // ===== footer info =====
  String get statusText {
    final s = tel?.statusNum ?? 0;
    switch (s) {
      case 1:
        return 'Đang tính đường';
      case 2:
        return 'Chờ xác nhận';
      case 3:
        return 'Đang di chuyển';
      case 4:
        return 'Đang sạc';
      case 5:
        return 'Khẩn cấp';
      default:
        return 'Sẵn sàng';
    }
  }

  double? get distanceToNext {
    if (vehiclePos == null) return null;
    if (remaining.length >= 2) {
      return polylineLength(remaining.take(50).toList());
    }
    final idx = tel?.points.indexWhere((p) => p.orderStatus != 4) ?? -1;
    if (idx >= 0 && idx < (tel?.points.length ?? 0)) {
      final p = tel!.points[idx];
      return haversine(vehiclePos!, LatLng(p.lat, p.lng));
    }
    return null;
  }

  // ===== bounds cho map =====
  LatLngBounds? get viewBounds {
    if (selected?.bounds != null) return selected!.bounds;
    if (stations.isEmpty) return null;
    return _boundsFromStations(stations);
  }

  LatLngBounds _boundsFromStations(List<Station> list) {
    var minLat = list.first.lat, maxLat = list.first.lat;
    var minLng = list.first.lng, maxLng = list.first.lng;
    for (final s in list) {
      if (s.lat < minLat) minLat = s.lat;
      if (s.lat > maxLat) maxLat = s.lat;
      if (s.lng < minLng) minLng = s.lng;
      if (s.lng > maxLng) maxLng = s.lng;
    }
    const pad = 0.0008;
    return LatLngBounds(
      LatLng(minLat - pad, minLng - pad),
      LatLng(maxLat + pad, maxLng + pad),
    );
  }

  // optional heading
  double _bearing(LatLng a, LatLng b) {
    final p1 = a.lat * math.pi / 180, p2 = b.lat * math.pi / 180;
    final l1 = a.lng * math.pi / 180, l2 = b.lng * math.pi / 180;
    final y = math.sin(l2 - l1) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(l2 - l1);
    final deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }
}
