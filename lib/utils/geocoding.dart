import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'plus_code.dart';

/// What is at a point: an address to show, the town it is in, and the Plus
/// Code for the square itself.
///
/// [plusCode] is never empty for a real point. It is worked out on the phone
/// by [plusCodeFor] rather than waited for, so it survives a geocoder that is
/// down, an airplane-mode moment, and our own backend being unreachable --
/// which is exactly the situation in which a customer standing in a lane with
/// no street name most needs something to give the vendor.
class GeocodedPlace {
  /// The readable address, or null when no geocoder could name one.
  final String? address;

  /// The town, for writing the code the short way. '' when unknown.
  final String locality;

  /// The full code -- "7M5237MC+37" -- which resolves anywhere.
  final String plusCode;

  const GeocodedPlace({
    this.address,
    this.locality = '',
    required this.plusCode,
  });

  /// The short form -- "37MC+37" -- or '' when there is no code to trim.
  String get plusCodeLocal => localPlusCode(plusCode);

  /// How to show it: "37MC+37, Chennai" when the town is known, the full code
  /// when it is not.
  String get plusCodeDisplay => displayPlusCode(plusCode, locality: locality);
}

/// Converts lat/long -> an address, a town and a Plus Code.
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
Future<GeocodedPlace> describePoint(double latitude, double longitude) async {
  final proxied = await _backendReverseGeocode(latitude, longitude);
  if (proxied != null) return proxied;

  final free = await _nominatimReverseGeocode(latitude, longitude);
  if (free != null) return free;

  // Nobody could name the place. The code still stands on its own.
  return GeocodedPlace(plusCode: plusCodeFor(latitude, longitude));
}

/// The address alone, for callers that want nothing else.
Future<String?> reverseGeocode(double latitude, double longitude) async =>
    (await describePoint(latitude, longitude)).address;

Future<GeocodedPlace?> _backendReverseGeocode(
  double latitude,
  double longitude,
) async {
  try {
    final uri = Uri.parse(
      '$kApiBaseUrl/maps/reverse-geocode/?lat=$latitude&lng=$longitude',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final address = data['address'] as String?;
    return GeocodedPlace(
      address: (address != null && address.isNotEmpty) ? address : null,
      locality: (data['locality'] as String?) ?? '',
      // The backend computes the same code from the same point, so this
      // agrees with plusCodeFor by construction -- both suites of vectors
      // exist to keep it that way. Falling back to the local one covers an
      // older backend that does not send the field yet.
      plusCode: (data['plus_code'] as String?)?.isNotEmpty == true
          ? data['plus_code'] as String
          : plusCodeFor(latitude, longitude),
    );
  } catch (_) {
    return null;
  }
}

Future<GeocodedPlace?> _nominatimReverseGeocode(
  double latitude,
  double longitude,
) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json'
      '&addressdetails=1&lat=$latitude&lon=$longitude',
    );
    final res = await http.get(
      uri,
      headers: {'User-Agent': 'HomeServiceApp/1.0'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return GeocodedPlace(
        address: data['display_name'] as String?,
        locality: _localityFrom(data['address']),
        plusCode: plusCodeFor(latitude, longitude),
      );
    }
  } catch (_) {
    // Silently ignore -- reverse geocoding is a convenience, not required.
  }
  return null;
}

/// Most specific first, matching the order the backend uses: a Plus Code
/// reads best against the smallest place whose name is recognised.
const List<String> _localityKeys = [
  'city',
  'town',
  'village',
  'municipality',
  'suburb',
  'city_district',
  'county',
  'state_district',
  'state',
];

String _localityFrom(dynamic address) {
  if (address is! Map) return '';
  for (final key in _localityKeys) {
    final value = address[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return '';
}

// ---------------------------------------------------------------------------
// The other direction: a code the customer typed
// ---------------------------------------------------------------------------

/// Where a Plus Code points, or why it could not be read.
class PlusCodeLookup {
  final double? latitude;
  final double? longitude;
  final String plusCode;
  final String locality;
  final String? address;

  /// Wording to show the customer. Null when the lookup succeeded.
  final String? error;

  const PlusCodeLookup({
    this.latitude,
    this.longitude,
    this.plusCode = '',
    this.locality = '',
    this.address,
    this.error,
  });

  bool get isFound => latitude != null && longitude != null;

  String get plusCodeDisplay => displayPlusCode(plusCode, locality: locality);
}

/// Turns whatever the customer typed into a point on the map.
///
/// A full code -- "7M5237MC+37" -- is arithmetic, so it resolves here on the
/// phone, instantly and offline. Only a short code -- "37MC+37, Chennai" --
/// has to go to the backend, because completing one means turning a town name
/// into a point, and that needs a geocoder.
///
/// [referenceLatitude]/[referenceLongitude] are wherever the map is currently
/// pointing. The backend falls back to them when the customer gave a short
/// code with no town beside it.
Future<PlusCodeLookup> lookupPlusCode(
  String text, {
  double? referenceLatitude,
  double? referenceLongitude,
}) async {
  final parsed = splitCodeAndLocality(text);
  if (parsed.code.isEmpty) {
    return const PlusCodeLookup(
      error: 'Enter a Plus Code, for example 37MC+37, Chennai.',
    );
  }

  if (isFullPlusCode(parsed.code)) {
    final area = decodePlusCode(parsed.code);
    return PlusCodeLookup(
      latitude: area.latitude,
      longitude: area.longitude,
      plusCode: parsed.code.toUpperCase(),
      locality: parsed.locality,
    );
  }

  if (!isShortPlusCode(parsed.code)) {
    return PlusCodeLookup(error: '"${parsed.code}" is not a Plus Code.');
  }

  return _backendPlusCodeLookup(
    text,
    referenceLatitude: referenceLatitude,
    referenceLongitude: referenceLongitude,
  );
}

Future<PlusCodeLookup> _backendPlusCodeLookup(
  String text, {
  double? referenceLatitude,
  double? referenceLongitude,
}) async {
  try {
    final query = <String, String>{'code': text};
    if (referenceLatitude != null && referenceLongitude != null) {
      query['lat'] = '$referenceLatitude';
      query['lng'] = '$referenceLongitude';
    }
    final uri = Uri.parse('$kApiBaseUrl/maps/plus-code/')
        .replace(queryParameters: query);

    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      return PlusCodeLookup(
        error: (data['detail'] as String?) ?? 'That Plus Code could not be found.',
      );
    }

    return PlusCodeLookup(
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      plusCode: (data['plus_code'] as String?) ?? '',
      locality: (data['locality'] as String?) ?? '',
      address: data['address'] as String?,
    );
  } catch (_) {
    // A short code cannot be completed without knowing where it was written,
    // so there is nothing to fall back to -- say what would work instead.
    return const PlusCodeLookup(
      error: 'Could not look that up. Add the town, for example '
          '"37MC+37, Chennai", or check your connection.',
    );
  }
}
