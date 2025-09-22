import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // chuẩn hoá: bỏ dấu '/' cuối nếu có
  static String _trimSlash(String s) => s.replaceFirst(RegExp(r'/*$'), '');

  /// Worker Node (simulator)
  static String get workerBase => _trimSlash(
        dotenv.env['WORKER_BASE'] ?? 'http://localhost:3002',
      );

  /// Dolphin API base (nên là .../api hoặc .../api/v1 tuỳ bạn set)
  /// Ví dụ của bạn: http://116.118.95.187:3000/api
  static String get dapiBase => _trimSlash(
        dotenv.env['DAPI_BASE'] ?? 'http://localhost:3000/api',
      );

  /// OSRM
  static String get osrmBase => _trimSlash(
        dotenv.env['OSRM_BASE'] ??
            'https://router.project-osrm.org/route/v1/driving',
      );

  /// MQTT WS
  static String get mqttWs =>
      dotenv.env['MQTT_WS'] ?? 'ws://localhost:8083/mqtt';
  static String get mqttUsername => dotenv.env['MQTT_USERNAME'] ?? '';
  static String get mqttPassword => dotenv.env['MQTT_PASSWORD'] ?? '';

  /// Routing timeout
  static int get routeTimeoutMs =>
      int.tryParse(dotenv.env['ROUTE_TIMEOUT_MS'] ?? '') ?? 7000;
}
