import 'package:flutter/material.dart';

import '../state/booking_controller.dart';
import '../widgets/area_header.dart';
import '../widgets/station_sheet.dart';
import '../widgets/map_view.dart';
import '../widgets/route_footer.dart';
import '../../../theme/colors.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late final BookingController c;

  @override
  void initState() {
    super.initState();
    c = BookingController()..init();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Đặt chuyến'),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: c.canBook
                    ? () async {
                        await c.createRide();
                        await c
                            .ensureOsrm(); // nếu BE chưa gửi path thì vẽ OSRM
                      }
                    : null,
                child: const Text('Đặt cuốc'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          backgroundColor: grayBg,
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Header chọn khu vực (bo góc màu xanh)
                AreaHeader(
                  areas: c.areas,
                  selected: c.selected,
                  onSelected: (a) => c.selectArea(a),
                ),

                const SizedBox(height: 12),

                // Sheet chọn bến
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: c.loadingStations
                        ? const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : SizedBox(
                            height: 220,
                            child: StationSheet(
                              stations: c.stations,
                              picked: c.pickedIds,
                              onAdd: c.addStation,
                              onRemove: c.removeStation,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Map trung tâm
                Expanded(
                  child: MapView(
                    area: c.selected,
                    vehicle: c.vehiclePos,
                    stations: c.stations,
                    visited: c.visited,
                    remaining: c.remaining,
                    bounds: c.viewBounds,
                  ),
                ),
              ],
            ),
          ),

          // Footer trạng thái xe + lộ trình
          bottomNavigationBar: RouteFooter(
            plate: c.tel?.carId ?? 'Xe tự hành',
            status: c.statusText,
            speedKmh: c.tel?.speed ?? 0,
            chargePercent: c.tel?.charge ?? 0,
            distance: c.distanceToNext,
            points: c.tel?.points ?? const [],
          ),
        );
      },
    );
  }
}
