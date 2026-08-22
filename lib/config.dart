// Base URL of your Django backend.
//
// IMPORTANT - which value to use depends on WHERE you're running the app:
//   - Android Emulator  -> http://10.0.2.2:8000        (10.0.2.2 = your PC's localhost, from the emulator's view)
//   - iOS Simulator     -> http://127.0.0.1:8000
//   - Real phone (same WiFi as your PC) -> http://<YOUR_PC_LAN_IP>:8000
//     Find your PC's LAN IP on Windows with: ipconfig  (look for "IPv4 Address")
//     Also make sure Django runs with: python manage.py runserver 0.0.0.0:8000
//     (not just runserver, which only listens on localhost)
const String kApiBaseUrl = "http://192.168.1.11:8000/api";
