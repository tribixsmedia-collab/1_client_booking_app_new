import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Shared helper: converts lat/long -> a readable address. Used by both the
/// auto-fetch flow on the booking screen and the map picker screen.
///
/// The lookup goes through our own backend rather than straight out to a
/// geocoder. That is what lets the admin switch between the free map and
/// Google Maps from the dashboard: the backend asks Google when a key is set
/// there and OpenStreetMap's Nominatim when it is not, so the app has one code
/// path either way and no key ever has to ship inside it.
///
/// Nominatim stays here as a direct fallback for the one case the proxy cannot
/// cover — our backend unreachable — because a missing address only costs the
/// customer a bit of typing, and typing an address into a blank field beats
/// staring at a spinner.
Future<String?> reverseGeocode(double latitude, double longitude) async {
  final proxied = await _backendReverseGeocode(latitude, longitude);
  if (proxied != null) return proxied;
  return _nominatimReverseGeocode(latitude, longitude);
}

Future<String?> _backendReverseGeocode(double latitude, double longitude) async {
  try {
    final uri = Uri.parse(
      '$kApiBaseUrl/maps/reverse-geocode/?lat=$latitude&lng=$longitude',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final address = data['address'] as String?;
    return (address != null && address.isNotEmpty) ? address : null;
  } catch (_) {
    return null;
  }
}

Future<String?> _nominatimReverseGeocode(
  double latitude,
  double longitude,
) async {
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
