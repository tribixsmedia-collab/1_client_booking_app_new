import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether visitors may browse the catalogue without an account.
///
/// On the web the app opens on the home page and only asks for a phone
/// number when someone actually books - a browser tab that demands an OTP
/// before showing anything loses the visitor. The installed Android and iOS
/// apps keep opening on the login screen, which is why this is not simply
/// `true`. Set it to `true` to use the same guest flow everywhere.
const bool kGuestBrowsing = kIsWeb;

// Base URL of your Django backend.
//
// IMPORTANT - which value to use depends on WHERE you're running the app:
//   - Android Emulator  -> http://10.0.2.2:8000        (10.0.2.2 = your PC's localhost, from the emulator's view)
//   - iOS Simulator     -> http://127.0.0.1:8000
//   - Real phone (same WiFi as your PC) -> http://<YOUR_PC_LAN_IP>:8000
//     Find your PC's LAN IP on Windows with: ipconfig  (look for "IPv4 Address")
//     Also make sure Django runs with: python manage.py runserver 0.0.0.0:8000
//     (not just runserver, which only listens on localhost)
//   - Web (flutter run -d chrome) -> http://127.0.0.1:8000, or your PC's LAN IP
//     if Django is on another machine. The backend already sets
//     CORS_ALLOW_ALL_ORIGINS, so a browser on a different origin can call it.
//     Note that a page served over https can only call an https API - browsers
//     block mixed content - so use https on both once you deploy.
//
// Override without editing this file (handy for a web deploy):
//   flutter build web --dart-define=API_BASE_URL=https://api.example.com/api
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: "http://192.168.1.8:8000/api",
);
