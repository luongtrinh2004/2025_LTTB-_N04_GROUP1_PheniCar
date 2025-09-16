import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../core/env.dart';

typedef OnTelemetry = void Function(Map<String, dynamic> json);
typedef OnStatus = void Function(Map<String, dynamic> json);

class MqttService {
  MqttServerClient? _client;

  Future<void> connect({
    required OnTelemetry onTelemetry,
    required OnStatus onStatus,
  }) async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    final uri = Uri.parse(Env.mqttWs); // ws://host:port/mqtt
    final clientId = 'roboride_${DateTime.now().millisecondsSinceEpoch}';

    final c = MqttServerClient.withPort(uri.host, clientId, uri.port);
    c.useWebSocket = true;
    // c.websocketPath = uri.path; // mặc định '/mqtt', nếu package của bạn có field này thì mở
    c.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    c.keepAlivePeriod = 30;
    c.logging(on: false);

    final conn = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(Env.mqttUser, Env.mqttPass)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    c.connectionMessage = conn;
    _client = c;

    final status = await c.connect();
    if (status?.state != MqttConnectionState.connected) {
      throw Exception('MQTT connect failed: ${status?.state}');
    }

    c.subscribe('car/+/telemetry', MqttQos.atLeastOnce);
    c.subscribe('car/+/status', MqttQos.atLeastOnce);

    c.updates?.listen((events) {
      for (final ev in events) {
        final topic = ev.topic;
        final msg = ev.payload as MqttPublishMessage;
        final str =
            MqttPublishPayload.bytesToStringAsString(msg.payload.message);
        try {
          final js = jsonDecode(str) as Map<String, dynamic>;
          if (topic.endsWith('/telemetry')) {
            onTelemetry(js);
          } else if (topic.endsWith('/status')) {
            onStatus(js);
          }
        } catch (_) {/* ignore */}
      }
    });
  }

  void disconnect() {
    _client?.disconnect(); // trên web không cần await
    _client = null;
  }

  Future<void> publishAssign(String carId, Map<String, dynamic> payload) async {
    final c = _client;
    if (c == null || c.connectionStatus?.state != MqttConnectionState.connected)
      return;
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
    c.publishMessage(
        'car/$carId/assign', MqttQos.atLeastOnce, builder.payload!);
  }
}
