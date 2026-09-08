/// Plus Codes -- Google's Open Location Code -- worked out on the phone.
///
/// A Plus Code is a street address for a place that has no street address,
/// which in this country is most of them: "7M5237MC+37" is a square about
/// fourteen metres across, and "37MC+37, Chennai" is the same square written
/// the way a customer would say it down a phone line.
///
/// This is a port of the same algorithm the backend runs in
/// `maps/plus_codes.py`, and the two have to agree character for character --
/// `test/plus_code_test.dart` holds Google's published vectors for exactly
/// that reason. It is duplicated rather than fetched because it is arithmetic,
/// not a service: the picker re-encodes on every frame of a map drag, and a
/// network round trip per frame would be both slow and pointless.
///
/// Only the directions the app needs are here. Encoding a point and decoding
/// a *full* code are pure maths and happen offline. Completing a *short* code
/// -- "37MC+37, Chennai" -- needs the town turned into a point, which needs a
/// geocoder, so that one goes to the backend (`/api/maps/plus-code/`).
library;

const String _alphabet = '23456789CFGHJMPQRVWX';
const int _base = 20;

const String separator = '+';
const int _separatorPosition = 8;
const String _padding = '0';

const int _latitudeMax = 90;
const int _longitudeMax = 180;

const int _maxDigitCount = 15;

const int _pairCodeLength = 10;
const int _pairPrecision = _base * _base * _base;
const int _pairFirstPlaceValue = 160000; // 20^4

const int _gridCodeLength = _maxDigitCount - _pairCodeLength;
const int _gridColumns = 4;
const int _gridRows = 5;
const int _gridLatFirstPlaceValue = 625; // 5^4
const int _gridLngFirstPlaceValue = 256; // 4^4

const int _finalLatPrecision = _pairPrecision * 3125; // * 5^5
const int _finalLngPrecision = _pairPrecision * 1024; // * 4^5

/// The first four characters -- roughly 100km across -- which a town name
/// replaces when the code is written the short way.
const int areaCodeLength = 4;

/// The everyday length: a square about fourteen metres across.
const int defaultCodeLength = _pairCodeLength;

/// The square a code stands for.
///
/// A Plus Code is an area, never a point. [latitude] and [longitude] are its
/// centre, which is where a pin goes; the bounds are there for anything that
/// wants to draw the square itself rather than imply metre accuracy.
class PlusCodeArea {
  final double latitudeLo;
  final double longitudeLo;
  final double latitudeHi;
  final double longitudeHi;
  final int codeLength;

  const PlusCodeArea({
    required this.latitudeLo,
    required this.longitudeLo,
    required this.latitudeHi,
    required this.longitudeHi,
    required this.codeLength,
  });

  double get latitude {
    final centre = latitudeLo + (latitudeHi - latitudeLo) / 2;
    return centre < _latitudeMax ? centre : _latitudeMax.toDouble();
  }

  double get longitude {
    final centre = longitudeLo + (longitudeHi - longitudeLo) / 2;
    return centre < _longitudeMax ? centre : _longitudeMax.toDouble();
  }
}

/// Thrown for a code that cannot be read. The message is worded to be shown
/// to a customer as-is.
class PlusCodeException implements Exception {
  final String message;
  const PlusCodeException(this.message);

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Reading a code
// ---------------------------------------------------------------------------

/// Whether this is a code at all. Says nothing about where it is.
bool isValidPlusCode(String? code) {
  if (code == null || code.isEmpty) return false;

  // Exactly one separator, at an even position no later than the eighth.
  if (separator.allMatches(code).length != 1) return false;
  final separatorAt = code.indexOf(separator);
  if (separatorAt > _separatorPosition || separatorAt.isOdd) return false;
  if (code.length == 1) return false;

  final paddingAt = code.indexOf(_padding);
  if (paddingAt != -1) {
    // Padding says "somewhere in this large area", which only makes sense on
    // a code that is otherwise complete.
    if (separatorAt < _separatorPosition) return false;
    if (paddingAt == 0) return false;
    final run = code.substring(paddingAt, code.lastIndexOf(_padding) + 1);
    if (run.length.isOdd) return false;
    if (run.split('').any((character) => character != _padding)) return false;
    if (!code.endsWith(separator)) return false;
  }

  // A lone digit after the separator would be half a pair.
  if (code.length - separatorAt - 1 == 1) return false;

  final body = code.replaceAll(separator, '').replaceAll(_padding, '');
  return body
      .toUpperCase()
      .split('')
      .every((character) => _alphabet.contains(character));
}

/// A code with its leading digits dropped: needs somewhere to be read against.
bool isShortPlusCode(String? code) {
  if (!isValidPlusCode(code)) return false;
  final separatorAt = code!.indexOf(separator);
  return separatorAt >= 0 && separatorAt < _separatorPosition;
}

/// A code that stands on its own anywhere on earth.
bool isFullPlusCode(String? code) {
  if (!isValidPlusCode(code) || isShortPlusCode(code)) return false;

  final upper = code!.toUpperCase();
  // The first digit alone can put the code off the top of the globe.
  if (_alphabet.indexOf(upper[0]) * _base >= _latitudeMax * 2) return false;
  if (upper.length > 1) {
    if (_alphabet.indexOf(upper[1]) * _base >= _longitudeMax * 2) return false;
  }
  return true;
}

/// The square a full code stands for.
///
/// Throws [PlusCodeException] on anything that is not a full code -- a short
/// one cannot be read without knowing roughly where it was written, which is
/// what the backend endpoint is for.
PlusCodeArea decodePlusCode(String code) {
  if (!isFullPlusCode(code)) {
    throw PlusCodeException('"$code" is not a complete Plus Code.');
  }

  // Separator and padding carry no value; they only mark shape.
  var digits = code.toUpperCase().replaceAll(RegExp(r'[+0]'), '');
  if (digits.length > _maxDigitCount) {
    digits = digits.substring(0, _maxDigitCount);
  }

  // Worked out as integers and converted to degrees only at the end, so
  // nothing drifts across the fifteen digits.
  var normalLat = -_latitudeMax * _pairPrecision;
  var normalLng = -_longitudeMax * _pairPrecision;
  var gridLat = 0;
  var gridLng = 0;

  final pairDigits =
      digits.length < _pairCodeLength ? digits.length : _pairCodeLength;
  var placeValue = _pairFirstPlaceValue;
  for (var index = 0; index < pairDigits; index += 2) {
    normalLat += _alphabet.indexOf(digits[index]) * placeValue;
    normalLng += _alphabet.indexOf(digits[index + 1]) * placeValue;
    if (index < pairDigits - 2) placeValue = placeValue ~/ _base;
  }

  var latitudeSize = placeValue / _pairPrecision;
  var longitudeSize = placeValue / _pairPrecision;

  if (digits.length > _pairCodeLength) {
    var rowPlaceValue = _gridLatFirstPlaceValue;
    var columnPlaceValue = _gridLngFirstPlaceValue;
    for (var index = _pairCodeLength; index < digits.length; index++) {
      final digitValue = _alphabet.indexOf(digits[index]);
      gridLat += (digitValue ~/ _gridColumns) * rowPlaceValue;
      gridLng += (digitValue % _gridColumns) * columnPlaceValue;
      if (index < digits.length - 1) {
        rowPlaceValue = rowPlaceValue ~/ _gridRows;
        columnPlaceValue = columnPlaceValue ~/ _gridColumns;
      }
    }
    latitudeSize = rowPlaceValue / _finalLatPrecision;
    longitudeSize = columnPlaceValue / _finalLngPrecision;
  }

  final latitude = normalLat / _pairPrecision + gridLat / _finalLatPrecision;
  final longitude = normalLng / _pairPrecision + gridLng / _finalLngPrecision;

  return PlusCodeArea(
    latitudeLo: latitude,
    longitudeLo: longitude,
    latitudeHi: latitude + latitudeSize,
    longitudeHi: longitude + longitudeSize,
    codeLength: digits.length,
  );
}

// ---------------------------------------------------------------------------
// Writing a code
// ---------------------------------------------------------------------------

/// The Plus Code for a point.
String encodePlusCode(
  double latitude,
  double longitude, {
  int codeLength = defaultCodeLength,
}) {
  if (codeLength < 2 || (codeLength < _pairCodeLength && codeLength.isOdd)) {
    throw PlusCodeException('$codeLength is not a usable code length.');
  }
  if (codeLength > _maxDigitCount) codeLength = _maxDigitCount;

  var lat = _clipLatitude(latitude);
  final lng = _normalizeLongitude(longitude);
  // The north pole is the top edge of no square at all, so it belongs to the
  // one below it.
  if (lat == _latitudeMax) lat -= _latitudePrecision(codeLength);

  var latValue = _scaled(lat + _latitudeMax, _finalLatPrecision);
  var lngValue = _scaled(lng + _longitudeMax, _finalLngPrecision);

  var code = '';
  if (codeLength > _pairCodeLength) {
    for (var i = 0; i < _gridCodeLength; i++) {
      final index =
          (latValue % _gridRows) * _gridColumns + (lngValue % _gridColumns);
      code = _alphabet[index] + code;
      latValue = latValue ~/ _gridRows;
      lngValue = lngValue ~/ _gridColumns;
    }
  } else {
    latValue = latValue ~/ 3125; // 5^5
    lngValue = lngValue ~/ 1024; // 4^5
  }

  for (var i = 0; i < _pairCodeLength ~/ 2; i++) {
    code = _alphabet[lngValue % _base] + code;
    code = _alphabet[latValue % _base] + code;
    latValue = latValue ~/ _base;
    lngValue = lngValue ~/ _base;
  }

  code = code.substring(0, _separatorPosition) +
      separator +
      code.substring(_separatorPosition);

  if (codeLength >= _separatorPosition) {
    return code.substring(0, codeLength + 1);
  }
  return code.substring(0, codeLength) +
      _padding * (_separatorPosition - codeLength) +
      separator;
}

/// The code for a point, or '' when there is no point.
///
/// Returning '' rather than throwing is deliberate: callers are usually
/// handing this a nullable latitude/longitude, and a missing pin is an
/// ordinary state rather than an error.
String plusCodeFor(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return '';
  if (latitude.isNaN || longitude.isNaN) return '';
  try {
    return encodePlusCode(latitude, longitude);
  } on PlusCodeException {
    return '';
  }
}

// ---------------------------------------------------------------------------
// The three ways of writing one
// ---------------------------------------------------------------------------

/// The last six-or-so characters -- "37MC+37" -- which only mean anything
/// next to a town name. '' when the code has nothing to trim.
String localPlusCode(String? code) {
  if (!isFullPlusCode(code) || code!.contains(_padding)) return '';
  return code.toUpperCase().substring(areaCodeLength);
}

/// How a code should be shown to a person: the short way when a town is
/// known, and the full code -- longer, but always resolvable -- when it is not.
String displayPlusCode(String? code, {String locality = ''}) {
  if (code == null || code.isEmpty) return '';
  final local = localPlusCode(code);
  if (local.isNotEmpty && locality.isNotEmpty) return '$local, $locality';
  return code.toUpperCase();
}

/// Pull a code and a place name out of whatever the customer pasted.
///
/// People paste "37MC+37, Chennai", or "7M5237MC+37", or a whole line off the
/// Google Maps share sheet with the address trailing behind it. All that is
/// needed is the first word containing a '+'.
({String code, String locality}) splitCodeAndLocality(String? text) {
  if (text == null || text.trim().isEmpty) return (code: '', locality: '');

  final parts = text
      .split(RegExp(r'[,\n]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return (code: '', locality: '');

  final head = parts.first;
  var locality = parts.skip(1).join(', ');

  // The head may still be "37MC+37 Chennai" with no comma.
  final words = head.split(RegExp(r'\s+'));
  var code = '';
  for (var index = 0; index < words.length; index++) {
    if (words[index].contains(separator)) {
      code = words[index];
      final trailing = words.skip(index + 1).join(' ').trim();
      if (trailing.isNotEmpty) {
        locality = locality.isEmpty ? trailing : '$trailing, $locality';
      }
      break;
    }
  }

  return (code: code.toUpperCase(), locality: locality);
}

// ---------------------------------------------------------------------------
// Bounds
// ---------------------------------------------------------------------------

double _clipLatitude(double latitude) {
  if (latitude < -_latitudeMax) return -_latitudeMax.toDouble();
  if (latitude > _latitudeMax) return _latitudeMax.toDouble();
  return latitude;
}

double _normalizeLongitude(double longitude) {
  var value = longitude;
  while (value < -_longitudeMax) {
    value += 360;
  }
  while (value >= _longitudeMax) {
    value -= 360;
  }
  return value;
}

double _latitudePrecision(int codeLength) {
  if (codeLength <= _pairCodeLength) {
    final exponent = ((codeLength / -2) + 2).floor();
    return _pow(_base.toDouble(), exponent);
  }
  return _pow(_base.toDouble(), -3) /
      _pow(_gridRows.toDouble(), codeLength - _pairCodeLength);
}

double _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent.abs(); i++) {
    result *= base;
  }
  return exponent < 0 ? 1 / result : result;
}

/// A degree value turned into whole units of the finest precision.
///
/// The reference implementation cleans the float to six decimal places and
/// then truncates. Rounding instead would move points that sit exactly on a
/// cell boundary into the next square along and produce a different code, so
/// this deliberately mirrors it rather than reaching for `round()`.
int _scaled(double value, int precision) {
  final scaled = value * precision;
  return double.parse(scaled.toStringAsFixed(6)).floor();
}
