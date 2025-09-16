import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as l2;

import '../../../data/models/area.dart';
import '../../../data/models/station.dart';
import '../../../core/utils/geo.dart'; // <- LatLng, LatLngBounds (của bạn)
import '../../../theme/colors.dart';

class MapView extends StatefulWidget {
  final MapArea? area;
  final LatLng? vehicle;
  final List<Station> stations;
  final List<LatLng> visited;
  final List<LatLng> remaining;
  final LatLngBounds? bounds; // bounds theo kiểu của bạn

  const MapView({
    super.key,
    required this.area,
    required this.vehicle,
    required this.stations,
    required this.visited,
    required this.remaining,
    required this.bounds,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final fm.MapController _map = fm.MapController();
  LatLngBounds? _lastBounds; // kiểu của bạn

  bool _boundsChanged(LatLngBounds a, LatLngBounds? b) {
    if (b == null) return true;
    return a.sw.lat != b.sw.lat ||
        a.sw.lng != b.sw.lng ||
        a.ne.lat != b.ne.lat ||
        a.ne.lng != b.ne.lng;
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final b = widget.bounds;
    if (b != null && _boundsChanged(b, _lastBounds)) {
      _lastBounds = b;
      final fit = fm.CameraFit.bounds(
        bounds: _BoundsX.toFlutterMap(b), // -> fm.LatLngBounds
        padding: const EdgeInsets.all(28),
      );
      _map.fitCamera(fit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.vehicle ??
        (widget.stations.isNotEmpty
            ? LatLng(widget.stations.first.lat, widget.stations.first.lng)
            : const LatLng(10.776889, 106.700806));

    final mapCenter = l2.LatLng(center.lat, center.lng);

    // Markers: xe + bến
    final List<fm.Marker> markers = [
      if (widget.vehicle != null)
        fm.Marker(
          point: mapCenter,
          width: 40,
          height: 40,
          child: const Icon(Icons.directions_car,
              color: Colors.blueAccent, size: 32),
        ),
      for (final s in widget.stations)
        fm.Marker(
          point: l2.LatLng(s.lat, s.lng),
          width: 36,
          height: 36,
          child:
              const Icon(Icons.location_on, color: Colors.deepOrange, size: 32),
        ),
    ];

    // Polylines: xám đã đi, xanh còn lại
    final List<fm.Polyline> polylines = [
      if (widget.visited.length >= 2)
        fm.Polyline(
          points: widget.visited
              .map((p) => l2.LatLng(p.lat, p.lng))
              .toList(growable: false),
          strokeWidth: 6,
          color: visitedGray,
        ),
      if (widget.remaining.length >= 2)
        fm.Polyline(
          points: widget.remaining
              .map((p) => l2.LatLng(p.lat, p.lng))
              .toList(growable: false),
          strokeWidth: 6,
          color: brandBlue,
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: fm.FlutterMap(
        mapController: _map,
        options: fm.MapOptions(
          initialCenter: mapCenter,
          initialZoom: 12,
        ),
        children: [
          fm.TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.roboride',
          ),
          if (polylines.isNotEmpty) fm.PolylineLayer(polylines: polylines),
          if (markers.isNotEmpty) fm.MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

/// Convert từ bounds của bạn -> bounds của flutter_map
extension _BoundsX on LatLngBounds {
  static fm.LatLngBounds toFlutterMap(LatLngBounds b) => fm.LatLngBounds(
        l2.LatLng(b.sw.lat, b.sw.lng),
        l2.LatLng(b.ne.lat, b.ne.lng),
      );
}
