import '../../core/utils/geo.dart';

class Vehicle {
  final String id;
  final bool online;
  final LatLng? pos;
  final double speed;
  final double? charge;

  Vehicle(
      {required this.id,
      required this.online,
      this.pos,
      this.speed = 0,
      this.charge});
}
