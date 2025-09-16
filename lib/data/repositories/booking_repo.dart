import '../sources/worker_api.dart';
import '../sources/routing_service.dart';

class BookingRepo {
  final WorkerApi api;
  final RoutingService router;
  BookingRepo({required this.api, required this.router});
}
