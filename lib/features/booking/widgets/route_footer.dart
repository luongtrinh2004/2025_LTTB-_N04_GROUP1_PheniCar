import 'package:flutter/material.dart';
import '../../../data/models/telemetry.dart';
import '../../../theme/colors.dart';

class RouteFooter extends StatelessWidget {
  final String plate;
  final String status;
  final double speedKmh;
  final double chargePercent;
  final double? distance; // mét
  final List<OrderPoint> points;

  const RouteFooter({
    super.key,
    required this.plate,
    required this.status,
    required this.speedKmh,
    required this.chargePercent,
    required this.distance,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final distText = distance != null ? '${distance!.round()} m' : '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 10)
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              CircleAvatar(
                  backgroundColor: brandBlue,
                  child: const Icon(Icons.directions_car, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plate,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                          '$status • ${speedKmh.toStringAsFixed(1)} km/h • Pin ${chargePercent.toStringAsFixed(0)}% • Cách điểm kế: $distText',
                          style: const TextStyle(color: Colors.black54)),
                    ]),
              ),
              TextButton(onPressed: null, child: const Text('GrabNow')),
            ]),
            const SizedBox(height: 6),
            Row(children: const [
              Icon(Icons.route, color: brandBlue, size: 18),
              SizedBox(width: 6),
              Text('Trạng thái lộ trình',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ...points.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final st = [
                    'Routing',
                    'Routed',
                    'Going',
                    'Stopping',
                    'Done'
                  ][p.orderStatus] ??
                  '—';
              final color = p.orderStatus == 4 ? Colors.grey : brandBlue;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.12),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: color, width: 2),
                    ),
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(right: 8),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                      child: Text(p.title ?? 'Điểm #${i + 1}',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(st,
                      style: TextStyle(
                          color: p.orderStatus == 4 ? Colors.grey : brandBlue,
                          fontWeight: FontWeight.w600)),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}
