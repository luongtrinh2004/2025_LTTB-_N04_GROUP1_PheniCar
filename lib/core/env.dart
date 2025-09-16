import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get workerBase => (dotenv.maybeGet('WORKER_BASE') ??
          const String.fromEnvironment('WORKER_BASE', defaultValue: ''))
      .replaceFirst(RegExp(r'/*$'), '');

  static String get dapiBase => (dotenv.maybeGet('DAPI_BASE') ??
          const String.fromEnvironment('DAPI_BASE', defaultValue: ''))
      .replaceFirst(RegExp(r'/*$'), '');

  static String get osrmBase => (dotenv.maybeGet('OSRM_BASE') ??
          const String.fromEnvironment('OSRM_BASE',
              defaultValue: 'https://router.project-osrm.org/route/v1/driving'))
      .replaceFirst(RegExp(r'/*$'), '');

  static String get mqttWs =>
      dotenv.maybeGet('MQTT_WS') ??
      const String.fromEnvironment('MQTT_WS', defaultValue: '');

  static String get mqttUser =>
      dotenv.maybeGet('MQTT_USERNAME') ??
      const String.fromEnvironment('MQTT_USERNAME', defaultValue: '');

  static String get mqttPass =>
      dotenv.maybeGet('MQTT_PASSWORD') ??
      const String.fromEnvironment('MQTT_PASSWORD', defaultValue: '');

  static Duration get routeTimeout {
    final s = dotenv.maybeGet('ROUTE_TIMEOUT_MS') ??
        const String.fromEnvironment('ROUTE_TIMEOUT_MS', defaultValue: '7000');
    final ms = int.tryParse(s) ?? 7000;
    return Duration(milliseconds: ms);
  }
}
