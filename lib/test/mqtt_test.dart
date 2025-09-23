import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mobile/core/env.dart';

Future<void> main() async {
  final client =
      MqttBrowserClient('ws://116.118.95.187:8083/mqtt', 'flutter_test_client');

  client.keepAlivePeriod = 20;
  client.logging(on: true);
  client.port = 8083;
  client.websocketProtocols = const <String>['mqtt'];
  client.setProtocolV311(); // BẮT BUỘC PHẢI GỌI

  client.onConnected = () => print('✅ MQTT connected!');
  client.onDisconnected = () => print('❌ MQTT disconnected!');
  client.onSubscribed = (t) => print('📡 Subscribed to $t');

  var msg = MqttConnectMessage()
      .withClientIdentifier('flutter_test_client')
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);

  if (Env.mqttUsername.isNotEmpty || Env.mqttPassword.isNotEmpty) {
    msg = msg.authenticateAs(Env.mqttUsername, Env.mqttPassword);
  }
  client.connectionMessage = msg;

  try {
    await client.connect();
    print('🚀 Connected OK!');
    client.subscribe('car/+/status', MqttQos.atLeastOnce);
  } catch (e) {
    print('❌ Connection failed: $e');
    client.disconnect();
  }
}
