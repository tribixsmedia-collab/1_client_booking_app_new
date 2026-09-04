import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config.dart';
import 'theme.dart';
import 'firebase_options.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/phone_entry_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/branding_service.dart';
import 'services/map_config_service.dart';
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

  // Same shape for the map: the cached choice first so the location picker
  // opens on the right basemap, then a refresh for the next time it is opened.
  await MapConfigService.load();
  MapConfigService.refresh();

  // Already signed in from a previous session? Refresh the device token.
  final loggedIn = await ApiService.isLoggedIn();
  if (loggedIn) {
    PushService.registerToken();
  }

  runApp(CustomerApp(home: _firstScreen(loggedIn)));
}

/// Where the app opens.
///
/// The installed apps get the animated splash. The web does not: the browser
/// already shows its own loading state while the bundle downloads, so a
/// second full-screen logo on top of that is two splashes in a row and a
/// wait the visitor did not need. Everything the splash used to do while it
/// waited - load branding, check the session - has already happened above.
Widget _firstScreen(bool loggedIn) {
  if (!kIsWeb) return const SplashScreen();
  return loggedIn || kGuestBrowsing
      ? const MainNavigationScreen()
      : const PhoneEntryScreen();
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Service',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: navigatorKey,
      home: home,
    );
  }
}
