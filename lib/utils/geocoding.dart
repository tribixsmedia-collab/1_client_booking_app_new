import 'dart:convert';
import 'package:http/http.dart' as http;

/// Shared helper: converts lat/long -> a readable address using
/// OpenStreetMap's free Nominatim service. Used by both the auto-fetch
/// flow on the booking screen and the map picker screen.
Future<String?> reverseGeocode(double latitude, double longitude) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude',
    );
    final res = await http.get(
      uri,
      headers: {'User-Agent': 'HomeServiceApp/1.0'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['display_name'] as String?;
    }
  } catch (_) {
    // Silently ignore -- reverse geocoding is a convenience, not required.
  }
  return null;
}
