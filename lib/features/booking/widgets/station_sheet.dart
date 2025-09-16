import 'package:flutter/material.dart';
import '../../../data/models/station.dart';

class StationSheet extends StatefulWidget {
  final List<Station> stations;
  final List<String> picked;
  final void Function(String id) onAdd;
  final void Function(String id) onRemove;

  const StationSheet({
    super.key,
    required this.stations,
    required this.picked,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<StationSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final query = q.trim().toLowerCase();
    final list = query.isEmpty
        ? widget.stations
        : widget.stations
            .where((s) => s.name.toLowerCase().contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Chọn bến',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Text(
              '(${widget.picked.length} đã chọn)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm bến...',
          ),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Không có bến phù hợp'))
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = list[i];
                    final picked = widget.picked.contains(s.id);
                    return ListTile(
                      dense: true,
                      title: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${s.lat.toStringAsFixed(6)}, ${s.lng.toStringAsFixed(6)}',
                      ),
                      trailing: picked
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () => widget.onRemove(s.id),
                              tooltip: 'Bỏ chọn',
                            )
                          : IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Colors.green),
                              onPressed: () => widget.onAdd(s.id),
                              tooltip: 'Thêm điểm',
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
