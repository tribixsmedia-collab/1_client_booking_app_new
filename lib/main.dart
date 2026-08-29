import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/branding_service.dart';
import 'services/push_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (PushService.isSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await PushService.init();

  // Cached branding first so the splash paints the right logo immediately,
  // then refresh in the background for the next launch.
  await BrandingService.load();
  BrandingService.refresh();

  // Already signed in from a previous session? Refresh the device token.
  if (await ApiService.isLoggedIn()) {
    PushService.registerToken();
  }

  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Service',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}
