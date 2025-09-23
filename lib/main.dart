import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'data/api.dart';
import 'features/auth/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = Api();
  // dùng service mới
  api.mqtt.connect(onStatus: (s) => debugPrint("MQTT: $s"));

  runApp(PheniCarApp(api: api));
}

class PheniCarApp extends StatelessWidget {
  final Api api;
  const PheniCarApp({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PheniCar',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: LoginPage(api: api),
    );
  }
}
