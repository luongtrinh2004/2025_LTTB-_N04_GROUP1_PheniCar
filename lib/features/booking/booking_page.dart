import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:mobile/data/api.dart';
import 'package:mobile/data/models.dart';

class BookingPage extends StatefulWidget {
  final Api api;
  const BookingPage({super.key, required this.api});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  // ===== Data chọn khu vực/bến =====
  List<Area> _areas = [];
  Area? _pickedArea;

  List<Station> _allStations = []; // mọi bến của khu đã chọn
  final Set<String> _pickedStationIds = {};

  // ===== Xe =====
  final Map<String, Vehicle> _vehicles = {}; // id -> Vehicle
  StreamSubscription<Telemetry>? _teleSub;

  // ===== Map / UI =====
  final MapController _mapCtrl = MapController();
  double _mapZoom = 12.0;
  ll.LatLng? _areaCenter; // tâm để tính xe gần nhất

  // ===== Footer status =====
  String _rideStatus = 'Chưa đặt';
  String _plate = '--';
  double _speed = 0;
  int get _remainStops => _pickedStationIds.length;

  @override
  void initState() {
    super.initState();
    _loadAreas();

    // ✅ Kết nối MQTT qua service: api.mqtt
    Future.microtask(() async {
      await widget.api.mqtt.connect(onStatus: (s) => debugPrint('MQTT: $s'));

      _teleSub = widget.api.mqtt.telemetryStream.listen((t) {
        // chỉ cập nhật nếu xe này đang theo dõi
        if (_vehicles.containsKey(t.carId ?? '')) {
          final old = _vehicles[t.carId]!;
          setState(() {
            _vehicles[t.carId!] = Vehicle(
              id: old.id,
              mapId: old.mapId,
              lat: t.lat ?? old.lat,
              lng: t.lng ?? old.lng,
              online: old.online,
              status: t.status ?? old.status,
              speed: t.speed ?? old.speed,
              charge: old.charge,
              updatedAt: t.ts ?? old.updatedAt,
            );
          });
          _updateFooterFromNearest();
        }
      }, onError: (e) => debugPrint('telemetry error: $e'));
    });
  }

  @override
  void dispose() {
    _teleSub?.cancel();
    super.dispose();
  }

  // ---------- Helpers ----------
  String _norm(String s) {
    final m = RegExp(r'[0-9a-fA-F]{24}').firstMatch(s);
    return m?.group(0) ?? s;
  }

  Vehicle? _nearestVehicleTo(ll.LatLng p) {
    if (_vehicles.isEmpty) return null;
    double best = 1e18;
    Vehicle? out;
    for (final v in _vehicles.values) {
      final dlat = (v.lat ?? 0) - p.latitude;
      final dlng = (v.lng ?? 0) - p.longitude;
      final d = dlat * dlat + dlng * dlng;
      if (d < best) {
        best = d;
        out = v;
      }
    }
    return out;
  }

  void _updateFooterFromNearest() {
    if (_areaCenter == null) return;
    final near = _nearestVehicleTo(_areaCenter!);
    if (near == null) return;
    setState(() {
      _plate = near.id ?? '--';
      _speed = near.speed ?? 0;
    });
  }

  // ---------- Load data ----------
  Future<void> _loadAreas() async {
    try {
      final areas = await widget.api.getMaps();
      if (!mounted) return;
      setState(() => _areas = areas);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi tải khu vực: $e')));
    }
  }

  Future<void> _loadStations(String mapId) async {
    try {
      final stations = await widget.api.getStationsByMap(mapId);
      if (!mounted) return;
      setState(() => _allStations = stations);
      _zoomToStations(stations);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi tải bến: $e')));
    }
  }

  Future<void> _loadVehiclesForArea(String areaId) async {
    try {
      final all = await widget.api.getVehicles(); // snapshot từ Worker
      final areaNorm = _norm(areaId);
      final filtered = all.where(
        (v) => v.mapId != null && _norm(v.mapId!) == areaNorm,
      );
      if (!mounted) return;
      setState(() {
        _vehicles
          ..clear()
          ..addEntries(filtered.map((v) => MapEntry(v.id ?? '', v)));
      });
      _updateFooterFromNearest();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi tải xe: $e')));
    }
  }

  // ---------- Actions ----------
  Future<void> _pickArea() async {
    if (_areas.isEmpty) return;
    final a = await showModalBottomSheet<Area>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _areas.length,
          itemBuilder: (_, i) {
            final it = _areas[i];
            final picked = _pickedArea?.id == it.id;
            return ListTile(
              title: Text(it.name ?? '(no name)'),
              trailing:
                  picked ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () => Navigator.pop(ctx, it),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
        ),
      ),
    );

    if (a == null) return;

    setState(() {
      _pickedArea = a;
      _pickedStationIds.clear();
      _allStations = [];
      _vehicles.clear();
      _areaCenter = null;
    });

    if (a.id != null && a.id!.isNotEmpty) {
      await _loadStations(a.id!);
      await _loadVehiclesForArea(a.id!);
    }
  }

  void _zoomToStations(List<Station> st) {
    if (st.isEmpty) return;
    final lat = st.map((e) => e.lat ?? 0).reduce((a, b) => a + b) / st.length;
    final lng = st.map((e) => e.lng ?? 0).reduce((a, b) => a + b) / st.length;
    _areaCenter = ll.LatLng(lat, lng);
    _mapCtrl.move(_areaCenter!, 13);
    setState(() => _mapZoom = 13);
    _updateFooterFromNearest();
  }

  Future<void> _pickStations() async {
    if (_pickedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hãy chọn khu vực trước')));
      return;
    }
    if (_allStations.isEmpty) {
      await _loadStations(_pickedArea!.id ?? '');
      if (!mounted) return;
    }

    final selected = Set<String>.from(_pickedStationIds);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheet) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('Chọn bến (${selected.length})',
                          style: Theme.of(ctx).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          selected.clear();
                          setSheet(() {});
                        },
                        child: const Text('Bỏ chọn'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _allStations.length,
                    itemBuilder: (_, i) {
                      final s = _allStations[i];
                      final id = s.id ?? '';
                      final checked = selected.contains(id);
                      return CheckboxListTile(
                        title: Text(s.name ?? '(no name)'),
                        subtitle: Text(
                          '(${(s.lat ?? 0).toStringAsFixed(6)}, ${(s.lng ?? 0).toStringAsFixed(6)})',
                        ),
                        value: checked,
                        onChanged: (v) {
                          if (v == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                          setSheet(() {});
                        },
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: const Text('Xong'),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;
    setState(() => _pickedStationIds
      ..clear()
      ..addAll(result));
  }

  Future<void> _book() async {
    if (_pickedStationIds.isEmpty) return;
    try {
      await widget.api.createRide(_pickedStationIds.toList());
      if (!mounted) return;
      setState(() => _rideStatus = 'Đã tạo cuốc');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tạo cuốc thành công')));
      _updateFooterFromNearest();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tạo cuốc lỗi: $e')));
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final pickedAreaName = _pickedArea?.name ?? 'Chọn khu vực';
    final pickedStops = _pickedStationIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PheniCar'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Header: 2 nút chọn
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _areas.isEmpty ? null : _pickArea,
                    icon: const Icon(Icons.map_outlined),
                    label:
                        Text(pickedAreaName, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_pickedArea == null) ? null : _pickStations,
                    icon: const Icon(Icons.place_outlined),
                    label: Text('Chọn bến ($pickedStops)'),
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: const ll.LatLng(21.0278, 105.8342), // Hà Nội
                  initialZoom: _mapZoom,
                  minZoom: 3,
                  maxZoom: 18,
                  interactionOptions:
                      const InteractionOptions(flags: ~InteractiveFlag.rotate),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.pheni.car',
                  ),
                  // Bến
                  MarkerLayer(
                    markers: _allStations
                        .map((s) => Marker(
                              point: ll.LatLng(s.lat ?? 0, s.lng ?? 0),
                              width: 36,
                              height: 36,
                              child: Tooltip(
                                message: s.name ?? '',
                                child: Icon(
                                  Icons.location_on,
                                  color: _pickedStationIds.contains(s.id)
                                      ? Colors.green
                                      : Colors.redAccent,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  // Xe (snapshot + realtime)
                  MarkerLayer(
                    markers: _vehicles.values.map((v) {
                      final point = ll.LatLng(v.lat ?? 0, v.lng ?? 0);
                      final color =
                          (v.online ?? false) ? Colors.blue : Colors.grey;
                      final info =
                          '${v.id ?? ''} • ${(v.speed ?? 0).toStringAsFixed(0)} km/h'
                          '${v.charge != null ? ' • ${v.charge!.toStringAsFixed(0)}%' : ''}';
                      return Marker(
                        point: point,
                        width: 46,
                        height: 46,
                        child: Tooltip(
                          message: info,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.circle,
                                  size: 24, color: Colors.white),
                              Icon(Icons.directions_car,
                                  size: 22, color: color),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Footer: trạng thái cuốc + thông tin
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.black12,
                    offset: Offset(0, -2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Trạng thái: $_rideStatus',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _chip('Bến còn lại', '$_remainStops'),
                            _chip('BKS', _plate),
                            _chip(
                                'Tốc độ', '${_speed.toStringAsFixed(1)} km/h'),
                            _chip('Xe trong khu', '${_vehicles.length}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _pickedStationIds.isEmpty ? null : _book,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Book'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(value, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
