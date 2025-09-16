import 'package:flutter/material.dart';
import '../../../data/models/area.dart';
import '../../../theme/colors.dart';

class AreaHeader extends StatelessWidget {
  final List<MapArea> areas;
  final MapArea? selected;
  final void Function(MapArea area) onSelected;

  const AreaHeader({
    super.key,
    required this.areas,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: brandBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MapArea>(
          value: selected,
          iconEnabledColor: Colors.white,
          dropdownColor: Colors.white,
          hint:
              const Text('Chọn khu vực', style: TextStyle(color: Colors.white)),
          items: areas
              .map((a) => DropdownMenuItem<MapArea>(
                    value: a,
                    child: Text(a.name),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onSelected(v);
          },
          style: const TextStyle(color: Colors.black87),
        ),
      ),
    );
  }
}
