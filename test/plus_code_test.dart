// What has to stay true about Plus Codes on the phone.
//
// The vectors below are Google's own, from the open-location-code repository,
// and the identical list is asserted on the backend in
// maps/test_plus_codes.py. That duplication is the point: the app encodes a
// pin locally on every frame of a map drag while the backend encodes the same
// pin when it serves a booking, and if the two implementations ever disagree
// the customer sees one code on screen and the vendor receives another. Both
// suites failing at once is the only way that stays visible.

import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/utils/plus_code.dart';

// Chennai, near Anna Salai.
const double chennaiLat = 13.0827;
const double chennaiLng = 80.2707;

void main() {
  group('encoding matches Google\'s published vectors', () {
    // latitude, longitude, code length, expected code
    const vectors = [
      (20.375, 2.775, 6, '7FG49Q00+'),
      (20.3700625, 2.7821875, 10, '7FG49QCJ+2V'),
      (20.3701125, 2.782234375, 11, '7FG49QCJ+2VX'),
      (20.3701135, 2.78223535, 13, '7FG49QCJ+2VXGJ'),
      (47.0000625, 8.0000625, 10, '8FVC2222+22'),
      (-41.2730625, 174.7859375, 10, '4VCPPQGP+Q9'),
      (0.5, -179.5, 4, '62G20000+'),
      (-89.9999375, -179.9999375, 10, '22222222+22'),
      (20.5, 2.5, 4, '7FG40000+'),
      (90, 1, 10, 'CFX3X2X2+X2'),
    ];

    for (final (latitude, longitude, length, expected) in vectors) {
      test('$latitude,$longitude at $length digits is $expected', () {
        expect(
          encodePlusCode(latitude.toDouble(), longitude.toDouble(),
              codeLength: length),
          expected,
        );
      });
    }

    test('every code decodes back to itself', () {
      for (final (_, _, _, code) in vectors) {
        final area = decodePlusCode(code);
        expect(
          encodePlusCode(area.latitude, area.longitude,
              codeLength: area.codeLength),
          code,
          reason: 'round trip through $code',
        );
      }
    });
  });

  group('encoding edges', () {
    test('the north pole decodes to somewhere on the map', () {
      expect(decodePlusCode(encodePlusCode(90, 1)).latitude, lessThan(90));
    });

    test('longitude wraps at the antimeridian', () {
      expect(encodePlusCode(1, 180), encodePlusCode(1, -180));
    });

    test('ten digits is a square about fourteen metres across', () {
      final area = decodePlusCode(encodePlusCode(chennaiLat, chennaiLng));

      expect(area.latitudeHi - area.latitudeLo, closeTo(0.000125, 1e-12));
    });

    test('a point on a cell boundary truncates rather than rounding up', () {
      // 20.3700625 lands exactly on an edge. Rounding would push it into the
      // next square along and produce a different code from the backend's.
      expect(encodePlusCode(20.3700625, 2.7821875), '7FG49QCJ+2V');
    });

    test('an odd short length is refused', () {
      expect(
        () => encodePlusCode(chennaiLat, chennaiLng, codeLength: 7),
        throwsA(isA<PlusCodeException>()),
      );
    });
  });

  group('validity matches Google\'s published vectors', () {
    // code, valid, short, full
    const vectors = [
      ('8FWC2345+G6', true, false, true),
      ('8FWC2345+G6G', true, false, true),
      ('8fwc2345+', true, false, true),
      ('8FWCX400+', true, false, true),
      ('WC2345+G6g', true, true, false),
      ('2345+G6', true, true, false),
      ('45+G6', true, true, false),
      ('+G6', true, true, false),
      ('G+', false, false, false),
      ('+', false, false, false),
      ('8FWC2345+G', false, false, false),
      ('8FWC2_45+G6', false, false, false),
      ('8FWC2345+G6+', false, false, false),
      ('8FWC2300+G6', false, false, false),
      ('WC2300+G6g', false, false, false),
      ('WC2345+G', false, false, false),
    ];

    for (final (code, valid, short, full) in vectors) {
      test('"$code" is valid=$valid short=$short full=$full', () {
        expect(isValidPlusCode(code), valid);
        expect(isShortPlusCode(code), short);
        expect(isFullPlusCode(code), full);
      });
    }

    test('nothing is not a code', () {
      for (final value in [null, '', '   ']) {
        expect(isValidPlusCode(value), isFalse, reason: 'for "$value"');
      }
    });

    test('decoding something unreadable throws with wording for a customer',
        () {
      expect(
        () => decodePlusCode('12 Anna Salai'),
        throwsA(isA<PlusCodeException>()),
      );
    });
  });

  group('the three ways of writing a code', () {
    test('a point becomes a full code', () {
      final code = plusCodeFor(chennaiLat, chennaiLng);

      expect(isFullPlusCode(code), isTrue);
      expect(code, '7M5237MC+37');
    });

    test('a missing pin is an empty code, not an error', () {
      expect(plusCodeFor(null, null), '');
      expect(plusCodeFor(chennaiLat, null), '');
      expect(plusCodeFor(double.nan, double.nan), '');
    });

    test('the local form drops the area code', () {
      expect(localPlusCode('7M5237MC+37'), '37MC+37');
    });

    test('a padded code has no local form', () {
      expect(localPlusCode('7FG40000+'), '');
    });

    test('a short code has no local form to take', () {
      expect(localPlusCode('37MC+37'), '');
    });

    test('a town makes the short readable form', () {
      expect(
        displayPlusCode('7M5237MC+37', locality: 'Chennai'),
        '37MC+37, Chennai',
      );
    });

    test('without a town the full code is shown', () {
      expect(displayPlusCode('7M5237MC+37'), '7M5237MC+37');
    });

    test('nothing displays as nothing', () {
      expect(displayPlusCode(null), '');
      expect(displayPlusCode(''), '');
    });
  });

  group('parsing whatever the customer pasted', () {
    test('a code with a town after a comma', () {
      final parsed = splitCodeAndLocality('37MC+37, Chennai');

      expect(parsed.code, '37MC+37');
      expect(parsed.locality, 'Chennai');
    });

    test('a code with a town and no comma', () {
      final parsed = splitCodeAndLocality('37MC+37 Chennai');

      expect(parsed.code, '37MC+37');
      expect(parsed.locality, 'Chennai');
    });

    test('a bare full code', () {
      final parsed = splitCodeAndLocality('7M5237MC+37');

      expect(parsed.code, '7M5237MC+37');
      expect(parsed.locality, '');
    });

    test('lower case is lifted', () {
      final parsed = splitCodeAndLocality('37mc+37, chennai');

      expect(parsed.code, '37MC+37');
      expect(parsed.locality, 'chennai');
    });

    test('a whole line off the share sheet', () {
      final parsed =
          splitCodeAndLocality('37MC+37, Teynampet, Chennai, Tamil Nadu');

      expect(parsed.code, '37MC+37');
      expect(parsed.locality, 'Teynampet, Chennai, Tamil Nadu');
    });

    test('surrounding space is ignored', () {
      final parsed = splitCodeAndLocality('  37MC+37 ,  Chennai  ');

      expect(parsed.code, '37MC+37');
      expect(parsed.locality, 'Chennai');
    });

    test('nothing parses to nothing', () {
      expect(splitCodeAndLocality('').code, '');
      expect(splitCodeAndLocality(null).code, '');
    });
  });
}
