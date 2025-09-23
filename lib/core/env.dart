// lib/core/env.dart
class Env {
  // Dolphin API backend (tự thêm /v1 khi gọi _dapi)
  static const dapiBase = "http://116.118.95.187:3000/api";

  // Worker service (Node simulator API)
  static const workerBase = "http://116.118.95.187:3002/api";

  // OSRM routing engine
  static const osrmBase = "https://router.project-osrm.org/route/v1/driving";

  // MQTT over WebSocket
  static const mqttWs = "ws://116.118.95.187:8083/mqtt";
  static const mqttUsername = "ducchien0612";
  static const mqttPassword = "123456";

  // Routing timeout (ms)
  static const routeTimeoutMs = 5000;
  static const enableMqtt = true;
}
