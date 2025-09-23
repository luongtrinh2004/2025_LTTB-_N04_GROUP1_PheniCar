// lib/services/mqtt_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:mqtt_client/mqtt_browser_client.dart' as b;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:mobile/core/env.dart';
import 'package:mobile/data/models.dart';

class MqttService {
  MqttClient? _mq;

  // Expose trạng thái nhanh
  bool get isConnected =>
      _mq?.connectionStatus?.state == MqttConnectionState.connected;

  // Stream telemetry
  final _telemetryCtrl = StreamController<Telemetry>.broadcast();
  Stream<Telemetry> get telemetryStream => _telemetryCtrl.stream;

  Future<void> connect({void Function(String status)? onStatus}) async {
    if (!Env.enableMqtt) {
      onStatus?.call('mqtt disabled');
      debugPrint('MQTT disabled by config');
      return;
    }

    final clientId =
        'flutter_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';

    // ---- Client theo nền tảng
    if (kIsWeb) {
      // Web: dùng nguyên URL ws/wss từ Env.mqttWs, KHÔNG set port
      final c = b.MqttBrowserClient(Env.mqttWs, clientId);
      c.logging(on: false);
      c.keepAlivePeriod = 20;
      c.websocketProtocols = const ['mqtt'];
      c.setProtocolV311();
      c.onConnected = () => onStatus?.call('connected');
      c.onDisconnected = () => onStatus?.call('disconnected');
      c.onSubscribed = (t) => onStatus?.call('sub:$t');
      _mq = c;
    } else {
      // Mobile/Desktop: TCP 1883
      final u = Uri.parse(Env.mqttWs);
      final host = u.host.isNotEmpty ? u.host : '127.0.0.1';

      final c = MqttServerClient(host, clientId);
      c.logging(on: false);
      c.keepAlivePeriod = 20;
      c.port = 1883;
      c.secure = false;
      c.setProtocolV311();
      c.connectTimeoutPeriod = 10000;
      c.onConnected = () => onStatus?.call('connected');
      c.onDisconnected = () => onStatus?.call('disconnected');
      c.onSubscribed = (t) => onStatus?.call('sub:$t');
      _mq = c;
    }

    // Auth + clean session
    var msg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    if (Env.mqttUsername.isNotEmpty || Env.mqttPassword.isNotEmpty) {
      msg = msg.authenticateAs(Env.mqttUsername, Env.mqttPassword);
    }
    _mq!.connectionMessage = msg;

    // Kết nối
    try {
      await _mq!.connect();
    } catch (e) {
      onStatus?.call('connect-error');
      debugPrint('MQTT connect error: $e');
      try {
        _mq?.disconnect();
      } catch (_) {}
      return;
    }

    // Lắng nghe message
    _mq?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (final rec in events) {
        final msg = rec.payload;
        if (msg is! MqttPublishMessage) continue;

        final payload =
            MqttPublishPayload.bytesToStringAsString(msg.payload.message);

        // chỉ xử lý telemetry
        if (rec.topic.endsWith('/telemetry')) {
          try {
            final js = jsonDecode(payload) as Map<String, dynamic>;
            _telemetryCtrl.add(Telemetry.fromJson(js));
          } catch (e) {
            // ignore malformed payload
          }
        }
      }
    });

    // Subscribe các topic mặc định
    await subscribe('car/+/telemetry');
    await subscribe('car/+/status');
  }

  Future<void> subscribe(String topic,
      {MqttQos qos = MqttQos.atLeastOnce}) async {
    if (!isConnected) return;
    _mq!.subscribe(topic, qos);
  }

  Future<void> unsubscribe(String topic) async {
    if (!isConnected) return;
    _mq!.unsubscribe(topic);
  }

  // tiện gửi test
  Future<void> publishJson(String topic, Map<String, dynamic> data,
      {MqttQos qos = MqttQos.atLeastOnce, bool retain = false}) async {
    if (!isConnected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addUTF8String(jsonEncode(data));
    _mq!.publishMessage(topic, qos, builder.payload!, retain: retain);
  }

  Future<void> dispose() async {
    try {
      await _telemetryCtrl.close();
    } catch (_) {}
    try {
      _mq?.disconnect();
    } catch (_) {}
  }
}
