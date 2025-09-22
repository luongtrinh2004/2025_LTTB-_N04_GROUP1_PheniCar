// lib/features/booking/map_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:mobile/data/api.dart';
import 'package:mobile/data/models.dart';

class MapView extends StatefulWidget {
  final Api api;
  const MapView({super.key, required this.api});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapCtrl = MapController();
  final Map<String, ll.LatLng> _cars = {}; // carId -> position
  StreamSubscription<Telemetry>? _sub;

  @override
  void initState() {
    super.initState();

    // Lắng nghe telemetry từ MQTT
    _sub = widget.api.telemetryStream.listen((t) {
      final pos = ll.LatLng(t.lat, t.lng);
      setState(() {
        _cars[t.carId] = pos;
      });

      // Auto follow theo xe gần nhất (đơn giản: xe cuối cùng nhận frame)
      if (_cars.isNotEmpty) {
        _mapCtrl.move(pos, _mapCtrl.camera.zoom);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapCtrl,
      options: const MapOptions(
        initialCenter: ll.LatLng(21.0278, 105.8342), // Hà Nội
        initialZoom: 13,
      ),
      children: [
        // OSM tiles
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'mobile',
        ),

        // Markers cho các xe
        MarkerLayer(
          markers: _cars.entries.map((e) {
            return Marker(
              width: 44,
              height: 44,
              point: e.value,
              child: Tooltip(
                message: 'Xe ${e.key}',
                preferBelow: false,
                child: const Icon(
                  Icons.directions_car,
                  size: 30,
                  color: Colors.blue,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
