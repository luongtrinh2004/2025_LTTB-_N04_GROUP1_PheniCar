import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'theme/app_theme.dart';
import 'data/api.dart';
import 'features/auth/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/config.env");
  runApp(const PheniCarApp());
}

class PheniCarApp extends StatelessWidget {
  const PheniCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PheniCar',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: LoginPage(api: Api()), // <-- BẮT ĐẦU từ Login
    );
  }
}
