import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:mobile/data/models.dart';

class MapView extends StatelessWidget {
  final List<Station> stations;
  final List<Vehicle> vehicles;
  final ll.LatLng initialCenter;
  final double initialZoom;

  const MapView({
    super.key,
    required this.stations,
    required this.vehicles,
    this.initialCenter = const ll.LatLng(21.0278, 105.8342), // Hà Nội
    this.initialZoom = 12,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        interactionOptions:
            const InteractionOptions(flags: ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.pheni.car',
        ),
        MarkerLayer(
          markers: [
            // stations
            ...stations.map((s) => Marker(
                  point: ll.LatLng(s.lat ?? 0, s.lng ?? 0),
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.location_on, color: Colors.redAccent),
                )),
            // vehicles
            ...vehicles.map((v) => Marker(
                  point: ll.LatLng(v.lat ?? 0, v.lng ?? 0),
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.directions_car, color: Colors.blue),
                )),
          ],
        ),
      ],
    );
  }
}
