import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ⬅️ THÊM DÒNG NÀY
import 'theme/app_theme.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config.env'); // ⬅️ Nạp env
  runApp(const RoboRideApp());
}

class RoboRideApp extends StatelessWidget {
  const RoboRideApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RoboRide',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
