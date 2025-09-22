// lib/features/booking/widgets.dart
import 'package:flutter/material.dart';
import '../../data/models.dart';

/// Hiển thị dropdown chọn Area (Map)
class AreaDropdown extends StatelessWidget {
  final List<Area> areas;
  final Area? selected;
  final ValueChanged<Area?> onChanged;

  const AreaDropdown({
    super.key,
    required this.areas,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<Area>(
      hint: const Text('Chọn khu vực'),
      value: selected,
      items: areas
          .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Hiển thị dropdown chọn Station (pickup hoặc drop)
class StationDropdown extends StatelessWidget {
  final String label;
  final List<Station> stations;
  final Station? selected;
  final ValueChanged<Station?> onChanged;

  const StationDropdown({
    super.key,
    required this.label,
    required this.stations,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<Station>(
      hint: Text(label),
      value: selected,
      items: stations
          .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Hiển thị trạng thái / log text
class StatusBar extends StatelessWidget {
  final String message;
  const StatusBar({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(color: Colors.blue),
    );
  }
}
